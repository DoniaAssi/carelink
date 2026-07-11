import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';
import 'doctor_visit_tracking_screen.dart';
import 'initial_diagnosis_report_screen.dart';
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
  String _doctorId = '';
  Map<String, int> _filterCounts = {
    'all': 0,
    'available': 0,
    'pending': 0,
    'confirmed': 0,
    'completed': 0,
    'cancelled': 0,
  };

  Color get _pageColor => DoctorUiConstants.pageColor(context);
  static const _primary = Color(0xFF0F8B8D);

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }

  static const _textDark = Color(0xFF101828);
  static const _textMuted = Color(0xFF667085);

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
      _doctorId = doctorId;

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

      final allRequests = _currentStatus == null
          ? requests
          : await _doctorService.getRequests(doctorId);
      final availableRequests = _currentStatus == 'available'
          ? requests
          : await _doctorService.getAvailableRequests(doctorId);
      final nextCounts = _buildFilterCounts(allRequests, availableRequests);

      debugPrint(
        '[doctor requests screen] doctorId=$doctorId '
        'selectedStatus=${_currentStatus ?? 'all'} '
        'received=${requests.length} '
        'statuses=${requests.map((item) => item is Map ? item['status'] : null).toList()}',
      );
      debugPrint(
        '[doctor requests screen] all=${allRequests.length} '
        'available=${availableRequests.length} counts=$nextCounts',
      );

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _filterCounts = nextCounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoctorTypographyScope(
      child: Scaffold(
        backgroundColor: _pageColor,
        appBar: AppBar(
          backgroundColor: _pageColor,
          surfaceTintColor: _pageColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: _primary,
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Requests',
            style: TextStyle(
              color: _textDark,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
              child: _buildStatusRow(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: _requests.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                return _buildRequestCard(_requests[index]);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
        children: [
          _buildFilterChip('All', null, _filterCounts['all'] ?? 0),
          _buildFilterChip(
            'Available',
            'available',
            _filterCounts['available'] ?? 0,
          ),
          _buildFilterChip('Pending', 'pending', _filterCounts['pending'] ?? 0),
          _buildFilterChip(
            'Confirmed',
            'confirmed',
            _filterCounts['confirmed'] ?? 0,
          ),
          _buildFilterChip(
            'Completed',
            'completed',
            _filterCounts['completed'] ?? 0,
          ),
          _buildFilterChip(
            'Cancelled',
            'cancelled',
            _filterCounts['cancelled'] ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status, int count) {
    final isSelected = _currentStatus == status;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Material(
        color: isSelected ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: isSelected ? 8 : 0,
        shadowColor: _primary.withValues(alpha: 0.22),
        child: InkWell(
          onTap: () {
            setState(() {
              _currentStatus = status;
            });
            _loadRequests();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _primary : const Color(0xFFDDE7E4),
              ),
            ),
            child: Text(
              '$label ($count)',
              style: TextStyle(
                color: isSelected ? Colors.white : _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        const Icon(Icons.assignment_outlined, color: _primary, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Showing ${_statusLabel(_currentStatus).toLowerCase()} requests',
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
        SnackBar(
          content: Text(context.dx('Request accepted successfully')),
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
        SnackBar(
          content: Text(context.dx('Request rejected')),
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
        title: Text(context.dx('Reject Request')),
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
            child: Text(context.dx('Cancel')),
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

  Future<bool> _completeRequest(dynamic request) async {
    final requestId = _requestIdOf(request);
    if (requestId.isEmpty || _busyRequestId != null) return false;

    setState(() => _busyRequestId = requestId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('doctor_userId') ?? '';
      await _doctorService.completeRequest(requestId, doctorId);

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.dx('Visit marked completed')),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadRequests();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing visit: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _openReportForRequest(Map<String, dynamic> request) async {
    final requestId = _requestIdOf(request);
    if (requestId.isEmpty) return;

    final requestData = Map<String, dynamic>.from(request);
    if (_asBool(requestData['hasReportForVisit'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.dx('A report already exists for this completed visit.'),
          ),
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
      final doctorId = _doctorId.isNotEmpty
          ? _doctorId
          : (requestData['providerUserId'] ?? '').toString();
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

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [_cardShadow()],
            border: Border.all(color: const Color(0xFFDCEAE6)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDF3EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No requests found',
                style: TextStyle(
                  fontSize: 20,
                  color: _textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New ${_statusLabel(_currentStatus).toLowerCase()} requests will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: _textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(dynamic rawRequest) {
    final request = rawRequest is Map
        ? Map<String, dynamic>.from(rawRequest)
        : <String, dynamic>{};
    final status = (request['status'] ?? 'pending').toString();
    final patientName = _cleanText(request['patientName']) ?? 'Patient';
    final patientId = (request['patientUserId'] ?? '').toString();
    final scheduledAt = _cleanText(request['scheduledAt']);
    final location =
        _cleanText(request['visitAddress']) ?? _cleanText(request['location']);
    final serviceType =
        _cleanText(request['serviceType']) ??
        _cleanText(request['reasonForVisit']) ??
        'Consultation';
    final requestId = _requestIdOf(request);
    final normalizedStatus = status.toLowerCase();
    final isPending =
        normalizedStatus == 'pending' ||
        normalizedStatus == 'pending_provider_approval';
    final canOpenRecord = patientId.isNotEmpty;
    final canComplete =
        status.toLowerCase() == 'confirmed' && requestId.isNotEmpty;
    final hasReportForVisit = _asBool(request['hasReportForVisit']);
    final canFileReport =
        status.toLowerCase() == 'completed' &&
        requestId.isNotEmpty &&
        !hasReportForVisit;
    final isBusy = _busyRequestId == requestId;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [_cardShadow()],
        border: Border.all(color: const Color(0xFFDCEAE6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
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
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _patientAvatar(patientName),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                _serviceIcon(serviceType),
                                color: _primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  serviceType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 22),
                _infoRow(
                  Icons.calendar_month_outlined,
                  scheduledAt == null
                      ? 'Not scheduled'
                      : _formatDate(scheduledAt),
                ),
                const SizedBox(height: 14),
                _infoRow(
                  Icons.location_on_rounded,
                  location ?? 'Location not set',
                ),
                if (isPending) ...[
                  const SizedBox(height: 24),
                  _pendingActions(request, isBusy),
                ] else ...[
                  const SizedBox(height: 14),
                  _nonPendingActions(
                    request: request,
                    patientId: patientId,
                    canOpenRecord: canOpenRecord,
                    canComplete: canComplete,
                    canFileReport: canFileReport,
                    isBusy: isBusy,
                    requestId: requestId,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _patientAvatar(String patientName) {
    final initial = patientName.trim().isEmpty
        ? 'P'
        : patientName.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF3EE),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _primary,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Icon(icon, color: const Color(0xFF344054), size: 24),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pendingActions(dynamic request, bool isBusy) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : () => _rejectRequest(request),
            icon: const Icon(Icons.close_rounded, size: 23),
            label: Text(context.dx('Reject')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB4233A),
              disabledForegroundColor: const Color(
                0xFFB4233A,
              ).withValues(alpha: 0.45),
              side: const BorderSide(color: Color(0xFFB4233A), width: 1.3),
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : () => _acceptRequest(request),
            icon: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 24),
            label: Text(context.dx('Accept')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007A5C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF007A5C,
              ).withValues(alpha: 0.45),
              minimumSize: const Size.fromHeight(58),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nonPendingActions({
    required Map<String, dynamic> request,
    required String patientId,
    required bool canOpenRecord,
    required bool canComplete,
    required bool canFileReport,
    required bool isBusy,
    required String requestId,
  }) {
    if (!canOpenRecord && !canComplete && !canFileReport) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RequestDetailsScreen(requestId: request['requestId']),
              ),
            ).then((_) => _loadRequests());
          },
          icon: const Icon(Icons.chevron_right_rounded),
          color: const Color(0xFF344054),
        ),
      );
    }

    return Row(
      children: [
        if (canOpenRecord)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MedicalRecordScreen(patientId: patientId),
                  ),
                );
              },
              icon: const Icon(Icons.medical_information_outlined, size: 18),
              label: Text(context.dx('Records')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFDDE7E4)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        if (canComplete) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isBusy
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorVisitTrackingScreen(
                            requestData: Map<String, dynamic>.from(request),
                            onCompleteVisit: () => _completeRequest(request),
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.directions_car_outlined, size: 18),
              label: Text(context.dx('On The Way')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ] else if (canFileReport) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openReportForRequest(request),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(context.dx('File Report')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ] else
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RequestDetailsScreen(requestId: request['requestId']),
                ),
              ).then((_) => _loadRequests());
            },
            icon: const Icon(Icons.chevron_right_rounded),
            color: const Color(0xFF344054),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final lower = status.toLowerCase();
    late final Color color;
    late final Color background;

    if (lower.contains('pending') && lower.contains('payment')) {
      color = const Color(0xFF1570EF);
      background = const Color(0xFFEAF4FF);
    } else if (lower == 'pending' || lower == 'pending_provider_approval') {
      color = const Color(0xFFD97706);
      background = const Color(0xFFFFF3E6);
    } else if (lower == 'confirmed') {
      color = const Color(0xFF079455);
      background = const Color(0xFFE8F7EE);
    } else if (lower == 'completed') {
      color = _primary;
      background = const Color(0xFFE8F5F2);
    } else if (lower == 'cancelled' || lower == 'canceled') {
      color = const Color(0xFFB42318);
      background = const Color(0xFFFFEDEC);
    } else {
      color = const Color(0xFF475467);
      background = const Color(0xFFF2F4F7);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusDisplay(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Map<String, int> _buildFilterCounts(
    List<dynamic> allRequests,
    List<dynamic> availableRequests,
  ) {
    final counts = {
      'all': allRequests.length,
      'available': availableRequests.length,
      'pending': 0,
      'confirmed': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (final request in allRequests) {
      if (request is! Map) continue;
      final status = (request['status'] ?? '').toString().toLowerCase();
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      } else if (status == 'pending_provider_approval') {
        counts['pending'] = counts['pending']! + 1;
      } else if (status == 'canceled') {
        counts['cancelled'] = counts['cancelled']! + 1;
      }
    }

    return counts;
  }

  BoxShadow _cardShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.045),
      blurRadius: 24,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    );
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'All';
    }
  }

  String _statusDisplay(String status) {
    final clean = status.trim().replaceAll('_', ' ');
    if (clean.isEmpty) return 'UNKNOWN';
    if (clean.toLowerCase() == 'pending provider approval') return 'PENDING';
    return clean.toUpperCase();
  }

  IconData _serviceIcon(String serviceType) {
    final lower = serviceType.toLowerCase();
    if (lower.contains('home')) return Icons.home_rounded;
    return Icons.medical_services_outlined;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final suffix = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $suffix';
    } catch (e) {
      return dateStr;
    }
  }
}
