import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';
import 'medical_record_screen.dart';
import 'medical_report_form.dart';
import 'request_details_screen.dart';

class RequestsListScreen extends StatefulWidget {
  final String? status;

  const RequestsListScreen({super.key, this.status});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  List<dynamic> _requests = [];
  String? _currentStatus;
  String? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';

      List<dynamic> requests;
      if (_currentStatus == 'available') {
        requests = await _doctorService.getAvailableRequests(doctorId);
      } else if (_currentStatus != null && _currentStatus!.isNotEmpty) {
        requests = await _doctorService.getRequests(
          doctorId,
          status: _currentStatus,
        );
      } else {
        requests = await _doctorService.getRequests(doctorId);
      }

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            height: 50,
            color: Colors.grey[100],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildFilterChip('All', null),
                _buildFilterChip('Available', 'available'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Confirmed', 'confirmed'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          // Requests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(_requests[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentStatus) {
      case 'pending':
        return 'Pending Requests';
      case 'available':
        return 'Available Requests';
      case 'confirmed':
        return 'Confirmed Requests';
      case 'completed':
        return 'Completed Requests';
      case 'cancelled':
        return 'Cancelled Requests';
      default:
        return 'All Requests';
    }
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _currentStatus == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _currentStatus = selected ? status : null;
          });
          _loadRequests();
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  String _requestIdOf(dynamic request) {
    if (request is! Map) return '';
    return (request['requestId'] ?? request['id'] ?? '').toString();
  }

  Future<void> _acceptRequest(dynamic request) async {
    final requestId = _requestIdOf(request);
    if (requestId.isEmpty || _busyRequestId != null) return;

    setState(() => _busyRequestId = requestId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      await _doctorService.acceptRequest(requestId, doctorId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error accepting request: $e')));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _rejectRequest(dynamic request) async {
    final requestId = _requestIdOf(request);
    if (requestId.isEmpty || _busyRequestId != null) return;

    final reason = await _askRejectReason();
    if (reason == null) return;

    setState(() => _busyRequestId = requestId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      await _doctorService.rejectRequest(
        requestId,
        doctorId,
        reason: reason.trim().isEmpty ? null : reason.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.red,
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting request: $e')));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Tell the patient why you declined',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _completeRequest(dynamic request) async {
    final requestId = _requestIdOf(request);
    if (requestId.isEmpty || _busyRequestId != null) return;

    setState(() => _busyRequestId = requestId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      await _doctorService.completeRequest(requestId, doctorId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit marked completed'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error completing visit: $e')));
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No requests found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final status = request['status'] ?? 'pending';
    final patientName = request['patientName'] ?? 'Unavailable';
    final patientId = (request['patientUserId'] ?? '').toString();
    final scheduledAt = request['scheduledAt'];
    final location = request['location'] ?? '';
    final reasonForVisit = request['reasonForVisit'] ?? '';
    final requestId = _requestIdOf(request);
    final isPending = status == 'pending';
    final canOpenRecord = patientId.isNotEmpty;
    final canComplete = status == 'confirmed' && requestId.isNotEmpty;
    final canFileReport = status == 'completed' && requestId.isNotEmpty;
    final isBusy = _busyRequestId == requestId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RequestDetailsScreen(requestId: request['requestId']),
            ),
          ).then((_) => _loadRequests());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              if (reasonForVisit.isNotEmpty)
                Text(
                  reasonForVisit,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    scheduledAt != null
                        ? _formatDate(scheduledAt)
                        : 'Not scheduled',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _rejectRequest(request),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _acceptRequest(request),
                        icon: isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (status == 'confirmed' || status == 'completed') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canOpenRecord
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MedicalRecordScreen(
                                      patientId: patientId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(
                          Icons.medical_information_outlined,
                          size: 18,
                        ),
                        label: const Text('Records'),
                      ),
                    ),
                    if (canComplete) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _completeRequest(request),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ] else if (canFileReport) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MedicalReportFormScreen(
                                  requestId: requestId,
                                  requestData: Map<String, dynamic>.from(
                                    request,
                                  ),
                                ),
                              ),
                            ).then((_) => _loadRequests());
                          },
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('File Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
