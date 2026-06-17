import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/nurse/screens/nurse_contact_patient_flow.dart';
import 'package:carelink/features/nurse/screens/nurse_schedule_screen.dart';
import 'package:carelink/features/nurse/services/nurse_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/shared/services/report_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';
import 'nurse_ui.dart';

class NurseServiceRequests extends StatefulWidget {
  final User user;

  const NurseServiceRequests({super.key, required this.user});

  @override
  State<NurseServiceRequests> createState() => _NurseServiceRequestsState();
}

bool nurseRequestNeedsDecision(String status) {
  final value = status.toLowerCase().trim();
  return value == 'new' ||
      value == 'pending' ||
      value == 'pending_provider_approval' ||
      value == 'pending provider approval' ||
      value == 'pending_payment' ||
      value == 'payment_pending';
}

bool nurseRequestRequiresDecision(ServiceRequest request) {
  return nurseRequestNeedsDecision(request.status);
}

bool nurseRequestIsAccepted(ServiceRequest request) {
  final value = request.status.toLowerCase().trim();
  return value == 'assigned' ||
      value == 'accepted' ||
      value == 'confirmed' ||
      value == 'scheduled';
}

bool nurseRequestIsCancelled(ServiceRequest request) {
  return request.status.toLowerCase().trim() == 'cancelled';
}

class _NurseServiceRequestsState extends State<NurseServiceRequests> {
  List<ServiceRequest> requests = [];
  bool isLoading = true;
  int selectedTab = 0;
  final NurseRepository nurseRepository = const NurseRepository();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('All Requests'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              color: const Color(0xFF0F766E),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                110,
                              ),
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
    switch (selectedTab) {
      case 1:
        return requests.where(nurseRequestRequiresDecision).toList();
      case 2:
        return requests.where(_isConfirmedRequest).toList();
      case 3:
        return requests.where((r) => r.status == 'cancelled').toList();
      default:
        return requests;
    }
  }

  Widget _tabs() {
    final tabs = const ['All', 'Pending', 'Accepted', 'Cancelled'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _tabButton(index, tabs[index]),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = selectedTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFF6B7280),
            fontWeight: FontWeight.w900,
            fontSize: 12,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedTab == 0
                      ? Icons.inbox_rounded
                      : Icons.medical_services_rounded,
                  color: const Color(0xFF0F766E),
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
                  color: const Color(0xFF111827),
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
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestCard(ServiceRequest request) {
    final clickable = !nurseRequestIsCancelled(request);
    return InkWell(
      onTap: clickable ? () => _openDetails(request) : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: Text(
                    _initial(request.patientName),
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 18,
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
                        request.patientName.isNotEmpty
                            ? request.patientName
                            : 'Patient',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        request.serviceType.isEmpty
                            ? 'Home visit'
                            : request.serviceType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF0F766E),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              request.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusPill(request.status, _statusColor(request.status)),
              ],
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 60),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_formatDate(request.scheduledDate)}, ${_formatTime(request.scheduledDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (nurseRequestIsCancelled(request)) ...[
              const SizedBox(height: 12),
              const Text(
                'Cancelled request is read-only',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isConfirmedRequest(ServiceRequest request) {
    final status = request.status.toLowerCase().trim();
    return status == 'confirmed' ||
        status == 'scheduled' ||
        status == 'assigned' ||
        status == 'accepted';
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? 'P' : clean.characters.first.toUpperCase();
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

  Future<void> _loadRequests() async {
    try {
      final data = await nurseRepository.getAllRequests(widget.user.userId);
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

  void _openDetails(ServiceRequest request) {
    if (nurseRequestIsCancelled(request)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(
          request: request,
          currentUser: widget.user,
          providerUserId: widget.user.userId,
          onChanged: _loadRequests,
          showVisitActions: !nurseRequestRequiresDecision(request),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    if (nurseRequestNeedsDecision(status)) return const Color(0xFFF59E0B);
    switch (status) {
      case 'assigned':
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return const Color(0xFF22C55E);
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
    if (nurseRequestNeedsDecision(status)) return 'Pending';
    switch (status) {
      case 'assigned':
      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'waiting_report':
        return 'Waiting Report';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class AcceptConfirmationScreen extends StatelessWidget {
  final ServiceRequest request;
  final User currentUser;
  final String providerUserId;
  final Future<void> Function() onChanged;

  const AcceptConfirmationScreen({
    super.key,
    required this.request,
    required this.currentUser,
    required this.providerUserId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: NurseUi.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Accept Confirmation',
            style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.w900),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          child: Column(
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Request Accepted!',
                style: TextStyle(
                  color: NurseUi.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have successfully accepted this request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NurseUi.muted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              _acceptedPatientCard(),
              const SizedBox(height: 14),
              _summaryCard(),
              const SizedBox(height: 28),
              _filledAction(
                icon: Icons.calendar_month_rounded,
                label: 'Add to Schedule',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssignTimeSlotScreen(
                        request: request,
                        currentUser: currentUser,
                        providerUserId: providerUserId,
                        onChanged: onChanged,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _outlineAction(
                icon: Icons.phone_rounded,
                label: 'Contact Patient',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactPatientScreen(
                        request: request,
                        currentUserId: currentUser.userId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _outlineAction(
                icon: Icons.arrow_forward_rounded,
                label: 'Go to Visit',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailsScreen(
                        request: request,
                        currentUser: currentUser,
                        providerUserId: providerUserId,
                        onChanged: onChanged,
                        showVisitActions: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _acceptedPatientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              _patientName.characters.first,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _patientName,
                  style: TextStyle(
                    color: NurseUi.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.patientAge > 0
                      ? '${request.patientAge} years'
                      : 'Age not set',
                  style: TextStyle(color: NurseUi.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  request.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD7F5E5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Accepted',
              style: TextStyle(
                color: Color(0xFF039855),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _summaryLine(
            Icons.medical_services_rounded,
            'Service Type',
            request.serviceType.isEmpty
                ? 'Home Nursing Care'
                : request.serviceType,
          ),
          const SizedBox(height: 14),
          _summaryLine(
            Icons.event_rounded,
            'Date & Time',
            '${_formatDate(request.scheduledDate)} - ${_formatTime(request.scheduledDate)}',
          ),
          const SizedBox(height: 14),
          _summaryLine(
            Icons.location_on_rounded,
            'Location',
            request.location.isEmpty ? 'Not set' : request.location,
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: NurseUi.muted, fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: NurseUi.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: NurseUi.surface,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: NurseUi.isDarkMode.value ? 0.16 : 0.04,
          ),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _filledAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  String get _patientName =>
      request.patientName.isEmpty ? 'Patient' : request.patientName;

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  static String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class AssignTimeSlotScreen extends StatefulWidget {
  final ServiceRequest request;
  final User currentUser;
  final String providerUserId;
  final Future<void> Function() onChanged;

  const AssignTimeSlotScreen({
    super.key,
    required this.request,
    required this.currentUser,
    required this.providerUserId,
    required this.onChanged,
  });

  @override
  State<AssignTimeSlotScreen> createState() => _AssignTimeSlotScreenState();
}

class _AssignTimeSlotScreenState extends State<AssignTimeSlotScreen> {
  final notesController = TextEditingController();
  final NurseRepository nurseRepository = const NurseRepository();
  final durations = const [30, 60, 90];
  var durationMinutes = 60;
  DateTime? selectedStart;
  List<Map<String, dynamic>> availabilitySlots = [];
  List<_AssignableSlot> slots = [];
  List<ServiceRequest> existingRequests = [];
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() => isLoading = true);
    final loadedSlots = await ProviderProfileService.getAvailability(
      widget.providerUserId,
    );
    final loadedRequests = await nurseRepository.getAllRequests(
      widget.providerUserId,
    );
    if (!mounted) return;
    availabilitySlots = loadedSlots;
    existingRequests = loadedRequests;
    setState(() {
      slots = _buildAssignableSlots(availabilitySlots);
      isLoading = false;
    });
  }

  List<_AssignableSlot> _buildAssignableSlots(List<Map<String, dynamic>> raw) {
    final date = widget.request.scheduledDate;
    final day = _weekdayName(date);
    final daySlots = raw.where((slot) {
      final slotDay = (slot['day'] ?? '').toString().toLowerCase();
      return slotDay == day.toLowerCase();
    }).toList();
    final source = daySlots.isNotEmpty
        ? daySlots
        : [
            {'startTime': '09:00', 'endTime': '18:00'},
          ];
    final result = <_AssignableSlot>[];
    for (final slot in source) {
      final start = _timeOnDate(date, slot['startTime']);
      final end = _timeOnDate(date, slot['endTime']);
      if (start == null || end == null || !end.isAfter(start)) continue;
      var cursor = start;
      while (!cursor.add(Duration(minutes: durationMinutes)).isAfter(end)) {
        final slotEnd = cursor.add(Duration(minutes: durationMinutes));
        final busy = _hasConflict(cursor, slotEnd);
        result.add(_AssignableSlot(start: cursor, end: slotEnd, busy: busy));
        cursor = cursor.add(const Duration(hours: 1));
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  bool _hasConflict(DateTime start, DateTime end) {
    for (final item in existingRequests) {
      if (item.id == widget.request.id) continue;
      final status = item.status.toLowerCase();
      if (status == 'cancelled' || status == 'completed') continue;
      final existingStart = item.scheduledDate;
      if (!_sameDay(existingStart, start)) continue;
      final existingEnd = existingStart.add(
        Duration(
          minutes: item.actualDurationMinutes > 0
              ? item.actualDurationMinutes
              : 60,
        ),
      );
      if (start.isBefore(existingEnd) && end.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _confirmAppointment() async {
    final start = selectedStart;
    if (start == null || isSaving) return;
    final end = start.add(Duration(minutes: durationMinutes));
    if (_hasConflict(start, end)) {
      _snack(
        'This time slot is no longer available. Please select another time.',
      );
      await _loadSlots();
      setState(() => selectedStart = null);
      return;
    }
    setState(() => isSaving = true);
    try {
      try {
        final success = await nurseRepository.updateRequestStatus(
          requestId: widget.request.id,
          status: 'accepted',
          nurseUserId: widget.providerUserId,
          scheduledAt: start,
          durationMinutes: durationMinutes,
          nurseNote: notesController.text.trim(),
        );
        if (!success) return;
      } catch (e) {
        final message = e.toString().toLowerCase();
        final alreadyConfirmed =
            message.contains('from confirmed') ||
            message.contains('already') ||
            message.contains('closed');
        if (!alreadyConfirmed) rethrow;
      }
      await widget.onChanged();
      if (!mounted) return;
      final updated = ServiceRequest.fromJson({
        ...widget.request.toJson(),
        'scheduledDate': start.toIso8601String(),
        'status': 'scheduled',
        'confirmedAt': DateTime.now().toIso8601String(),
        'actualDurationMinutes': durationMinutes,
      });
      await _saveLocalScheduledRequest(updated);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentConfirmedScreen(
            request: updated,
            currentUser: widget.currentUser,
            providerUserId: widget.providerUserId,
            scheduledStart: start,
            durationMinutes: durationMinutes,
            nurseNote: notesController.text.trim(),
            onChanged: widget.onChanged,
          ),
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _saveLocalScheduledRequest(ServiceRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'nurse_scheduled_requests_${widget.providerUserId}';
    final existing = prefs.getString(key);
    final items = <Map<String, dynamic>>[];
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = jsonDecode(existing);
        if (decoded is List) {
          items.addAll(
            decoded.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
      } catch (_) {}
    }
    items.removeWhere((item) => (item['id'] ?? '').toString() == request.id);
    items.add(request.toJson());
    await prefs.setString(key, jsonEncode(items));
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Assign Time Slot'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              color: AppColors.primaryDark,
              onPressed: () {},
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _patientSummary(),
                    const SizedBox(height: 18),
                    const Text(
                      'Select Available Time',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final slot in slots) _timeRow(slot),
                    const SizedBox(height: 18),
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: durations
                          .map(
                            (value) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: value == durations.last ? 0 : 8,
                                ),
                                child: _durationChip(value),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Notes (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLength: 200,
                      minLines: 3,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add a note for the patient',
                        filled: true,
                        fillColor: Colors.white,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: NurseUi.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: NurseUi.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: selectedStart == null || isSaving
                    ? null
                    : _confirmAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirm Appointment',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _patientSummary() {
    final name = widget.request.patientName.isEmpty
        ? 'Patient'
        : widget.request.patientName;
    final initial = name.characters.first.toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: NurseUi.softSurface,
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                widget.request.serviceType.isEmpty
                    ? 'Home Nursing Care'
                    : widget.request.serviceType,
                style: TextStyle(
                  color: NurseUi.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryDark,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.request.location.isEmpty
                          ? widget.request.patientAddress
                          : widget.request.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NurseUi.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeRow(_AssignableSlot slot) {
    final selected =
        selectedStart != null && selectedStart!.isAtSameMomentAs(slot.start);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: slot.busy
            ? null
            : () => setState(() => selectedStart = slot.start),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: slot.busy ? const Color(0xFFF3F6F6) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : NurseUi.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatTime(slot.start),
                  style: TextStyle(
                    color: slot.busy ? NurseUi.muted : NurseUi.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (slot.busy)
                Text(
                  'Busy',
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : const Color(0xFFB0BEC5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationChip(int value) {
    final selected = durationMinutes == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          durationMinutes = value;
          selectedStart = null;
          slots = _buildAssignableSlots(availabilitySlots);
        });
      },
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : NurseUi.border,
          ),
        ),
        child: Text(
          '$value min',
          style: TextStyle(
            color: selected ? Colors.white : NurseUi.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime? _timeOnDate(DateTime date, dynamic value) {
    final text = (value ?? '').toString();
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _weekdayName(DateTime date) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class AppointmentConfirmedScreen extends StatelessWidget {
  final ServiceRequest request;
  final User currentUser;
  final String providerUserId;
  final DateTime scheduledStart;
  final int durationMinutes;
  final String nurseNote;
  final Future<void> Function() onChanged;

  const AppointmentConfirmedScreen({
    super.key,
    required this.request,
    required this.currentUser,
    required this.providerUserId,
    required this.scheduledStart,
    required this.durationMinutes,
    required this.nurseNote,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canStartVisit = nurseRequestIsAccepted(request);
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Appointment Confirmed'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.language_rounded),
              color: AppColors.primaryDark,
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
          child: Column(
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 72,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Appointment Confirmed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NurseUi.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The appointment has been scheduled successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NurseUi.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              _summaryCard(),
              const SizedBox(height: 18),
              _outlineButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Contact Patient',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactPatientScreen(
                        request: request,
                        currentUserId: currentUser.userId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _outlineButton(
                icon: Icons.map_outlined,
                label: 'View Location',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientLocationScreen(request: request),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _primaryButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start Visit',
                onPressed: canStartVisit
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitDashboardScreen(
                              request: request,
                              user: currentUser,
                              onChanged: onChanged,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryLine(Icons.person_outline, 'Patient', _patientName),
          _summaryLine(
            Icons.calendar_today_outlined,
            'Date',
            _formatDate(scheduledStart),
          ),
          _summaryLine(
            Icons.access_time_rounded,
            'Time',
            _formatTime(scheduledStart),
          ),
          _summaryLine(
            Icons.timer_outlined,
            'Duration',
            '$durationMinutes minutes',
          ),
          _summaryLine(
            Icons.location_on_outlined,
            'Location',
            request.location.isEmpty
                ? request.patientAddress
                : request.location,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: NurseUi.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: NurseUi.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String get _patientName =>
      request.patientName.isEmpty ? 'Patient' : request.patientName;

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AssignableSlot {
  final DateTime start;
  final DateTime end;
  final bool busy;

  const _AssignableSlot({
    required this.start,
    required this.end,
    required this.busy,
  });
}

class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final User currentUser;
  final String providerUserId;
  final Future<void> Function() onChanged;
  final bool showVisitActions;

  const RequestDetailsScreen({
    super.key,
    required this.request,
    required this.currentUser,
    required this.providerUserId,
    required this.onChanged,
    this.showVisitActions = false,
  });

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late ServiceRequest request;
  final NurseRepository nurseRepository = const NurseRepository();
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
    final showStartVisit =
        widget.showVisitActions && nurseRequestIsAccepted(request);
    final hasBottomActions = !widget.showVisitActions || showStartVisit;

    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: NurseUi.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Request Details',
            style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.language_rounded),
              color: AppColors.primaryDark,
              onPressed: () => NurseUi.isArabic.value = !NurseUi.isArabic.value,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  hasBottomActions ? 96 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _patientHeaderCard(),
                    const SizedBox(height: 18),
                    _sectionTitle('Service Details'),
                    _serviceDetailsCard([
                      RequestInfoItem(
                        'Service Type',
                        _serviceText,
                        Icons.healing_rounded,
                      ),
                      RequestInfoItem(
                        'Visit Time',
                        '${_formatDate(request.scheduledDate)}  ${_formatTime(request.scheduledDate)}',
                        Icons.event_rounded,
                      ),
                      RequestInfoItem(
                        'Location',
                        request.location.isNotEmpty
                            ? request.location
                            : request.patientAddress,
                        Icons.location_on_rounded,
                      ),
                      RequestInfoItem(
                        'Notes',
                        _reasonText,
                        Icons.notes_rounded,
                      ),
                      RequestInfoItem(
                        'Location Note',
                        _locationNoteText,
                        Icons.apartment_rounded,
                      ),
                      RequestInfoItem(
                        'Estimated Fee',
                        request.price > 0
                            ? '${request.price.toStringAsFixed(0)} ILS'
                            : 'Not set',
                        Icons.payments_rounded,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _sectionTitle('Medical Information'),
                    _serviceDetailsCard(_medicalInformationItems),
                    const SizedBox(height: 18),
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
        bottomNavigationBar: !widget.showVisitActions
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: RequestActionButtons(
                    isSaving: isSaving,
                    onReject: _rejectRequest,
                    onAccept: _acceptRequest,
                  ),
                ),
              )
            : showStartVisit
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: _startVisitButton(),
                ),
              )
            : null,
      ),
    );
  }

  String get _patientName =>
      request.patientName.isNotEmpty ? request.patientName : request.patientId;

  Map<String, String> get _parsedNoteFields {
    final raw = request.notes ?? '';
    final fields = <String, String>{};
    for (final part in raw.split('|')) {
      final index = part.indexOf(':');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim().toLowerCase();
      final value = part.substring(index + 1).trim();
      if (value.isNotEmpty) fields[key] = value;
    }
    return fields;
  }

  String get _serviceText {
    final parsed = _parsedNoteFields['service'] ?? '';
    if (parsed.isNotEmpty) return parsed;
    return request.serviceType.isEmpty
        ? 'Home Nursing Care'
        : request.serviceType;
  }

  String get _appointmentTypeText {
    final parsed = _parsedNoteFields['appointmenttype'] ?? '';
    if (parsed.isEmpty) return 'Home';
    return parsed[0].toUpperCase() + parsed.substring(1);
  }

  String get _addressText {
    final parsed = _parsedNoteFields['address'] ?? '';
    if (parsed.isNotEmpty) return parsed;
    if (request.location.isNotEmpty) return request.location;
    return request.patientAddress.isEmpty ? 'Not set' : request.patientAddress;
  }

  String get _visitGpsText {
    final parsed = _parsedNoteFields['visitgps'] ?? '';
    if (parsed.isNotEmpty) return parsed;
    return _gpsText;
  }

  List<RequestInfoItem> get _medicalInformationItems {
    return [
      RequestInfoItem('Service', _serviceText, Icons.medical_services_rounded),
      RequestInfoItem(
        'Appointment Type',
        _appointmentTypeText,
        Icons.home_work_rounded,
      ),
      RequestInfoItem('Address', _addressText, Icons.location_on_rounded),
      RequestInfoItem('Current Case', _reasonText, Icons.assignment_rounded),
      RequestInfoItem('Reason', _reasonText, Icons.notes_rounded),
      RequestInfoItem('GPS Location', _visitGpsText, Icons.map_rounded),
    ];
  }

  String get _reasonText {
    final reason = request.reasonForVisit.trim();
    if (reason.isNotEmpty) return reason;
    final notes = _cleanComposedNotes(request.notes ?? '');
    return notes.isEmpty ? 'No notes added' : notes;
  }

  String get _locationNoteText {
    final direct = request.locationNote.trim();
    if (direct.isNotEmpty) return direct;
    final match = RegExp(
      r'LocationNote:\s*([^|]+)',
      caseSensitive: false,
    ).firstMatch(request.notes ?? '');
    final parsed = match?.group(1)?.trim() ?? '';
    return parsed.isEmpty ? 'No location note' : parsed;
  }

  String _cleanComposedNotes(String raw) {
    var value = raw;
    for (final pattern in [
      r'Service:\s*[^|]+',
      r'AppointmentType:\s*[^|]+',
      r'Address:\s*[^|]+',
      r'VisitGPS:\s*[^|]+',
      r'LocationNote:\s*[^|]+',
    ]) {
      value = value.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }
    return value
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
  }

  String get _gpsText {
    if (request.gpsLat == null || request.gpsLng == null) return 'Not set';
    return '${request.gpsLat!.toStringAsFixed(5)}, ${request.gpsLng!.toStringAsFixed(5)}';
  }

  Widget _patientHeaderCard() {
    return PatientInfoCard(
      name: _patientName,
      ageText: request.patientAge > 0
          ? '${request.patientAge} years'
          : 'Age not set',
      location: request.location.isNotEmpty
          ? request.location
          : request.patientAddress,
      statusLabel: _statusLabel(request.status),
      statusColor: _statusColor(request.status),
    );
  }

  Widget _serviceDetailsCard(List<RequestInfoItem> items) {
    return ServiceDetailsCard(items: items);
  }

  Future<void> _acceptRequest() async {
    setState(() => isSaving = true);
    try {
      var accepted = ServiceRequest.fromJson({
        ...request.toJson(),
        'status': 'accepted',
        'confirmedAt': DateTime.now().toIso8601String(),
      });

      if (!nurseRequestIsAccepted(request)) {
        try {
          final success = await nurseRepository.createAppointment(
            request: request,
            nurseUserId: widget.providerUserId,
          );
          if (!success) return;
        } catch (e) {
          final message = e.toString().toLowerCase();
          final alreadyAccepted =
              message.contains('from confirmed') ||
              message.contains('already') ||
              message.contains('closed');
          if (!alreadyAccepted) rethrow;
        }
      }

      await widget.onChanged();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentConfirmedScreen(
            request: accepted,
            currentUser: widget.currentUser,
            providerUserId: widget.providerUserId,
            scheduledStart: accepted.scheduledDate,
            durationMinutes: accepted.actualDurationMinutes > 0
                ? accepted.actualDurationMinutes
                : 60,
            nurseNote: '',
            onChanged: widget.onChanged,
          ),
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _rejectRequest() async {
    final reason = await _askRejectReason();
    if (reason == null) return;
    await _runAction(() async {
      final success = await nurseRepository.updateRequestStatus(
        requestId: request.id,
        status: 'cancelled',
        nurseUserId: widget.providerUserId,
      );
      if (!success || !mounted) return;
      await widget.onChanged();
      if (!mounted) return;
      Navigator.pop(context);
    }, 'Request rejected');
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject request'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
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

  Widget _noteBox(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NurseUi.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NurseUi.border.withValues(alpha: 0.7)),
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

  Widget _startVisitButton() {
    return _primaryAction('Start Visit', Icons.play_arrow_rounded, _startVisit);
  }

  Widget _endVisitButton() {
    return _primaryAction('End Visit', Icons.stop_rounded, _endVisit);
  }

  Widget _primaryAction(
    String label,
    IconData icon,
    Future<void> Function() action,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
        border: Border.all(color: NurseUi.border.withValues(alpha: 0.8)),
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
                    subtitle: Text(
                      activity.arLabel,
                      style: TextStyle(color: NurseUi.muted),
                    ),
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
        border: Border.all(color: NurseUi.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Submit Visit Report'),
          _reportField('Patient Condition Before Visit', beforeController),
          _reportField(
            'Services Provided',
            notesController,
            initial: serviceSummary,
          ),
          _reportField('Vital Signs', vitalsController),
          _reportField('Patient Condition After Visit', afterController),
          _reportField('Recommendations', recommendationsController),
          SwitchListTile(
            value: needsDoctorFollowUp,
            onChanged: (value) => setState(() => needsDoctorFollowUp = value),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Need Doctor Follow-up?',
              style: TextStyle(
                color: NurseUi.text,
                fontWeight: FontWeight.bold,
              ),
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

  Future<void> _runAction(
    Future<void> Function() action,
    String success,
  ) async {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    if (nurseRequestNeedsDecision(status)) return 'New';
    switch (status) {
      case 'assigned':
      case 'confirmed':
      case 'scheduled':
        return 'Confirmed';
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

  Color _statusColor(String status) {
    if (nurseRequestNeedsDecision(status)) return const Color(0xFF1570EF);
    switch (status) {
      case 'assigned':
      case 'confirmed':
      case 'scheduled':
        return AppColors.primaryDark;
      case 'in_progress':
        return const Color(0xFFF79009);
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class RequestInfoItem {
  final String label;
  final String value;
  final IconData icon;

  RequestInfoItem(this.label, this.value, this.icon);
}

class PatientInfoCard extends StatelessWidget {
  final String name;
  final String ageText;
  final String location;
  final String statusLabel;
  final Color statusColor;

  const PatientInfoCard({
    super.key,
    required this.name,
    required this.ageText,
    required this.location,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.characters.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: NurseUi.isDarkMode.value ? 0.14 : 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NurseUi.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ageText,
                  style: TextStyle(color: NurseUi.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primaryDark,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: NurseUi.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceDetailsCard extends StatelessWidget {
  final List<RequestInfoItem> items;

  const ServiceDetailsCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NurseUi.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _DetailLine(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final RequestInfoItem item;

  const _DetailLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, color: AppColors.primaryDark, size: 19),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(color: NurseUi.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                item.value.isEmpty ? 'Not set' : item.value,
                style: TextStyle(
                  color: NurseUi.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RequestActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  const RequestActionButtons({
    super.key,
    required this.isSaving,
    required this.onReject,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB42318),
              side: const BorderSide(color: Color(0xFFFF6B6B)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: isSaving ? null : onReject,
            child: const Text(
              'Reject Request',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: isSaving ? null : onAccept,
            child: const Text(
              'Accept Request',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _NursingActivity {
  final String label;
  final String arLabel;
  final TextEditingController notesController = TextEditingController();
  bool done = false;

  _NursingActivity(this.label, this.arLabel);
}
