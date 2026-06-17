import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/features/nurse/screens/nurse_contact_patient_flow.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/features/nurse/services/nurse_repository.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'package:carelink/shared/services/report_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('My Schedule'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: const Color(0xFF0F766E),
            onPressed: () {},
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
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
      height: 38,
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0F766E) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFE5E7EB),
                  width: selected ? 1.5 : 1,
                ),
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
      height: 70,
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
              width: 54,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0F766E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0xFF0F766E).withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.045),
                    blurRadius: selected ? 16 : 12,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF607D8B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF151823),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 680,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: const [
                      _ScheduleHeaderCell('Patient Name', flex: 3),
                      _ScheduleHeaderCell('Time', flex: 2),
                      _ScheduleHeaderCell('Service Type', flex: 3),
                      _ScheduleHeaderCell('Status', flex: 2),
                    ],
                  ),
                ),
                for (var i = 0; i < appointments.length; i++) ...[
                  _scheduleTableRow(appointments[i]),
                  if (i != appointments.length - 1)
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleTableRow(ServiceRequest request) {
    return InkWell(
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
      child: Container(
        height: 76,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE0F2F1),
                    child: Text(
                      _initial(request.patientName),
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _shortPatientName(request.patientName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF0F766E),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _timeOneLine(request.scheduledDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                request.serviceType.isEmpty
                    ? 'Home Nursing Care'
                    : request.serviceType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _chip(_statusLabel(request.status), request.status),
              ),
            ),
          ],
        ),
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
        builder: (_) =>
            NurseSetAvailabilityScreen(user: widget.user, initialSlots: slots),
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

  String _timeOneLine(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
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

class _ScheduleHeaderCell extends StatelessWidget {
  const _ScheduleHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class NurseSetAvailabilityScreen extends StatefulWidget {
  const NurseSetAvailabilityScreen({
    super.key,
    required this.user,
    required this.initialSlots,
  });

  final User user;
  final List<Map<String, dynamic>> initialSlots;

  @override
  State<NurseSetAvailabilityScreen> createState() =>
      _NurseSetAvailabilityScreenState();
}

class _NurseSetAvailabilityScreenState
    extends State<NurseSetAvailabilityScreen> {
  bool available = true;
  final workingDays = <String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  };
  late List<Map<String, dynamic>> slots;

  @override
  void initState() {
    super.initState();
    slots = widget.initialSlots
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Set Availability'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            _card(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: available,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Availability Status',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('You are Available'),
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
                    onPressed: _openAddTimeSlot,
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
                onPressed: _save,
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
      MaterialPageRoute(builder: (_) => const NurseAddTimeSlotScreen()),
    );
    if (slot == null) return;
    setState(() => slots.add(slot));
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
    await _saveLocalSlots(slots);
    final success = await ProviderProfileService.saveAvailability(
      providerId,
      slots,
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
    if (success) Navigator.pop(context, slots);
  }

  Future<void> _saveLocalSlots(List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'nurse_availability_slots_${widget.user.userId}';
    await prefs.setString(key, jsonEncode(value));
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
}

class NurseAddTimeSlotScreen extends StatefulWidget {
  const NurseAddTimeSlotScreen({super.key});

  @override
  State<NurseAddTimeSlotScreen> createState() => _NurseAddTimeSlotScreenState();
}

class _NurseAddTimeSlotScreenState extends State<NurseAddTimeSlotScreen> {
  String day = 'Wednesday';
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 13, minute: 0);
  String serviceType = 'Home visit';
  String location = 'Birzeit, Ramallah';
  final notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: const Text('Add Time Slot'),
          centerTitle: true,
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            _label('Select Day'),
            _dropdown(day, const [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ], (v) => setState(() => day = v!)),
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
            _label('Service Type'),
            _dropdown(serviceType, const [
              'Home visit',
              'Elderly care',
              'Post-surgery care',
              'Medication assistance',
            ], (v) => setState(() => serviceType = v!)),
            const SizedBox(height: 16),
            _label('Location'),
            _dropdown(location, const [
              'Birzeit, Ramallah',
              'Al-bireh, Ramallah',
              'Beitunia, Ramallah',
            ], (v) => setState(() => location = v!)),
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
                    'startTime': _format24(start),
                    'endTime': _format24(end),
                    'serviceType': serviceType,
                    'location': location,
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
          title: const Text('My Availability'),
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
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Future<void> _saveSlots() async {
    await ProviderProfileService.saveAvailability(widget.user.userId, slots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'nurse_availability_slots_${widget.user.userId}',
      jsonEncode(slots),
    );
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
          title: const Text('Time Slot Details'),
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
          title: const Text('Visit Dashboard'),
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
            onTap: isSaving ? null : _confirmStartVisit,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primaryDark,
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
    if (status == 'assigned' || status == 'scheduled' || status == 'pending') {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : _confirmStartVisit,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(isSaving ? 'Starting...' : 'Start Visit'),
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
              onPressed: () => Navigator.pop(context),
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
    return null;
  }

  Future<void> _confirmStartVisit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start visit'),
        content: const Text('Are you sure you want to start this visit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start Visit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final startTime = DateTime.now();
    setState(() => isSaving = true);
    try {
      final success = await ServiceRequestService.startVisit(
        request.id,
        providerUserId: widget.user.userId,
      );
      if (!success) return;
      await widget.onChanged();
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
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
          title: const Text('Visit In Progress'),
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
                onPressed: _completeVisit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
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

  void _completeVisit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReportScreen(
          request: widget.request,
          user: widget.user,
          startTime: widget.startTime,
          visitNotes: notesController.text.trim(),
          checklist: checklist,
          elapsed: elapsed,
          onChanged: widget.onChanged,
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
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
  final medicationNameController = TextEditingController();
  final medicationNotesController = TextEditingController();
  final followUpInstructionsController = TextEditingController();
  final otherCareController = TextEditingController();
  var dosage = '1 Tablet';
  var route = 'Oral';
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
  final attachments = <IconData>[
    Icons.image_outlined,
    Icons.image_outlined,
    Icons.image_outlined,
  ];

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
    medicationNameController.dispose();
    medicationNotesController.dispose();
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
          title: const Text('Create Report'),
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
          onPressed: () {},
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
            children: [
              _input(
                'Medication Name',
                medicationNameController,
                'Medication name',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      value: dosage,
                      items: const ['1 Tablet', '2 Tablets', '5 ml', '10 ml'],
                      onChanged: (value) => setState(() => dosage = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      value: route,
                      items: const [
                        'Oral',
                        'IV',
                        'IM',
                        'Subcutaneous',
                        'Topical',
                        'Inhalation',
                        'Other',
                      ],
                      onChanged: (value) => setState(() => route = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: medicationNotesController,
                minLines: 3,
                maxLines: 4,
                maxLength: 200,
                decoration: _inputDecoration('Medication notes'),
              ),
              TextButton.icon(
                onPressed: () {},
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
                  title: const Text('Follow-up Date'),
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
                return _attachmentTile(Icons.add_rounded, 'Add More');
              }
              return _attachmentTile(attachments[index], '');
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
        _reviewCard([
          _ReviewItem('Medication', medicationNameController.text.trim()),
          _ReviewItem('Dosage', dosage),
          _ReviewItem('Route', route),
          _ReviewItem('Notes', medicationNotesController.text.trim()),
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

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: _inputDecoration(''),
    );
  }

  Widget _attachmentTile(IconData icon, String label) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: label.isEmpty ? Colors.white : NurseUi.softSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NurseUi.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryDark),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
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
    final medication = [
      medicationNameController.text.trim(),
      dosage,
      route,
      medicationNotesController.text.trim(),
    ].where((value) => value.trim().isNotEmpty).join(' | ');
    final summary = reportNotesController.text.trim();
    try {
      final saved = await ReportService.createReport(
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
      );
      if (!saved) throw Exception('Failed to submit report');
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
                'Condition: ${stable ? 'Stable' : 'Critical'}\n$vitals\nCare provided: $care\nMedication: $medication\nSummary: $summary',
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
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _ReviewItem {
  final String label;
  final String value;

  const _ReviewItem(this.label, this.value);
}

class ReportSubmittedScreen extends StatelessWidget {
  const ReportSubmittedScreen({
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
          title: const Text('Report Submitted'),
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
                  '${_formatDate(request.scheduledDate)} · ${_formatTime(request.scheduledDate)}',
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
          title: const Text('Visit Report'),
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
