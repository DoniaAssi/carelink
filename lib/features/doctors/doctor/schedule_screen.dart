import 'package:carelink/features/notifications/notifications_screen.dart';
import 'package:carelink/shared/services/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/locale_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';
import 'request_details_screen.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  bool _isAvailable = true;
  int _selectedTab = 0;
  List<dynamic> _slots = [];
  List<dynamic> _appointments = [];
  String _doctorId = '';
  DateTime _selectedDate = DateTime.now();
  String _appointmentFilter = 'all';

  static const _pageColor = DoctorUiConstants.doctorBackground;
  static const _primary = Color(0xFF0F8B8D);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    notificationCenter.addListener(_onNotificationsChanged);
    _loadData();
  }

  @override
  void dispose() {
    notificationCenter.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';

      final results = await Future.wait([
        _doctorService.getAvailabilityStatus(_doctorId),
        _doctorService.getSchedule(_doctorId),
        _doctorService.getRequests(_doctorId),
        notificationCenter.load(_doctorId, force: true).then((_) => null),
      ]);

      if (!mounted) return;
      final availability = results[0] as Map<String, dynamic>;
      setState(() {
        _isAvailable = availability['isAvailable'] ?? true;
        _slots = results[1] as List<dynamic>;
        _appointments = results[2] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final newStatus = !_isAvailable;
      await _doctorService.setAvailability(_doctorId, newStatus);
      setState(() {
        _isAvailable = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are now ${newStatus ? 'available' : 'unavailable'}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSlot({
    String? day,
    Map<String, dynamic>? existingSlot,
  }) async {
    String? selectedDay = existingSlot?['day']?.toString() ?? day;
    TimeOfDay? startTime = _parseSlotTime(existingSlot?['startTime']);
    TimeOfDay? endTime = _parseSlotTime(existingSlot?['endTime']);
    final editing = existingSlot != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            editing ? 'Edit Availability Slot' : 'Add Availability Slot',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Day'),
                initialValue: selectedDay,
                items: _days
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedDay = value);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setDialogState(() => startTime = time);
                    }
                  },
                  child: Text(
                    startTime != null ? startTime!.format(context) : 'Select',
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          endTime ?? const TimeOfDay(hour: 17, minute: 0),
                    );
                    if (time != null) {
                      setDialogState(() => endTime = time);
                    }
                  },
                  child: Text(
                    endTime != null ? endTime!.format(context) : 'Select',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDay == null ||
                    startTime == null ||
                    endTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                final startMinutes = startTime!.hour * 60 + startTime!.minute;
                final endMinutes = endTime!.hour * 60 + endTime!.minute;
                if (endMinutes <= startMinutes) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'day': selectedDay,
                  'startTime': startTime,
                  'endTime': endTime,
                });
              },
              child: Text(editing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    ).then((result) async {
      if (result != null) {
        try {
          if (!mounted) return;
          final startTimeStr = result['startTime'].format(context);
          final endTimeStr = result['endTime'].format(context);
          final timeRange = '$startTimeStr - $endTimeStr';
          debugPrint('Selected time: $timeRange');

          if (editing) {
            await _doctorService.updateScheduleSlot(
              _doctorId,
              (existingSlot['slot_id'] ?? '').toString(),
              day: result['day'],
              startTime: _formatTimeForApi(result['startTime']),
              endTime: _formatTimeForApi(result['endTime']),
            );
          } else {
            await _doctorService.addScheduleSlot(
              _doctorId,
              day: result['day'],
              startTime: _formatTimeForApi(result['startTime']),
              endTime: _formatTimeForApi(result['endTime']),
            );
          }

          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  editing
                      ? 'Slot updated successfully'
                      : 'Slot added successfully',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    });
  }

  Future<void> _deleteSlot(String slotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text(
          'Are you sure you want to delete this availability slot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _doctorService.deleteScheduleSlot(_doctorId, slotId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Slot deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _disableDaySlots(
    String day,
    List<Map<String, dynamic>> slots,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disable $day'),
        content: const Text(
          'All availability periods for this day will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      for (final slot in slots) {
        final slotId = (slot['slot_id'] ?? '').toString();
        if (slotId.isNotEmpty) {
          await _doctorService.deleteScheduleSlot(_doctorId, slotId);
        }
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$day availability disabled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  TimeOfDay? _parseSlotTime(dynamic value) {
    final parts = value?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _pageColor,
          appBar: AppBar(
            backgroundColor: _pageColor,
            surfaceTintColor: _pageColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: _primary,
            ),
            title: const Text(
              'Schedule',
              style: TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Language',
                onPressed: () => localeController.toggleDoctor(),
                icon: const Icon(Icons.language_rounded),
                color: _primary,
              ),
              _notificationButton(),
              const SizedBox(width: 10),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                        children: [
                          _buildTabs(),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _selectedTab == 0
                                ? _buildScheduleTab()
                                : _buildAvailabilityTab(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _notificationButton() {
    final count = notificationCenter.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: _doctorId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                        userId: _doctorId,
                        userRole: 'doctor',
                      ),
                    ),
                  );
                },
          icon: Icon(
            count > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_rounded,
          ),
          color: _primary,
        ),
        if (count > 0)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _pageColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.05)],
      ),
      child: Row(
        children: [
          _tabButton(
            index: 0,
            icon: Icons.calendar_month_outlined,
            label: 'Schedule',
          ),
          _tabButton(
            index: 1,
            icon: Icons.access_time_rounded,
            label: 'Availability',
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Material(
        color: selected ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: selected ? 8 : 0,
        shadowColor: _primary.withValues(alpha: 0.22),
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? Colors.white : _muted, size: 22),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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

  Widget _buildScheduleTab() {
    final appointments = _filteredAppointments();

    return Column(
      key: const ValueKey('schedule-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklyCalendar(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _selectedDateHeading,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildFilterDropdown(),
          ],
        ),
        const SizedBox(height: 18),
        if (appointments.isEmpty)
          _emptyAppointments()
        else
          ...appointments.map(_appointmentCard),
      ],
    );
  }

  Widget _buildWeeklyCalendar() {
    final weekStart = _weekStart(_selectedDate);
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _dayCard(days[index]),
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemCount: days.length,
      ),
    );
  }

  Widget _dayCard(DateTime day) {
    final selected = _isSameDay(day, _selectedDate);
    final name = _days[day.weekday - 1].substring(0, 3);

    return SizedBox(
      width: 82,
      height: double.infinity,
      child: Material(
        color: selected ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: selected ? 8 : 0,
        shadowColor: _primary.withValues(alpha: 0.18),
        child: InkWell(
          onTap: () => setState(() => _selectedDate = day),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _primary : const Color(0xFFE4E7EC),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected ? Colors.white : _muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          maxLines: 1,
                          style: TextStyle(
                            color: selected ? Colors.white : _ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _appointmentFilter,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Appointments')),
            DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
            DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
            DropdownMenuItem(value: 'completed', child: Text('Completed')),
            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _appointmentFilter = value);
          },
        ),
      ),
    );
  }

  Widget _appointmentCard(dynamic rawAppointment) {
    final appointment = rawAppointment is Map
        ? Map<String, dynamic>.from(rawAppointment)
        : <String, dynamic>{};
    final patientName = _cleanText(appointment['patientName']) ?? 'Patient';
    final serviceType =
        _cleanText(appointment['serviceType']) ?? 'Consultation';
    final location =
        _cleanText(appointment['visitAddress']) ??
        _cleanText(appointment['location']) ??
        'Location not set';
    final status = _cleanText(appointment['status']) ?? 'pending';
    final scheduledAt = _appointmentDate(appointment);
    final requestId = _cleanText(appointment['requestId']);
    final statusStyle = _appointmentStatusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.045)],
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: requestId == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestDetailsScreen(requestId: requestId),
                    ),
                  ).then((_) => _loadData());
                },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    scheduledAt == null ? '--:--' : _timeLabel(scheduledAt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _avatar(patientName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        serviceType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: _primary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _statusBadge(statusStyle),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(_StatusStyle style) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        style.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: style.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyAppointments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.04)],
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: _primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No appointments',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appointments for ${_selectedDateHeading.toLowerCase()} will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTab() {
    return Column(
      key: const ValueKey('availability-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Availability Status',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _availabilityStatusCard(),
        const SizedBox(height: 24),
        const Text(
          'Availability Slots',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage the time slots when you are available to accept appointments.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        ..._days.map(_availabilityDayCard),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addSlot,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: Text(context.dtr('doctor.schedule.add')),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _availabilityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isAvailable ? const Color(0xFFE8F7EE) : const Color(0xFFFFEDEC),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [_softShadow(opacity: 0.035)],
      ),
      child: Row(
        children: [
          Icon(
            _isAvailable ? Icons.check_circle : Icons.cancel,
            color: _isAvailable ? AppColors.success : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable
                      ? context.dtr('doctor.schedule.available')
                      : context.dtr('doctor.schedule.unavailable'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: _isAvailable ? AppColors.success : Colors.red,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isAvailable
                      ? context.dtr('doctor.schedule.accepting')
                      : context.dtr('doctor.schedule.notAccepting'),
                  style: TextStyle(
                    color: _isAvailable ? AppColors.success : Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (_) => _toggleAvailability(),
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _availabilityDayCard(String day) {
    final daySlots = _slots
        .where((slot) {
          if (slot is! Map) return false;
          return (slot['day'] ?? '').toString().toLowerCase() ==
              day.toLowerCase();
        })
        .map((slot) => Map<String, dynamic>.from(slot as Map))
        .toList();
    final hasSlots = daySlots.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [_softShadow(opacity: 0.04)],
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.access_time_rounded, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                if (hasSlots)
                  ...daySlots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _slotTime(slot),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Not available',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add period for $day',
            onPressed: () => _addSlot(day: day),
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: _primary,
          ),
          Switch(
            value: hasSlots,
            onChanged: (_) =>
                hasSlots ? _disableDaySlots(day, daySlots) : _addSlot(day: day),
            activeThumbColor: _primary,
          ),
          if (hasSlots)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: _muted),
              onSelected: (action) {
                if (action == 'add') {
                  _addSlot(day: day);
                  return;
                }
                final separator = action.indexOf(':');
                if (separator < 0) return;
                final type = action.substring(0, separator);
                final slotId = action.substring(separator + 1);
                final slot = daySlots.cast<Map<String, dynamic>?>().firstWhere(
                  (item) => (item?['slot_id'] ?? '').toString() == slotId,
                  orElse: () => null,
                );
                if (slot == null) return;
                if (type == 'edit') {
                  _addSlot(day: day, existingSlot: slot);
                } else if (type == 'delete') {
                  _deleteSlot(slotId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(Icons.add_rounded),
                    title: Text('Add another period'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                for (final slot in daySlots)
                  PopupMenuItem(
                    value: 'edit:${(slot['slot_id'] ?? '').toString()}',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text('Edit ${_slotTime(slot)}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                for (final slot in daySlots)
                  PopupMenuItem(
                    value: 'delete:${(slot['slot_id'] ?? '').toString()}',
                    child: ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      title: Text('Delete ${_slotTime(slot)}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  List<dynamic> _filteredAppointments() {
    final rows =
        _appointments.where((raw) {
          if (raw is! Map) return false;
          final date = _appointmentDate(Map<String, dynamic>.from(raw));
          if (date == null || !_isSameDay(date, _selectedDate)) return false;
          if (_appointmentFilter == 'all') return true;
          return _statusGroup((raw['status'] ?? '').toString()) ==
              _appointmentFilter;
        }).toList()..sort((a, b) {
          final aDate = _appointmentDate(Map<String, dynamic>.from(a as Map));
          final bDate = _appointmentDate(Map<String, dynamic>.from(b as Map));
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

    return rows;
  }

  DateTime? _appointmentDate(Map<String, dynamic> item) {
    final raw =
        _cleanText(item['scheduledAt']) ?? _cleanText(item['requestedDate']);
    if (raw == null) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  String _statusGroup(String rawStatus) {
    final status = rawStatus.toLowerCase().trim();
    if (status == 'completed') return 'completed';
    if (status == 'cancelled' || status == 'canceled' || status == 'rejected') {
      return 'cancelled';
    }
    if (status == 'in_progress' || status == 'waiting_report') {
      return 'in_progress';
    }
    return 'upcoming';
  }

  _StatusStyle _appointmentStatusStyle(String rawStatus) {
    switch (_statusGroup(rawStatus)) {
      case 'completed':
        return const _StatusStyle(
          label: 'Completed',
          color: Color(0xFF079455),
          background: Color(0xFFE8F7EE),
        );
      case 'cancelled':
        return const _StatusStyle(
          label: 'Cancelled',
          color: Color(0xFFB42318),
          background: Color(0xFFFFEDEC),
        );
      case 'in_progress':
        return const _StatusStyle(
          label: 'In Progress',
          color: Color(0xFFB54708),
          background: Color(0xFFFFF3E6),
        );
      default:
        return const _StatusStyle(
          label: 'Upcoming',
          color: Color(0xFF1570EF),
          background: Color(0xFFEAF4FF),
        );
    }
  }

  DateTime _weekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get _selectedDateHeading {
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
    final dayName = _days[_selectedDate.weekday - 1];
    return '$dayName, ${months[_selectedDate.month - 1]} ${_selectedDate.day}';
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute\n$suffix';
  }

  Widget _avatar(String name) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _primary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _slotTime(Map<String, dynamic> slot) {
    return '${_shortTime(slot['startTime'])} - ${_shortTime(slot['endTime'])}';
  }

  String _shortTime(dynamic value) {
    final text = value?.toString() ?? '';
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return text;
  }

  BoxShadow _softShadow({double opacity = 0.05}) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 24,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}
