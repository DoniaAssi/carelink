import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';
import 'initial_diagnosis_report_screen.dart';
import 'medical_report_form.dart';

class DoctorReportsScreen extends StatefulWidget {
  const DoctorReportsScreen({super.key});

  @override
  State<DoctorReportsScreen> createState() => _DoctorReportsScreenState();
}

class _DoctorReportsScreenState extends State<DoctorReportsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  List<dynamic> _requests = [];

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      final requests = doctorId.isEmpty
          ? <dynamic>[]
          : await _doctorService.getRequests(doctorId);

      if (!mounted) return;
      setState(() {
        _requests = requests
            .where((item) {
              if (item is! Map) return false;
              final status = (item['status'] ?? '').toString().toLowerCase();
              final hasReportForVisit = _asBool(item['hasReportForVisit']);
              final canCreateReport = item.containsKey('canCreateReport')
                  ? _asBool(item['canCreateReport'])
                  : status == 'completed' && !hasReportForVisit;
              return status == 'completed' && canCreateReport;
            })
            .take(12)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
    }
  }

  void _openFirstReport() {
    final request = _requests.cast<dynamic>().firstWhere(
      (item) =>
          item is Map &&
          (item['status'] ?? '').toString().toLowerCase() == 'completed' &&
          (item['requestId'] ?? '').toString().isNotEmpty,
      orElse: () => null,
    );

    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed visits ready for a report')),
      );
      return;
    }

    _openReportForm(request);
  }

  Future<void> _openReportForm(dynamic rawRequest) async {
    if (rawRequest is! Map) return;
    final requestId = (rawRequest['requestId'] ?? rawRequest['id'] ?? '')
        .toString();
    if (requestId.isEmpty) return;

    final requestData = Map<String, dynamic>.from(rawRequest);
    if (_asBool(requestData['hasReportForVisit'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A report already exists for this completed visit.'),
        ),
      );
      _loadRequests();
      return;
    }

    var hasInitial = _asBool(
      requestData['hasInitialDiagnosisReportForCase'] ??
          requestData['hasInitialDiagnosisReport'],
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId =
          prefs.getString('doctor_userId') ??
          (requestData['providerUserId'] ?? '').toString();
      if (!hasInitial) {
        final response = await _doctorService.getInitialDiagnosisReport(
          requestId,
          doctorUserId: doctorId,
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
                requestId: requestId,
                requestData: requestData,
              )
            : InitialDiagnosisReportScreen(
                requestId: requestId,
                requestData: requestData,
              ),
      ),
    ).then((_) => _loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: DoctorUiConstants.doctorBackground,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 118),
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 26),
                              _buildHeroCard(),
                              const SizedBox(height: 24),
                              Text(
                                context.dtr('doctor.reports.completedReady'),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_requests.isEmpty)
                                _buildEmptyState()
                              else
                                for (final request in _requests)
                                  _buildReportRequestTile(request),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          context.dtr('doctor.dashboard.medicalReports'),
          style: TextStyle(
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _requests.isEmpty ? null : _openFirstReport,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(context.dtr('doctor.dashboard.newReport')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F7F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create and manage reports',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Send medical summaries after completed visits',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF68727D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No completed visits available for reporting.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A new report can be created only after a completed visit without an existing report.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRequestTile(dynamic rawRequest) {
    final request = rawRequest is Map ? rawRequest : <String, dynamic>{};
    final patientName = (request['patientName'] ?? 'Unavailable').toString();
    final serviceType = (request['serviceType'] ?? 'Medical visit').toString();
    final status = (request['status'] ?? '').toString();
    final canCreate = status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAF0EF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE7F7F2),
            child: Text(
              patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF68727D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: canCreate ? () => _openReportForm(request) : null,
            icon: Icon(
              canCreate ? Icons.add_rounded : Icons.check_rounded,
              size: 18,
            ),
            label: Text(canCreate ? 'Report' : 'Done'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: canCreate
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.24),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
