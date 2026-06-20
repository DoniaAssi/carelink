import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';
import 'doctor_ui_constants.dart';
import 'initial_diagnosis_report_screen.dart';
import 'medical_record_screen.dart';
import 'medical_report_form.dart';

class RequestDetailsScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailsScreen({super.key, required this.requestId});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  Map<String, dynamic> _request = {};
  String _doctorId = '';

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';

      final request = await _doctorService.getRequestDetails(widget.requestId);
      debugPrint(
        '[doctor:request-details:loaded] requestId=${widget.requestId} '
        'patientId=${request['patientUserId']} '
        'doctorId=${request['providerUserId']} '
        'hasInitialDiagnosisReport=${request['hasInitialDiagnosisReport']} '
        'parsed=${_asBool(request['hasInitialDiagnosisReport'])}',
      );
      setState(() {
        _request = request;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading request: $e')));
      }
    }
  }

  Future<void> _acceptRequest() async {
    try {
      final response = await _doctorService.acceptRequest(
        widget.requestId,
        _doctorId,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request accepted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadRequestDetails();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest() async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    final cleanReason = reason?.trim();
    reasonController.dispose();
    if (reason == null) return;

    try {
      final response = await _doctorService.rejectRequest(
        widget.requestId,
        _doctorId,
        reason: cleanReason == null || cleanReason.isEmpty ? null : cleanReason,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request rejected'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeRequest() async {
    try {
      final response = await _doctorService.completeRequest(
        widget.requestId,
        _doctorId,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visit marked completed'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadRequestDetails();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openReportForRequest() async {
    final requestData = Map<String, dynamic>.from(_request);
    if (_asBool(requestData['hasReportForVisit'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A report already exists for this completed visit.'),
        ),
      );
      _loadRequestDetails();
      return;
    }

    var hasInitial = _asBool(
      requestData['hasInitialDiagnosisReportForCase'] ??
          requestData['hasInitialDiagnosisReport'],
    );

    try {
      if (!hasInitial) {
        final response = await _doctorService.getInitialDiagnosisReport(
          widget.requestId,
          doctorUserId: _doctorId,
        );
        hasInitial = _asBool(response['hasInitialDiagnosisReport']);
      }
      requestData['hasInitialDiagnosisReport'] = hasInitial;
      requestData['hasInitialDiagnosisReportForCase'] = hasInitial;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking initial diagnosis: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => hasInitial
            ? MedicalReportFormScreen(
                requestId: widget.requestId,
                requestData: requestData,
              )
            : InitialDiagnosisReportScreen(
                requestId: widget.requestId,
                requestData: requestData,
              ),
      ),
    ).then((_) => _loadRequestDetails());
  }

  @override
  Widget build(BuildContext context) {
    final status = _request['status'] ?? 'pending';
    final patientName = _request['patientName'] ?? 'Unavailable';
    final patientPhone = _request['patientPhone'] ?? '';
    final patientEmail = _request['patientEmail'] ?? '';
    final scheduledAt = _request['scheduledAt'];
    final location = _request['location'] ?? '';
    final reasonForVisit = _request['reasonForVisit'] ?? '';
    final notes = _request['notes'] ?? '';
    final normalizedStatus = status.toString().toLowerCase();
    final canCreateReport =
        normalizedStatus == 'completed' &&
        !_asBool(_request['hasReportForVisit']) &&
        (_request['requestId'] ?? widget.requestId).toString().isNotEmpty;

    return Scaffold(
      backgroundColor: DoctorUiConstants.doctorBackground,
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Patient Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patient Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          _buildInfoRow('Name', patientName),
                          if (patientPhone.isNotEmpty)
                            _buildInfoRow('Phone', patientPhone),
                          if (patientEmail.isNotEmpty)
                            _buildInfoRow('Email', patientEmail),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Appointment Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appointment Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          if (reasonForVisit.isNotEmpty)
                            _buildInfoRow('Reason', reasonForVisit),
                          if (scheduledAt != null)
                            _buildInfoRow(
                              'Scheduled',
                              _formatDate(scheduledAt),
                            ),
                          if (location.isNotEmpty)
                            _buildInfoRow('Location', location),
                          if (notes.isNotEmpty) _buildInfoRow('Notes', notes),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  if (status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _acceptRequest,
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejectRequest,
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'confirmed') ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MedicalRecordScreen(
                              patientId: _request['patientUserId'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_information),
                      label: const Text('View Medical Record'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _completeRequest,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark Visit Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                  if (normalizedStatus == 'completed') ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MedicalRecordScreen(
                              patientId: _request['patientUserId'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_information),
                      label: const Text('View Medical Record'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (canCreateReport) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openReportForRequest,
                        icon: const Icon(Icons.description),
                        label: const Text('Submit Medical Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        break;
      case 'confirmed':
        color = AppColors.success;
        break;
      case 'completed':
        color = AppColors.info;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
