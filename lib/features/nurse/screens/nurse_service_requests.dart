import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/report_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';
import 'nurse_ui.dart';

class NurseServiceRequests extends StatefulWidget {
  final User user;

  const NurseServiceRequests({Key? key, required this.user}) : super(key: key);

  @override
  State<NurseServiceRequests> createState() => _NurseServiceRequestsState();
}

class _NurseServiceRequestsState extends State<NurseServiceRequests> {
  List<ServiceRequest> requests = [];
  bool isLoading = true;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(
            selectedTab == 0 ? 'Service Requests' : 'My Assigned Services',
          ),
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [NurseModeControls(providerUserId: widget.user.userId)],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: _tabs(),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: _visibleRequests.isEmpty
                          ? _emptyState()
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                              itemCount: _visibleRequests.length,
                              itemBuilder: (context, index) {
                                return _requestCard(_visibleRequests[index]);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<ServiceRequest> get _visibleRequests {
    if (selectedTab == 0) {
      return requests.where((r) => r.status == 'pending').toList();
    }
    return requests
        .where(
          (r) => {
            'assigned',
            'in_progress',
            'waiting_report',
            'completed',
          }.contains(r.status),
        )
        .toList();
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          _tabButton(0, Icons.inbox_rounded, 'New Requests'),
          _tabButton(1, Icons.medical_services_rounded, 'Assigned Services'),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = selectedTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : NurseUi.muted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : NurseUi.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: NurseUi.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: NurseUi.border.withOpacity(0.8)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: NurseUi.softSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedTab == 0
                      ? Icons.inbox_rounded
                      : Icons.medical_services_rounded,
                  color: AppColors.primaryDark,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                selectedTab == 0
                    ? 'No new service requests'
                    : 'No assigned services yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NurseUi.text,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedTab == 0
                    ? 'Accepted requests will move to My Assigned Services.'
                    : 'Accepted visits, active visits, and waiting reports appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NurseUi.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestCard(ServiceRequest request) {
    final color = _statusColor(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(NurseUi.isDarkMode.value ? 0.16 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.healing_rounded, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.patientName.isNotEmpty
                          ? request.patientName
                          : 'Patient',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NurseUi.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.serviceType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NurseUi.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _statusPill(request.status, color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  Icons.event_rounded,
                  'Date',
                  _formatDate(request.scheduledDate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfo(
                  Icons.schedule_rounded,
                  'Time',
                  _formatTime(request.scheduledDate),
                ),
              ),
            ],
          ),
          if ((request.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NurseUi.softSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NurseUi.border.withOpacity(0.65)),
              ),
              child: Text(
                request.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: NurseUi.text, fontSize: 13, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (request.status == 'pending') ...[
                Expanded(
                  child: _solidButton(
                    'Accept',
                    Icons.check_rounded,
                    () => _updateRequestStatus(request, 'scheduled'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlineButton(
                    'Reject',
                    Icons.close_rounded,
                    () => _updateRequestStatus(request, 'cancelled'),
                    color: const Color(0xFFB42318),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _solidButton(
                    'View Details',
                    Icons.visibility_rounded,
                    () => _openDetails(request),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NurseUi.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: NurseUi.muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _solidButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _outlineButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    final c = color ?? AppColors.primaryDark;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _loadRequests() async {
    try {
      final data = await ServiceRequestService.getProviderRequests(widget.user.userId);
      if (!mounted) return;
      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _updateRequestStatus(ServiceRequest request, String status) async {
    try {
      final success = await ServiceRequestService.updateRequestStatus(
        request.id,
        status,
        providerUserId: widget.user.userId,
      );
      if (success) {
        if (status == 'scheduled') setState(() => selectedTab = 1);
        await _loadRequests();
        _snack(status == 'scheduled'
            ? 'Request accepted and moved to My Assigned Services'
            : 'Request updated');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _openDetails(ServiceRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignedServiceDetails(
        request: request,
        providerUserId: widget.user.userId,
        onChanged: _loadRequests,
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFB7791F);
      case 'assigned':
        return AppColors.primaryDark;
      case 'in_progress':
        return const Color(0xFF1570EF);
      case 'waiting_report':
        return const Color(0xFFB54708);
      case 'completed':
        return const Color(0xFF039855);
      case 'cancelled':
        return const Color(0xFFB42318);
      default:
        return NurseUi.muted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'ASSIGNED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'waiting_report':
        return 'WAITING REPORT';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AssignedServiceDetails extends StatefulWidget {
  final ServiceRequest request;
  final String providerUserId;
  final Future<void> Function() onChanged;

  const _AssignedServiceDetails({
    required this.request,
    required this.providerUserId,
    required this.onChanged,
  });

  @override
  State<_AssignedServiceDetails> createState() => _AssignedServiceDetailsState();
}

class _AssignedServiceDetailsState extends State<_AssignedServiceDetails> {
  late ServiceRequest request;
  final beforeController = TextEditingController();
  final afterController = TextEditingController();
  final vitalsController = TextEditingController();
  final notesController = TextEditingController();
  final recommendationsController = TextEditingController();
  bool needsDoctorFollowUp = false;
  bool isSaving = false;

  final activities = <_NursingActivity>[
    _NursingActivity('Blood Pressure', 'قياس ضغط الدم'),
    _NursingActivity('Sugar Level', 'قياس السكر'),
    _NursingActivity('Medication Given', 'إعطاء الدواء'),
    _NursingActivity('Dressing Changed', 'تغيير الضماد'),
    _NursingActivity('Vital Signs Follow-up', 'متابعة العلامات الحيوية'),
    _NursingActivity('Mobility Assistance', 'مساعدة المريض على الحركة'),
    _NursingActivity('Health Education', 'تقديم تعليمات صحية'),
  ];

  @override
  void initState() {
    super.initState();
    request = widget.request;
    for (final saved in request.nursingActivities) {
      final name = (saved['activity'] ?? '').toString();
      for (final activity in activities) {
        if (activity.label == name) {
          activity.done = saved['done'] == true;
          activity.notesController.text = (saved['notes'] ?? '').toString();
        }
      }
    }
  }

  @override
  void dispose() {
    beforeController.dispose();
    afterController.dispose();
    vitalsController.dispose();
    notesController.dispose();
    recommendationsController.dispose();
    for (final activity in activities) {
      activity.notesController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: NurseUi.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Details',
                          style: TextStyle(
                            color: NurseUi.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          _statusLabel(request.status),
                          style: TextStyle(color: NurseUi.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: NurseUi.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Patient Information'),
                    _infoGrid([
                      _InfoItem('Patient Name', _patientName, Icons.person_rounded),
                      _InfoItem('Age', request.patientAge > 0 ? '${request.patientAge}' : 'Not set', Icons.cake_rounded),
                      _InfoItem('Phone Number', request.patientPhone.isNotEmpty ? request.patientPhone : 'Not set', Icons.call_rounded),
                      _InfoItem('Address', request.location.isNotEmpty ? request.location : request.patientAddress, Icons.location_on_rounded),
                      _InfoItem('GPS Location', _gpsText, Icons.map_rounded),
                      _InfoItem('Medical Condition', _condition, Icons.health_and_safety_rounded),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('Required Service'),
                    _infoGrid([
                      _InfoItem('Service Type', request.serviceType, Icons.healing_rounded),
                      _InfoItem('Visit Time', '${_formatDate(request.scheduledDate)}  ${_formatTime(request.scheduledDate)}', Icons.event_rounded),
                      _InfoItem('Expected Duration', '${request.expectedDurationHours} hours', Icons.timer_rounded),
                      _InfoItem('Price', request.price > 0 ? '\$${request.price.toStringAsFixed(0)}' : 'Not set', Icons.payments_rounded),
                    ]),
                    if ((request.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _noteBox('Notes', request.notes!),
                    ],
                    const SizedBox(height: 18),
                    _timeline(),
                    const SizedBox(height: 18),
                    if (request.status == 'assigned') _startVisitButton(),
                    if (request.status == 'in_progress') ...[
                      _activitiesCard(),
                      const SizedBox(height: 14),
                      _endVisitButton(),
                    ],
                    if (request.status == 'waiting_report') _reportForm(),
                    if (request.status == 'completed') _completedBox(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _patientName =>
      request.patientName.isNotEmpty ? request.patientName : request.patientId;

  String get _condition =>
      request.medicalCondition.isNotEmpty
          ? request.medicalCondition
          : ((request.notes ?? '').isNotEmpty ? request.notes! : 'Not recorded');

  String get _gpsText {
    if (request.gpsLat == null || request.gpsLng == null) return 'Not set';
    return '${request.gpsLat!.toStringAsFixed(5)}, ${request.gpsLng!.toStringAsFixed(5)}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 560;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: twoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth,
              child: _infoTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _infoTile(_InfoItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: NurseUi.border.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(color: NurseUi.muted, fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  item.value.isNotEmpty ? item.value : 'Not set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NurseUi.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteBox(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NurseUi.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NurseUi.border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: NurseUi.muted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(body, style: TextStyle(color: NurseUi.text, height: 1.4)),
        ],
      ),
    );
  }

  Widget _timeline() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Column(
        children: [
          _timeRow('Actual Start Time', request.actualStartedAt),
          const Divider(height: 18),
          _timeRow('Actual End Time', request.actualEndedAt),
          if (request.actualDurationMinutes > 0) ...[
            const Divider(height: 18),
            Row(
              children: [
                Icon(Icons.timelapse_rounded, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 10),
                Text('Total Duration', style: TextStyle(color: NurseUi.muted)),
                const Spacer(),
                Text(
                  _durationText(request.actualDurationMinutes),
                  style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeRow(String label, DateTime? value) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 20),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: NurseUi.muted)),
        const Spacer(),
        Text(
          value == null ? 'Not recorded' : _formatTime(value),
          style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _startVisitButton() {
    return _primaryAction(
      'Start Visit',
      Icons.play_arrow_rounded,
      _startVisit,
    );
  }

  Widget _endVisitButton() {
    return _primaryAction(
      'End Visit',
      Icons.stop_rounded,
      _endVisit,
    );
  }

  Widget _primaryAction(String label, IconData icon, Future<void> Function() action) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: isSaving ? null : action,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _activitiesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Nursing Activities'),
          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: activity.done,
                    onChanged: (value) {
                      setState(() => activity.done = value ?? false);
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      activity.label,
                      style: TextStyle(
                        color: NurseUi.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(activity.arLabel, style: TextStyle(color: NurseUi.muted)),
                  ),
                  TextField(
                    controller: activity.notesController,
                    decoration: InputDecoration(
                      hintText: 'Notes',
                      filled: true,
                      fillColor: NurseUi.softSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportForm() {
    final serviceSummary = activities
        .where((a) => a.done)
        .map((a) {
          final note = a.notesController.text.trim();
          return note.isEmpty ? a.label : '${a.label}: $note';
        })
        .join('\n');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Submit Visit Report'),
          _reportField('Patient Condition Before Visit', beforeController),
          _reportField('Services Provided', notesController, initial: serviceSummary),
          _reportField('Vital Signs', vitalsController),
          _reportField('Patient Condition After Visit', afterController),
          _reportField('Recommendations', recommendationsController),
          SwitchListTile(
            value: needsDoctorFollowUp,
            onChanged: (value) => setState(() => needsDoctorFollowUp = value),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Need Doctor Follow-up?',
              style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          _primaryAction('Submit Report', Icons.send_rounded, _submitReport),
        ],
      ),
    );
  }

  Widget _reportField(
    String label,
    TextEditingController controller, {
    String? initial,
  }) {
    if (initial != null && controller.text.isEmpty) controller.text = initial;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: NurseUi.softSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _completedBox() {
    return _noteBox(
      'Completed',
      'The visit is completed. The patient can now rate the nurse and write feedback.',
    );
  }

  Future<void> _startVisit() async {
    await _runAction(() async {
      final ok = await ServiceRequestService.startVisit(
        request.id,
        providerUserId: widget.providerUserId,
      );
      if (ok) {
        setState(() {
          request = ServiceRequest.fromJson({
            ...request.toJson(),
            'status': 'in_progress',
            'actualStartedAt': DateTime.now().toIso8601String(),
          });
        });
        await widget.onChanged();
      }
    }, 'Visit started');
  }

  Future<void> _endVisit() async {
    final payload = activities
        .map(
          (a) => {
            'activity': a.label,
            'done': a.done,
            'notes': a.notesController.text.trim(),
          },
        )
        .toList();
    await _runAction(() async {
      final ok = await ServiceRequestService.endVisit(
        request.id,
        providerUserId: widget.providerUserId,
        nursingActivities: payload,
      );
      if (ok) {
        final now = DateTime.now();
        final minutes = request.actualStartedAt == null
            ? 0
            : now.difference(request.actualStartedAt!).inMinutes;
        setState(() {
          request = ServiceRequest.fromJson({
            ...request.toJson(),
            'status': 'waiting_report',
            'actualEndedAt': now.toIso8601String(),
            'actualDurationMinutes': minutes,
            'nursingActivities': payload,
          });
        });
        await widget.onChanged();
      }
    }, 'Visit ended. Please submit the report');
  }

  Future<void> _submitReport() async {
    final services = notesController.text.trim();
    if (beforeController.text.trim().isEmpty ||
        afterController.text.trim().isEmpty ||
        services.isEmpty) {
      _snack('Please fill condition before, services, and condition after');
      return;
    }
    await _runAction(() async {
      final ok = await ReportService.createReport(
        providerId: widget.providerUserId,
        requestId: request.id,
        patientId: request.patientId,
        patientName: _patientName,
        serviceType: request.serviceType,
        location: request.location,
        scheduledDate: request.scheduledDate,
        durationHours: request.actualDurationMinutes > 0
            ? (request.actualDurationMinutes / 60).ceil()
            : request.expectedDurationHours,
        visitSummary:
            'Before: ${beforeController.text.trim()}\nAfter: ${afterController.text.trim()}',
        vitalSigns: vitalsController.text.trim(),
        medications: services,
        observations:
            '${notesController.text.trim()}\nNeed doctor follow-up: ${needsDoctorFollowUp ? 'Yes' : 'No'}',
        recommendations: recommendationsController.text.trim(),
      );
      if (ok) {
        setState(() {
          request = ServiceRequest.fromJson({
            ...request.toJson(),
            'status': 'completed',
          });
        });
        await widget.onChanged();
        if (mounted) Navigator.pop(context);
      }
    }, 'Report submitted. Visit completed');
  }

  Future<void> _runAction(Future<void> Function() action, String success) async {
    setState(() => isSaving = true);
    try {
      await action();
      _snack(success);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'waiting_report':
        return 'Waiting Report';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _durationText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m minutes';
    return '$h hours ${m > 0 ? 'and $m minutes' : ''}';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;

  _InfoItem(this.label, this.value, this.icon);
}

class _NursingActivity {
  final String label;
  final String arLabel;
  final TextEditingController notesController = TextEditingController();
  bool done = false;

  _NursingActivity(this.label, this.arLabel);
}
