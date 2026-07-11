import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/nurse/screens/nurse_contact_patient_flow.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/features/nurse/screens/nurse_patient_medical_records_screen.dart';
import 'package:carelink/features/nurse/services/nurse_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/models/visit_report.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/shared/services/report_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';

import 'nurse_visit_reports.dart';
import 'nurse_visit_tracking_screen.dart';
import 'nurse_ui.dart';

class NurseScheduleScreen extends StatefulWidget {
  const NurseScheduleScreen({super.key, required this.user});

  final User user;

  @override
  State<NurseScheduleScreen> createState() => _NurseScheduleScreenState();
}

class _NurseScheduleScreenState extends State<NurseScheduleScreen> {
  bool isLoading = true;
  int selectedFilter = 0;
  DateTime selectedDate = DateTime.now();
  List<ServiceRequest> requests = [];
  List<Map<String, dynamic>> slots = [];
  Timer? scheduleSyncTimer;
  final NurseRepository nurseRepository = const NurseRepository();

  @override
  void initState() {
    super.initState();
    _load();
    scheduleSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    scheduleSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => isLoading = true);
    final loadedRequests = await nurseRepository.getSchedule(
      widget.user.userId,
    );
    final loadedSlots = await ProviderProfileService.getAvailability(
      widget.user.userId,
    );
    final localSlots = await _loadLocalSlots();
    final localRequests = await _loadLocalScheduledRequests();
    final mergedRequests = _mergeRequests(loadedRequests, localRequests);
    if (!mounted) return;
    setState(() {
      requests = mergedRequests;
      slots = loadedSlots.isNotEmpty ? loadedSlots : localSlots;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('My Schedule')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF0F766E),
            onPressed: () {},
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              color: const Color(0xFF0F766E),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NurseMyAvailabilityScreen(
                      slots: slots,
                      user: widget.user,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              color: const Color(0xFF0F766E),
              onPressed: _openSetAvailability,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    _weekStrip(),
                    const SizedBox(height: 14),
                    _filterStrip(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          _dateHeaderTitle,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _headerDateText,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _scheduleCards(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filterStrip() {
    const filters = [
      'All',
      'Upcoming',
      'In Progress',
      'Completed',
      'Cancelled',
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedFilter == index;
          return InkWell(
            onTap: () => setState(() => selectedFilter = index),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFE9F7F4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                filters[index],
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _weekStrip() {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = _sameDay(day, selectedDate);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => selectedDate = day),
            child: Container(
              width: 42,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE2F5F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: selected
                    ? Border.all(color: const Color(0xFF0F766E), width: 1.4)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF607D8B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF151823),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scheduleCards() {
    final appointments = _visibleAppointments;
    if (appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF0F766E),
              size: 38,
            ),
            SizedBox(height: 10),
            Text(
              'No appointments for this day',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          for (var i = 0; i < appointments.length; i++) ...[
            _scheduleListRow(appointments[i]),
            if (i != appointments.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _scheduleListRow(ServiceRequest request) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisitDashboardScreen(
            request: request,
            user: widget.user,
            onChanged: () => _load(),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _timeStacked(request.scheduledDate),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 10,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE8F1EF)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFDDF4EF),
                    child: Text(
                      _initial(request.patientName),
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
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
                          _shortPatientName(request.patientName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.serviceType.isEmpty
                              ? 'Home Nursing Care'
                              : request.serviceType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF0F766E),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _locationLabel(request),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF5B7F7A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _chip(_scheduleStatusLabel(request.status), request.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _openSetAvailability() async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => NurseSetAvailabilityScreen(
          user: widget.user,
          initialSlots: slots,
          selectedDate: selectedDate,
        ),
      ),
    );
    if (updated == null) return;
    setState(() => slots = updated);
    await _saveLocalSlots(updated);
  }

  Future<List<Map<String, dynamic>>> _loadLocalSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localAvailabilityKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<ServiceRequest>> _loadLocalScheduledRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      'nurse_scheduled_requests_${widget.user.userId}',
    );
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  ServiceRequest.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  List<ServiceRequest> _mergeRequests(
    List<ServiceRequest> remote,
    List<ServiceRequest> local,
  ) {
    final byId = <String, ServiceRequest>{};
    for (final request in remote) {
      byId[request.id] = request;
    }
    for (final request in local) {
      byId[request.id] = request;
    }
    return byId.values.toList();
  }

  Future<void> _saveLocalSlots(List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localAvailabilityKey, jsonEncode(value));
  }

  String get _localAvailabilityKey =>
      'nurse_availability_slots_${widget.user.userId}';

  List<ServiceRequest> get _visibleAppointments {
    final list = requests.where((r) {
      final status = r.status.toLowerCase();
      if (!_sameDay(r.scheduledDate, selectedDate)) return false;
      final accepted =
          status == 'assigned' ||
          status == 'scheduled' ||
          status == 'confirmed' ||
          status == 'accepted';
      if (!accepted) return false;
      switch (selectedFilter) {
        case 0:
        case 1:
          return true;
        case 2:
        case 3:
        case 4:
          return false;
        default:
          return false;
      }
    }).toList();
    list.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return list;
  }

  String get _dateHeaderTitle {
    final today = DateTime.now();
    final prefix = _sameDay(selectedDate, today)
        ? 'Today'
        : _weekdayLabel(selectedDate);
    return '$prefix, ${_shortDate(selectedDate)}';
  }

  String get _headerDateText {
    final count = _visibleAppointments.length;
    return '$count ${count == 1 ? 'appointment' : 'appointments'}';
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  String _shortDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _timeStacked(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m\n${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _locationLabel(ServiceRequest request) {
    final value = request.location.trim().isNotEmpty
        ? request.location.trim()
        : request.patientAddress.trim();
    return value.isEmpty ? 'Location not set' : value;
  }

  String _shortPatientName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Patient';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts[1][0]}.';
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'P' : trimmed.characters.first.toUpperCase();
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
      case 'pending_provider_approval':
      case 'pending_payment':
      case 'payment_pending':
        return 'Pending';
      case 'assigned':
      case 'scheduled':
      case 'accepted':
      case 'confirmed':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _scheduleStatusLabel(String status) {
    final value = status.toLowerCase();
    if (value == 'assigned' ||
        value == 'scheduled' ||
        value == 'accepted' ||
        value == 'confirmed') {
      return 'Upcoming';
    }
    return _statusLabel(status);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
      case 'pending_provider_approval':
      case 'pending_payment':
      case 'payment_pending':
        return const Color(0xFFF59E0B);
      case 'assigned':
      case 'scheduled':
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF22C55E);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF0F766E);
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class NurseSetAvailabilityScreen extends StatefulWidget {
  const NurseSetAvailabilityScreen({
    super.key,
    required this.user,
    required this.initialSlots,
    required this.selectedDate,
  });

  final User user;
  final List<Map<String, dynamic>> initialSlots;
  final DateTime selectedDate;

  @override
  State<NurseSetAvailabilityScreen> createState() =>
      _NurseSetAvailabilityScreenState();
}

class _NurseSetAvailabilityScreenState
    extends State<NurseSetAvailabilityScreen> {
  bool available = true;
  bool eligibilityLoading = true;
  bool canManageAvailability = false;
  String eligibilityMessage =
      'Accept your admin-set hourly rate before setting availability.';
  String approvedSpecialization = 'Nursing';
  double approvedHourlyRate = 0;
  final workingDays = <String>{};
  late List<Map<String, dynamic>> slots;

  @override
  void initState() {
    super.initState();
    slots = widget.initialSlots
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _syncWorkingDaysFromSlots();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ProviderProfileService.baseUrl}/nurse/rate-status/${widget.user.userId}',
        ),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          canManageAvailability = data['canWork'] == true;
          eligibilityMessage =
              (data['reason'] ??
                      'Accept your admin-set hourly rate before setting availability.')
                  .toString();
          approvedSpecialization = (data['specialization'] ?? 'Nursing')
              .toString();
          approvedHourlyRate = _double(data['providerRate']);
          eligibilityLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      canManageAvailability = false;
      eligibilityMessage =
          'Could not verify your rate approval status. Please try again.';
      eligibilityLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Set Availability')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            if (eligibilityLoading)
              const LinearProgressIndicator(minHeight: 3)
            else if (!canManageAvailability) ...[
              _lockedCard(),
              const SizedBox(height: 14),
            ] else ...[
              _approvedRateCard(),
              const SizedBox(height: 14),
            ],
            _card(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: available,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Availability Status',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(NurseUi.t('You are Available')),
                onChanged: (value) => setState(() => available = value),
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Working Days',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select days you are available',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final day in const [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday',
                      ])
                        _dayChip(day),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Working Hours',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set your daily available time slots',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final slot in slots) _slotEditRow(slot),
                  TextButton.icon(
                    onPressed: canManageAvailability ? _openAddTimeSlot : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Time Slot'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: canManageAvailability ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Availability',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _lockedCard() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              eligibilityMessage,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvedRateCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyRow('Specialization', approvedSpecialization),
          const Divider(height: 22),
          _readOnlyRow('Approved Hourly Rate', _money(approvedHourlyRate)),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _dayChip(String day) {
    final selected = workingDays.contains(day);
    return FilterChip(
      label: Text(day.substring(0, 3)),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF607D8B),
        fontWeight: FontWeight.w900,
      ),
      onSelected: (value) {
        setState(() {
          if (value) {
            workingDays.add(day);
          } else {
            workingDays.remove(day);
          }
        });
      },
    );
  }

  Widget _slotEditRow(Map<String, dynamic> slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _timeBox(_displayTime(slot['startTime']))),
          const SizedBox(width: 8),
          Expanded(child: _timeBox(_displayTime(slot['endTime']))),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFF4D4F),
            ),
            onPressed: () => setState(() => slots.remove(slot)),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String text) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7F0EE)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Future<void> _openAddTimeSlot() async {
    final slot = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => NurseAddTimeSlotScreen(
          specialization: approvedSpecialization,
          approvedHourlyRate: approvedHourlyRate,
          referenceDate: widget.selectedDate,
        ),
      ),
    );
    if (slot == null) return;
    setState(() {
      slots.add(slot);
      _syncWorkingDaysFromSlots();
    });
  }

  void _syncWorkingDaysFromSlots() {
    workingDays
      ..clear()
      ..addAll(
        slots
            .map((slot) => (slot['day'] ?? '').toString().trim())
            .where((day) => day.isNotEmpty),
      );
  }

  Future<void> _save() async {
    final providerId = await _providerId();
    if (providerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nurse session is missing. Please sign in again.'),
        ),
      );
      return;
    }
    final selectedSlots = slots.map(_slotWithDate).toList();
    final hourlySlots = ProviderProfileService.expandHourlyAvailabilitySlots(
      selectedSlots,
    );
    await _saveLocalSlots(hourlySlots);
    final publishedSlots = selectedSlots.expand(_slotsForPublishing).toList();
    final success = await ProviderProfileService.saveAvailability(
      providerId,
      publishedSlots,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Availability saved successfully'
              : (ProviderProfileService.lastError ??
                    'Could not publish availability. Check the connection and save again.'),
        ),
      ),
    );
    if (success) Navigator.pop(context, hourlySlots);
  }

  Future<void> _saveLocalSlots(List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'nurse_availability_slots_${widget.user.userId}';
    await prefs.setString(key, jsonEncode(value));
  }

  Map<String, dynamic> _slotWithDate(Map<String, dynamic> slot) {
    final copy = Map<String, dynamic>.from(slot);
    final existingDate = (copy['date'] ?? '').toString().trim();
    if (existingDate.isNotEmpty) return copy;
    final day = (copy['day'] ?? '').toString().trim();
    if (day.isNotEmpty) {
      copy['date'] = _dateKey(_dateForSelectedDay(day));
    }
    return copy;
  }

  List<Map<String, dynamic>> _slotsForPublishing(Map<String, dynamic> slot) {
    final dated = Map<String, dynamic>.from(slot);
    final date = (dated['date'] ?? '').toString().trim();
    if (date.isNotEmpty) return [dated];
    return [dated];
  }

  Future<String> _providerId() async {
    final id = widget.user.userId.trim();
    if (id.isNotEmpty) return id;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('session_user_id') ?? '').trim();
  }

  String _displayTime(dynamic value) {
    final text = (value ?? '').toString();
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text.isEmpty ? '--:--' : text;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(num value) {
    final fixed = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$fixed ILS/hour';
  }

  DateTime _dateForSelectedDay(String selectedDay) {
    final target = _weekdayNumber(selectedDay);
    final selected = widget.selectedDate;
    final reference = DateTime(selected.year, selected.month, selected.day);
    if (target == null) return reference;
    final offset = (target - reference.weekday + 7) % 7;
    final date = reference.add(Duration(days: offset));
    return DateTime(date.year, date.month, date.day);
  }

  int? _weekdayNumber(String day) {
    switch (day.toLowerCase().trim()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
    }
    return null;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

}

class NurseAddTimeSlotScreen extends StatefulWidget {
  const NurseAddTimeSlotScreen({
    super.key,
    required this.specialization,
    required this.approvedHourlyRate,
    required this.referenceDate,
  });

  final String specialization;
  final double approvedHourlyRate;
  final DateTime referenceDate;

  @override
  State<NurseAddTimeSlotScreen> createState() => _NurseAddTimeSlotScreenState();
}

class _NurseAddTimeSlotScreenState extends State<NurseAddTimeSlotScreen> {
  late String day;
  late DateTime selectedSlotDate;
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 13, minute: 0);
  final locationController = TextEditingController(text: 'Birzeit, Ramallah');
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedSlotDate = DateTime(
      widget.referenceDate.year,
      widget.referenceDate.month,
      widget.referenceDate.day,
    );
    day = _dayName(selectedSlotDate);
  }

  @override
  void dispose() {
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Add Time Slot')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            _label('Select Date'),
            _dateTile(_formatDate(selectedSlotDate), _pickSlotDate),
            const SizedBox(height: 16),
            _label('Select Day'),
            _dropdown(day, const [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ], (v) {
              if (v == null) return;
              setState(() {
                day = v;
                selectedSlotDate = _dateForSelectedDay(v);
              });
            }),
            const SizedBox(height: 16),
            _label('Start Time'),
            _timeTile(_formatClock(start), () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: start,
              );
              if (picked != null) setState(() => start = picked);
            }),
            const SizedBox(height: 16),
            _label('End Time'),
            _timeTile(_formatClock(end), () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: end,
              );
              if (picked != null) setState(() => end = picked);
            }),
            const SizedBox(height: 16),
            _label('Specialization'),
            _readOnlyField(widget.specialization),
            const SizedBox(height: 16),
            _label('Approved Hourly Rate'),
            _readOnlyField(_money(widget.approvedHourlyRate)),
            const SizedBox(height: 16),
            _label('Location'),
            TextField(
              controller: locationController,
              decoration: _decoration('Visit location'),
            ),
            const SizedBox(height: 16),
            _label('Notes (Optional)'),
            TextField(
              controller: notesController,
              maxLines: 4,
              maxLength: 150,
              decoration: _decoration('Add a note...'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'day': day,
                    'date': _dateKey(selectedSlotDate),
                    'startTime': _format24(start),
                    'endTime': _format24(end),
                    'serviceType': widget.specialization,
                    'specialization': widget.specialization,
                    'approvedHourlyRate': widget.approvedHourlyRate,
                    'location': locationController.text.trim(),
                    'notes': notesController.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Slot',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF607D8B),
        ),
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _decoration(null),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _readOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0ECEA)),
      ),
      child: Text(
        value.trim().isEmpty ? 'Not set' : value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _dateTile(String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(null),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(null),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.access_time_rounded, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _format24(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickSlotDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedSlotDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      selectedSlotDate = DateTime(picked.year, picked.month, picked.day);
      day = _dayName(selectedSlotDate);
    });
  }

  DateTime _dateForSelectedDay(String selectedDay) {
    final reference = DateTime(
      selectedSlotDate.year,
      selectedSlotDate.month,
      selectedSlotDate.day,
    );
    final target = _weekdayNumber(selectedDay);
    if (target == null) return reference;
    final offset = (target - reference.weekday + 7) % 7;
    final date = reference.add(Duration(days: offset));
    return DateTime(date.year, date.month, date.day);
  }

  int? _weekdayNumber(String day) {
    switch (day.toLowerCase().trim()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
    }
    return null;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _money(num value) {
    final fixed = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$fixed ILS/hour';
  }

  String _formatClock(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

class NurseMyAvailabilityScreen extends StatefulWidget {
  const NurseMyAvailabilityScreen({
    super.key,
    required this.user,
    required this.slots,
  });

  final User user;
  final List<Map<String, dynamic>> slots;

  @override
  State<NurseMyAvailabilityScreen> createState() =>
      _NurseMyAvailabilityScreenState();
}

class _NurseMyAvailabilityScreenState extends State<NurseMyAvailabilityScreen> {
  late List<Map<String, dynamic>> slots;
  bool available = true;

  @override
  void initState() {
    super.initState();
    slots = widget.slots.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('My Availability')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'You are Available',
                          style: TextStyle(
                            color: Color(0xFF079179),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Patients can book your available slots',
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: available,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => available = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'This Week',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jun 15 - Jun 21',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final day in const [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ])
                    _dayRow(day),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(String day) {
    final daySlots = slots.where((slot) => slot['day'] == day).toList();
    final short = day.substring(0, 3);
    final date = {
      'Monday': '15',
      'Tuesday': '16',
      'Wednesday': '17',
      'Thursday': '18',
      'Friday': '19',
      'Saturday': '20',
      'Sunday': '21',
    }[day]!;
    final selected = day == 'Wednesday';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: daySlots.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NurseTimeSlotDetails(
                  slot: daySlots.first,
                  onDeleted: () async {
                    setState(() => slots.remove(daySlots.first));
                    await _saveSlots();
                  },
                ),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4F6F2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    short,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: daySlots.isEmpty
                  ? const Text(
                      'Not available',
                      style: TextStyle(
                        color: Color(0xFF78909C),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final slot in daySlots)
                          Text(
                            '${_displayTime(slot['startTime'])} - ${_displayTime(slot['endTime'])}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BEC5)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return NurseUi.cardDecoration();
  }

  Future<void> _saveSlots() async {
    final hourlySlots = ProviderProfileService.expandHourlyAvailabilitySlots(
      slots,
    );
    await ProviderProfileService.saveAvailability(
      widget.user.userId,
      slots.expand(_slotsForPublishing).toList(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'nurse_availability_slots_${widget.user.userId}',
      jsonEncode(hourlySlots),
    );
  }

  List<Map<String, dynamic>> _slotsForPublishing(Map<String, dynamic> slot) {
    final dated = Map<String, dynamic>.from(slot);
    final date = (dated['date'] ?? '').toString().trim();
    if (date.isNotEmpty) return [dated];
    return [dated];
  }

  String _displayTime(dynamic value) {
    final text = (value ?? '').toString();
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text.isEmpty ? '--:--' : text;
  }
}

class NurseTimeSlotDetails extends StatelessWidget {
  const NurseTimeSlotDetails({
    super.key,
    required this.slot,
    required this.onDeleted,
  });

  final Map<String, dynamic> slot;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Time Slot Details')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge('Available Slot'),
                  const SizedBox(height: 18),
                  _detail(Icons.calendar_today_rounded, 'Wed, Jun 17, 2026'),
                  _detail(
                    Icons.access_time_rounded,
                    '${slot['startTime']} - ${slot['endTime']}',
                  ),
                  _detail(
                    Icons.medical_services_outlined,
                    'Service Type\n${slot['serviceType'] ?? 'Home visit'}',
                  ),
                  _detail(
                    Icons.location_on_outlined,
                    'Location\n${slot['location'] ?? 'Birzeit, Ramallah'}',
                  ),
                  _detail(
                    Icons.note_alt_outlined,
                    'Notes\n${slot['notes'] ?? 'Available for home nursing care visits.'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Edit Slot'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await onDeleted();
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Delete Slot'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFBFE9D7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class VisitDashboardScreen extends StatefulWidget {
  const VisitDashboardScreen({
    super.key,
    required this.request,
    required this.user,
    required this.onChanged,
  });

  final ServiceRequest request;
  final User user;
  final Future<void> Function() onChanged;

  @override
  State<VisitDashboardScreen> createState() => _VisitDashboardScreenState();
}

class _VisitDashboardScreenState extends State<VisitDashboardScreen> {
  late ServiceRequest request;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    request = widget.request;
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Visit Dashboard')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.phone_rounded),
              color: AppColors.primaryDark,
              onPressed: _openContactPatient,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _patientCard(),
              const SizedBox(height: 16),
              _appointmentTimeCard(),
              const SizedBox(height: 16),
              _timerPreviewCard(),
              const SizedBox(height: 18),
              const Text(
                'Quick Actions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _quickActionsGrid(),
            ],
          ),
        ),
        bottomNavigationBar: _bottomAction(),
      ),
    );
  }

  Widget _patientCard() {
    final name = request.patientName.isEmpty ? 'Patient' : request.patientName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFDDF2EF),
            child: Text(
              name.characters.first.toUpperCase(),
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
                const SizedBox(height: 4),
                Text(
                  request.patientAge > 0
                      ? '${request.patientAge} years'
                      : 'Age not set',
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
                        request.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _chip(_statusLabel(request.status), _statusColor(request.status)),
        ],
      ),
    );
  }

  Widget _appointmentTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 12),
          Text(
            _formatTime(request.scheduledDate),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF78909C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _durationText,
            style: const TextStyle(
              color: Color(0xFF607D8B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerPreviewCard() {
    final canStart = _canStartVisit(request.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Visit Timer',
                  style: TextStyle(
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  '00:00:00',
                  style: TextStyle(
                    color: Color(0xFF151823),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Not started yet',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isSaving || !canStart ? null : _openVisitTracking,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (canStart ? AppColors.primary : const Color(0xFF94A3B8))
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: canStart ? AppColors.primary : const Color(0xFF94A3B8),
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: canStart
                    ? AppColors.primaryDark
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsGrid() {
    final actions = [
      (Icons.favorite_border_rounded, 'Vital Signs'),
      (Icons.assignment_outlined, 'Care Plan'),
      (Icons.medication_outlined, 'Medication'),
      (Icons.note_alt_outlined, 'Notes'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NurseUi.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.$1, color: AppColors.primaryDark, size: 22),
                const SizedBox(height: 8),
                Text(
                  action.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openContactPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPatientScreen(
          request: request,
          currentUserId: widget.user.userId,
        ),
      ),
    );
  }

  Widget? _bottomAction() {
    final status = request.status.toLowerCase();
    if (_canStartVisit(status)) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : _openVisitTracking,
              icon: const Icon(Icons.directions_car_outlined),
              label: Text(isSaving ? 'Starting...' : 'On The Way'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (status == 'in_progress') {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _continueVisit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Continue Visit',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      );
    }
    if (status == 'waiting_report') {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _openCreateReport,
              icon: const Icon(Icons.description_outlined),
              label: const Text(
                'Create Report',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  Future<void> _openVisitTracking() async {
    if (!_canStartVisit(request.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start Visit is available only for accepted visits.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NurseVisitTrackingScreen(
          request: request,
          onStartVisit: _startVerifiedVisit,
        ),
      ),
    );
  }

  Future<bool> _startVerifiedVisit(DateTime startTime) async {
    setState(() => isSaving = true);
    try {
      final success = await ServiceRequestService.startVisit(
        request.id,
        providerUserId: widget.user.userId,
      );
      if (!success) return false;
      await widget.onChanged();
      if (!mounted) return false;
      final startedRequest = ServiceRequest.fromJson({
        ...request.toJson(),
        'status': 'in_progress',
        'actualStartedAt': startTime.toIso8601String(),
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VisitInProgressScreen(
            request: startedRequest,
            user: widget.user,
            startTime: startTime,
            onChanged: widget.onChanged,
          ),
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _continueVisit() {
    final startTime = request.actualStartedAt ?? DateTime.now();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisitInProgressScreen(
          request: request,
          user: widget.user,
          startTime: startTime,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  void _openCreateReport() {
    final startTime = request.actualStartedAt ?? request.scheduledDate;
    final elapsed = request.actualDurationMinutes > 0
        ? Duration(minutes: request.actualDurationMinutes)
        : DateTime.now().difference(startTime);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReportScreen(
          request: request,
          user: widget.user,
          startTime: startTime,
          visitNotes: '',
          checklist: const <String, bool>{
            'Vital signs': true,
            'Medication administration': true,
            'Personal care': false,
            'Patient education': false,
            'Environment safety': false,
          },
          elapsed: elapsed,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  bool _canStartVisit(String status) {
    final value = status.toLowerCase().trim();
    return value == 'accepted' ||
        value == 'assigned' ||
        value == 'scheduled' ||
        value == 'confirmed';
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return NurseUi.cardDecoration();
  }

  int get _durationMinutes {
    if (request.actualDurationMinutes > 0) return request.actualDurationMinutes;
    final value = request.expectedDurationHours * 60;
    return value <= 0 ? 60 : value;
  }

  String get _durationText => '$_durationMinutes minutes';

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
      case 'scheduled':
      case 'pending':
        return 'Upcoming';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return const Color(0xFFFFDFA8);
      case 'completed':
        return const Color(0xFFC9F2D7);
      case 'cancelled':
        return const Color(0xFFFFD8D8);
      default:
        return const Color(0xFFD8F5EC);
    }
  }
}

class VisitInProgressScreen extends StatefulWidget {
  const VisitInProgressScreen({
    super.key,
    required this.request,
    required this.user,
    required this.startTime,
    required this.onChanged,
  });

  final ServiceRequest request;
  final User user;
  final DateTime startTime;
  final Future<void> Function() onChanged;

  @override
  State<VisitInProgressScreen> createState() => _VisitInProgressScreenState();
}

class _VisitInProgressScreenState extends State<VisitInProgressScreen> {
  final notesController = TextEditingController();
  late Timer timer;
  late Duration elapsed;
  bool isCompleting = false;
  final checklist = <String, bool>{
    'Vital signs': false,
    'Medication administration': false,
    'Personal care': false,
    'Patient education': false,
    'Environment safety': false,
  };

  @override
  void initState() {
    super.initState();
    elapsed = DateTime.now().difference(widget.startTime);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => elapsed = DateTime.now().difference(widget.startTime));
    });
  }

  @override
  void dispose() {
    timer.cancel();
    notesController.dispose();
    super.dispose();
  }

  void _openContactPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPatientScreen(
          request: widget.request,
          currentUserId: widget.user.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = checklist.values.where((done) => done).length;
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Visit In Progress')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.phone_rounded),
              color: AppColors.primaryDark,
              onPressed: _openContactPatient,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _visitTrackingProgress(),
              const SizedBox(height: 16),
              _visitInProgressBanner(),
              const SizedBox(height: 16),
              _timerCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Visit Checklist',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '$completed/${checklist.length} Completed',
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _checklistCard(),
              const SizedBox(height: 16),
              const Text(
                'Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                minLines: 4,
                maxLines: 5,
                decoration: _inputDecoration('Add notes about the visit...'),
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
                onPressed: isCompleting ? null : _completeVisit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isCompleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Complete Visit',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit Timer',
                  style: TextStyle(
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _formatElapsed(elapsed),
                  style: const TextStyle(
                    color: Color(0xFF151823),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'In Progress',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitTrackingProgress() {
    const labels = ['On The Way', 'Arrived', 'In Progress'];
    const icons = [
      Icons.directions_car,
      Icons.location_on,
      Icons.medical_services_outlined,
    ];
    return Row(
      children: List.generate(labels.length, (index) {
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icons[index], color: Colors.white, size: 21),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      child: Text(
                        labels[index],
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 24,
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 25),
                  color: AppColors.primary,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _visitInProgressBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC5E8E0)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.medical_services_outlined,
              color: AppColors.primaryDark,
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visit In Progress',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Care session is currently in progress',
                  style: TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: checklist.keys.map((label) {
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            value: checklist[label],
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onChanged: (value) {
              setState(() => checklist[label] = value == true);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _completeVisit() async {
    setState(() => isCompleting = true);
    final payload = checklist.entries
        .map(
          (entry) => {
            'activity': entry.key,
            'done': entry.value,
            'notes': entry.key == 'Visit notes'
                ? notesController.text.trim()
                : '',
          },
        )
        .toList();
    try {
      final ended = await ServiceRequestService.endVisit(
        widget.request.id,
        providerUserId: widget.user.userId,
        nursingActivities: payload,
      );
      if (!ended) return;
      await widget.onChanged();
      if (!mounted) return;
      final now = DateTime.now();
      final completedRequest = ServiceRequest.fromJson({
        ...widget.request.toJson(),
        'status': 'waiting_report',
        'actualEndedAt': now.toIso8601String(),
        'actualDurationMinutes': elapsed.inMinutes,
        'nursingActivities': payload,
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateReportScreen(
            request: completedRequest,
            user: widget.user,
            startTime: widget.startTime,
            visitNotes: notesController.text.trim(),
            checklist: checklist,
            elapsed: elapsed,
            onChanged: widget.onChanged,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isCompleting = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: NurseUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: NurseUi.border),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return NurseUi.cardDecoration();
  }

  String _formatElapsed(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({
    super.key,
    required this.request,
    required this.user,
    required this.startTime,
    required this.visitNotes,
    required this.checklist,
    required this.elapsed,
    required this.onChanged,
  });

  final ServiceRequest request;
  final User user;
  final DateTime startTime;
  final String visitNotes;
  final Map<String, bool> checklist;
  final Duration elapsed;
  final Future<void> Function() onChanged;

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final pageController = PageController();
  final NurseRepository nurseRepository = const NurseRepository();
  final bloodPressureController = TextEditingController();
  final heartRateController = TextEditingController();
  final temperatureController = TextEditingController();
  final oxygenController = TextEditingController();
  final symptomsController = TextEditingController();
  final reportNotesController = TextEditingController();
  final followUpInstructionsController = TextEditingController();
  final otherCareController = TextEditingController();
  var currentPage = 0;
  var painLevel = 1.0;
  var stable = true;
  var followUpNeeded = false;
  DateTime? followUpDate;
  bool isSaving = false;
  final careProvided = <String, bool>{
    'Medication administration': true,
    'Wound care': false,
    'IV support': false,
    'Vital signs monitoring': true,
    'Patient education': false,
    'Hygiene care': false,
    'Respiratory therapy': false,
    'Other care': false,
  };
  final medications = <_MedicationEntry>[];
  final attachments = <XFile>[];
  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    symptomsController.text = widget.request.reasonForVisit.isNotEmpty
        ? widget.request.reasonForVisit
        : widget.request.medicalCondition;
    reportNotesController.text = widget.visitNotes;
    followUpDate = widget.request.scheduledDate.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    bloodPressureController.dispose();
    heartRateController.dispose();
    temperatureController.dispose();
    oxygenController.dispose();
    symptomsController.dispose();
    reportNotesController.dispose();
    followUpInstructionsController.dispose();
    otherCareController.dispose();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Create Report')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: _stepIndicator(),
            ),
            Expanded(
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _pageFrame(_patientInfoPage()),
                  _pageFrame(_conditionAndVitalsPage()),
                  _pageFrame(_careAndMedicationPage()),
                  _pageFrame(_summaryPage()),
                  _pageFrame(_reviewPage()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentPage == 0 || isSaving ? null : _back,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : currentPage == 4
                        ? _submitReport
                        : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            currentPage == 4 ? 'Submit Report' : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _pageFrame(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: child,
    );
  }

  Widget _stepIndicator() {
    final labels = ['Patient Info', 'Care', 'Summary', 'Review'];
    final activeStep = _activeStep;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= activeStep
                        ? AppColors.primary
                        : const Color(0xFFE6F1EF),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= activeStep ? Colors.white : NurseUi.muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: i == activeStep
                        ? AppColors.primaryDark
                        : NurseUi.muted,
                    fontSize: 10,
                    fontWeight: i == activeStep
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1)
            Container(
              width: 20,
              height: 1,
              margin: const EdgeInsets.only(bottom: 22),
              color: i < activeStep ? AppColors.primary : NurseUi.border,
            ),
        ],
      ],
    );
  }

  int get _activeStep {
    if (currentPage == 0) return 0;
    if (currentPage == 1 || currentPage == 2) return 1;
    if (currentPage == 3) return 2;
    return 3;
  }

  Widget _patientInfoPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Patient Information'),
        _card(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: NurseUi.softSurface,
                    child: Text(
                      _patientName.characters.first.toUpperCase(),
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
                        Text(
                          _patientName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${widget.request.patientAge > 0 ? '${widget.request.patientAge} years' : 'Age not set'}, $_genderText',
                          style: TextStyle(
                            color: NurseUi.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.request.location,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _reviewLine('Request ID', widget.request.id),
              _reviewLine('Service Type', _serviceType),
              _reviewLine(
                'Visit Date',
                _formatDate(widget.request.scheduledDate),
              ),
              _reviewLine(
                'Scheduled Time',
                _formatTime(widget.request.scheduledDate),
              ),
              _reviewLine('Actual Start Time', _formatTime(widget.startTime)),
              _reviewLine('Known Condition', _knownCondition),
              _reviewLine('Allergies', _allergiesText, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openMedicalRecords,
          icon: const Icon(Icons.description_outlined),
          label: const Text('View Full Medical Record'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  void _openMedicalRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NursePatientMedicalRecordsScreen(
          request: widget.request,
          providerUserId: widget.user.userId,
        ),
      ),
    );
  }

  Widget _conditionAndVitalsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Patient Condition'),
        const Text(
          'General Condition',
          style: TextStyle(
            color: Color(0xFF78909C),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _conditionCard(),
        const SizedBox(height: 16),
        _sectionTitle('Symptoms'),
        TextField(
          controller: symptomsController,
          minLines: 3,
          maxLines: 4,
          maxLength: 200,
          decoration: _inputDecoration('Patient symptoms...'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pain Level (1-10)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              painLevel.round().toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          value: painLevel,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: AppColors.primary,
          onChanged: (value) => setState(() => painLevel = value),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Vital Signs'),
        _vitalsCard(),
      ],
    );
  }

  Widget _careAndMedicationPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Care Provided'),
        _careCard(),
        if (careProvided['Other care'] == true) ...[
          const SizedBox(height: 10),
          TextField(
            controller: otherCareController,
            decoration: _inputDecoration('Please specify'),
          ),
        ],
        const SizedBox(height: 16),
        _sectionTitle('Medications Given'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (medications.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NurseUi.softSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NurseUi.border),
                  ),
                  child: Text(
                    'No medications added yet',
                    style: TextStyle(
                      color: NurseUi.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              for (var i = 0; i < medications.length; i++) ...[
                _medicationTile(medications[i], i),
                const SizedBox(height: 10),
              ],
              TextButton.icon(
                onPressed: _showMedicationForm,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Medication'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Notes & Summary'),
        TextField(
          controller: reportNotesController,
          minLines: 5,
          maxLines: 7,
          maxLength: 500,
          decoration: _inputDecoration('Visit notes and summary'),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Follow-up Plan'),
        _card(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: followUpNeeded,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Follow-up Needed',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onChanged: (value) => setState(() => followUpNeeded = value),
              ),
              if (followUpNeeded) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primaryDark,
                  ),
                  title: Text(NurseUi.t('Follow-up Date')),
                  subtitle: Text(_formatDate(followUpDate ?? DateTime.now())),
                  onTap: _pickFollowUpDate,
                ),
                TextField(
                  controller: followUpInstructionsController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: _inputDecoration('Follow-up instructions'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Attachments'),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: attachments.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == attachments.length) {
                return _attachmentAddTile();
              }
              return _attachmentImageTile(attachments[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _reviewPage() {
    final care = _selectedCare.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Patient Information'),
        _reviewCard([
          _ReviewItem('Patient', _patientName),
          _ReviewItem(
            'Age / Gender',
            '${widget.request.patientAge} years, $_genderText',
          ),
          _ReviewItem('Location', widget.request.location),
          _ReviewItem('Request ID', widget.request.id),
        ]),
        _sectionTitle('Visit Details'),
        _reviewCard([
          _ReviewItem(
            'Date & Time',
            '${_formatDate(widget.request.scheduledDate)} - ${_formatTime(widget.request.scheduledDate)}',
          ),
          _ReviewItem('Visit Type', _serviceType),
          _ReviewItem(
            'Duration',
            '${widget.elapsed.inMinutes <= 0 ? 1 : widget.elapsed.inMinutes} minutes',
          ),
          _ReviewItem('Actual Start', _formatTime(widget.startTime)),
        ]),
        _sectionTitle('Patient Condition'),
        _reviewCard([
          _ReviewItem('Condition', stable ? 'Stable' : 'Critical'),
          _ReviewItem('Symptoms', symptomsController.text.trim()),
          _ReviewItem('Pain Level', '${painLevel.round()}/10'),
        ]),
        _sectionTitle('Vital Signs'),
        _reviewCard([
          _ReviewItem('Blood Pressure', bloodPressureController.text.trim()),
          _ReviewItem('Heart Rate', heartRateController.text.trim()),
          _ReviewItem('Temperature', temperatureController.text.trim()),
          _ReviewItem('Oxygen Saturation', oxygenController.text.trim()),
        ]),
        _sectionTitle('Care Provided'),
        _reviewCard([_ReviewItem('Selected Care', care)]),
        _sectionTitle('Medication'),
        _reviewCard(
          medications.isEmpty
              ? const [_ReviewItem('Medications Given', 'None')]
              : [
                  for (var i = 0; i < medications.length; i++)
                    _ReviewItem('Medication ${i + 1}', medications[i].summary),
                ],
        ),
        _sectionTitle('Attachments'),
        _reviewCard([
          _ReviewItem(
            'Images',
            attachments.isEmpty
                ? 'No attachments'
                : '${attachments.length} attachment(s)',
          ),
        ]),
        _sectionTitle('Notes & Follow-up'),
        _reviewCard([
          _ReviewItem('Summary', reportNotesController.text.trim()),
          _ReviewItem('Follow-up', followUpNeeded ? 'Needed' : 'Not needed'),
          if (followUpNeeded)
            _ReviewItem(
              'Follow-up Date',
              _formatDate(followUpDate ?? DateTime.now()),
            ),
          if (followUpNeeded)
            _ReviewItem(
              'Instructions',
              followUpInstructionsController.text.trim(),
            ),
        ]),
      ],
    );
  }

  Widget _conditionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(child: _conditionOption('Stable', true)),
          const SizedBox(width: 10),
          Expanded(child: _conditionOption('Critical', false)),
        ],
      ),
    );
  }

  Widget _conditionOption(String label, bool value) {
    final selected = stable == value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => stable = value),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : NurseUi.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primaryDark : const Color(0xFFB0BEC5),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _careCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: careProvided.keys.map((label) {
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            value: careProvided[label],
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onChanged: (value) {
              setState(() => careProvided[label] = value == true);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _medicationTile(_MedicationEntry medication, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NurseUi.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${medication.dosage} - ${medication.route}',
                  style: TextStyle(
                    color: NurseUi.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (medication.notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    medication.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: NurseUi.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove medication',
            icon: const Icon(Icons.delete_outline_rounded),
            color: const Color(0xFFEF4444),
            onPressed: () => setState(() => medications.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _showMedicationForm() async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    var selectedDosage = '1 Tablet';
    var selectedRoute = 'Oral';

    final entry = await showModalBottomSheet<_MedicationEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4FAF9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Medication',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sheetTextField(
                      controller: nameController,
                      label: 'Medication Name',
                      hint: 'Ibuprofen, Paracetamol',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _sheetDropdown(
                            label: 'Dosage',
                            value: selectedDosage,
                            items: const [
                              '1 Tablet',
                              '2 Tablets',
                              '5 ml',
                              'Injection',
                            ],
                            onChanged: (value) =>
                                setSheetState(() => selectedDosage = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sheetDropdown(
                            label: 'Route',
                            value: selectedRoute,
                            items: const ['Oral', 'IV', 'IM'],
                            onChanged: (value) =>
                                setSheetState(() => selectedRoute = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sheetTextField(
                      controller: notesController,
                      label: 'Notes',
                      hint: 'Given for pain and inflammation',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(
                            sheetContext,
                            _MedicationEntry(
                              name: name,
                              dosage: selectedDosage,
                              route: selectedRoute,
                              notes: notesController.text.trim(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Medication'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    notesController.dispose();
    if (entry == null || !mounted) return;
    setState(() => medications.add(entry));
  }

  Widget _sheetTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NurseUi.border),
        ),
      ),
    );
  }

  Widget _sheetDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NurseUi.border),
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _vitalsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _input('Blood Pressure', bloodPressureController, '120/80 mmHg'),
          const SizedBox(height: 10),
          _input('Heart Rate', heartRateController, '82 bpm'),
          const SizedBox(height: 10),
          _input('Temperature', temperatureController, '37.2 C'),
          const SizedBox(height: 10),
          _input('Oxygen Saturation', oxygenController, '98 %'),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NurseUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NurseUi.border),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: NurseUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: NurseUi.border),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: child,
    );
  }

  Widget _attachmentAddTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _pickAttachment,
      child: Container(
        width: 84,
        height: 82,
        decoration: BoxDecoration(
          color: NurseUi.softSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NurseUi.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.primaryDark),
            SizedBox(height: 4),
            Text(
              'Add More',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentImageTile(XFile file, int index) {
    return Stack(
      children: [
        Container(
          width: 84,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NurseUi.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_outlined, color: AppColors.primaryDark),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: () => setState(() => attachments.removeAt(index)),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(NurseUi.t('Choose from gallery')),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(NurseUi.t('Take a photo')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    if (source == ImageSource.gallery) {
      final images = await imagePicker.pickMultiImage();
      if (images.isEmpty || !mounted) return;
      setState(() => attachments.addAll(images));
      return;
    }

    final image = await imagePicker.pickImage(source: ImageSource.camera);
    if (image == null || !mounted) return;
    setState(() => attachments.add(image));
  }

  Widget _reviewCard(List<_ReviewItem> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _card(
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              _reviewLine(
                items[i].label,
                items[i].value,
                isLast: i == items.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewLine(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: NurseUi.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not set' : value,
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

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: followUpDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => followUpDate = picked);
  }

  void _next() {
    if (!_validateCurrentPage()) return;
    final nextPage = (currentPage + 1).clamp(0, 4);
    setState(() => currentPage = nextPage);
    pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    final previous = (currentPage - 1).clamp(0, 4);
    setState(() => currentPage = previous);
    pageController.animateToPage(
      previous,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  bool _validateCurrentPage() {
    if (currentPage == 1) {
      final missingVitals =
          bloodPressureController.text.trim().isEmpty ||
          heartRateController.text.trim().isEmpty ||
          temperatureController.text.trim().isEmpty ||
          oxygenController.text.trim().isEmpty;
      if (missingVitals) {
        _snack('Please enter all vital signs before continuing.');
        return false;
      }
    }
    if (currentPage == 3 && reportNotesController.text.trim().isEmpty) {
      _snack('Please add notes and summary before review.');
      return false;
    }
    return true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _patientName => widget.request.patientName.isEmpty
      ? 'Patient'
      : widget.request.patientName;

  String get _genderText => 'Gender not set';

  String get _serviceType => widget.request.serviceType.isEmpty
      ? 'Home nursing'
      : widget.request.serviceType;

  String get _knownCondition {
    if (widget.request.medicalCondition.trim().isNotEmpty) {
      return widget.request.medicalCondition;
    }
    if (widget.request.reasonForVisit.trim().isNotEmpty) {
      return widget.request.reasonForVisit;
    }
    return 'Not set';
  }

  String get _allergiesText {
    final raw = widget.request.notes ?? '';
    final match = RegExp(
      r'Allergies:\s*([^|]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1)?.trim() ?? 'Not set';
  }

  List<String> get _selectedCare {
    final values = careProvided.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if (careProvided['Other care'] == true &&
        otherCareController.text.trim().isNotEmpty) {
      values.add(otherCareController.text.trim());
    }
    return values;
  }

  String _medicationReviewText() {
    if (medications.isEmpty) return 'None';
    return medications
        .map((medication) => medication.summary)
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _submitReport() async {
    if (!_validateCurrentPage()) return;
    setState(() => isSaving = true);
    final vitals =
        'BP: ${bloodPressureController.text.trim()}, HR: ${heartRateController.text.trim()}, Temp: ${temperatureController.text.trim()}, O2: ${oxygenController.text.trim()}';
    final care = _selectedCare.join(', ');
    final medication = jsonEncode(
      medications.map((medication) => medication.toJson()).toList(),
    );
    final summary = reportNotesController.text.trim();
    final attachmentRefs = attachments.map((file) => file.path).toList();
    try {
      final savedReport = await ReportService.createReportRecord(
        providerId: widget.user.userId,
        requestId: widget.request.id,
        patientId: widget.request.patientId,
        patientName: widget.request.patientName,
        serviceType: widget.request.serviceType,
        location: widget.request.location,
        scheduledDate: widget.request.scheduledDate,
        durationHours: widget.elapsed.inMinutes <= 60
            ? 1
            : (widget.elapsed.inMinutes / 60).ceil(),
        visitSummary: summary,
        vitalSigns: vitals,
        medications: medication,
        observations:
            '${widget.visitNotes}\nSymptoms: ${symptomsController.text.trim()}\nPain level: ${painLevel.round()}/10\nCare provided: $care\nCondition: ${stable ? 'Stable' : 'Critical'}',
        recommendations: followUpNeeded
            ? followUpInstructionsController.text.trim()
            : '',
        attachments: attachmentRefs,
      );
      if (savedReport == null) throw Exception('Failed to submit report');
      try {
        await nurseRepository.updateRequestStatus(
          requestId: widget.request.id,
          status: 'completed',
          nurseUserId: widget.user.userId,
        );
      } catch (e) {
        final message = e.toString().toLowerCase();
        final alreadyClosed =
            message.contains('already closed') ||
            message.contains('already completed') ||
            message.contains('request_already_closed') ||
            message.contains('visit_already_completed');
        if (!alreadyClosed) rethrow;
      }
      await widget.onChanged();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReportSubmittedScreen(
            request: ServiceRequest.fromJson({
              ...widget.request.toJson(),
              'status': 'completed',
            }),
            user: widget.user,
            submittedBy: widget.user.fullName.isEmpty
                ? 'Nurse'
                : widget.user.fullName,
            reportSummary:
                'Condition: ${stable ? 'Stable' : 'Critical'}\n$vitals\nCare provided: $care\nMedications: ${_medicationReviewText()}\nAttachments: ${attachmentRefs.length}\nSummary: $summary',
            report: savedReport,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  BoxDecoration _cardDecoration() {
    return NurseUi.cardDecoration();
  }
}

class _ReviewItem {
  final String label;
  final String value;

  const _ReviewItem(this.label, this.value);
}

class _MedicationEntry {
  const _MedicationEntry({
    required this.name,
    required this.dosage,
    required this.route,
    required this.notes,
  });

  final String name;
  final String dosage;
  final String route;
  final String notes;

  Map<String, String> toJson() {
    return {'name': name, 'dosage': dosage, 'route': route, 'notes': notes};
  }

  String get summary {
    final parts = [
      name,
      dosage,
      route,
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    if (notes.trim().isEmpty) return parts;
    return '$parts\n$notes';
  }
}

class ReportSubmittedScreen extends StatelessWidget {
  const ReportSubmittedScreen({
    super.key,
    required this.request,
    required this.user,
    required this.submittedBy,
    required this.reportSummary,
    this.report,
  });

  final ServiceRequest request;
  final User user;
  final String submittedBy;
  final String reportSummary;
  final VisitReport? report;

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Report Submitted')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => NurseDashboard(user: user)),
                (route) => false,
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: AppColors.primaryDark,
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
          child: Column(
            children: [
              _successMark(),
              const SizedBox(height: 22),
              const Text(
                'Report Submitted\nSuccessfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your visit report has been submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF607D8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 26),
              _summaryCard(),
              const SizedBox(height: 26),
              _primaryButton(
                icon: Icons.description_outlined,
                label: 'View Report',
                onPressed: () {
                  final submittedReport = report;
                  if (submittedReport != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReportDetailsScreen(report: submittedReport),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitReportDetailsScreen(
                        request: request,
                        user: user,
                        submittedBy: submittedBy,
                        reportSummary: reportSummary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _outlineButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back to Home',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NurseDashboard(user: user),
                    ),
                    (route) => false,
                  );
                },
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: NurseUi.softSurface,
            child: Text(
              _patientName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primaryDark,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.serviceType.isEmpty
                      ? 'Home nursing'
                      : request.serviceType,
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _compactLine(
                  Icons.calendar_today_outlined,
                  '${_formatDate(request.scheduledDate)} Â· ${_formatTime(request.scheduledDate)}',
                ),
                const SizedBox(height: 7),
                _compactLine(Icons.receipt_long_outlined, '#${request.id}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successMark() {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 6, right: 22, child: _dot(5)),
          Positioned(bottom: 20, left: 18, child: _dot(6)),
          Positioned(top: 36, left: 4, child: _dot(4)),
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _compactLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
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
      height: 50,
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
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class VisitReportDetailsScreen extends StatelessWidget {
  const VisitReportDetailsScreen({
    super.key,
    required this.request,
    required this.user,
    required this.submittedBy,
    required this.reportSummary,
  });

  final ServiceRequest request;
  final User user;
  final String submittedBy;
  final String reportSummary;

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Visit Report')),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Patient Information'),
              _card([
                _line('Patient', request.patientName),
                _line('Request ID', request.id),
                _line('Location', request.location),
              ]),
              _title('Nurse Information'),
              _card([
                _line('Submitted By', submittedBy),
                _line('Nurse ID', user.userId),
              ]),
              _title('Visit Details'),
              _card([
                _line('Visit Date', _formatDate(request.scheduledDate)),
                _line('Scheduled Time', _formatTime(request.scheduledDate)),
                _line('Service Type', request.serviceType),
                _line('Report Status', 'Submitted'),
              ]),
              _title('Medical Report'),
              _card([
                _line('Summary', reportSummary),
                _line('Submitted Date', _formatDate(DateTime.now())),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(children: children),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not set' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

