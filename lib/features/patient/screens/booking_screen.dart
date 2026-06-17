import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'select_visit_location_screen.dart';
import 'package:carelink/features/patient/widgets/booking_provider_summary.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class BookingScreen extends StatefulWidget {
  final BookingRequestModel request;

  const BookingScreen({super.key, required this.request});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _visibleStartDate = DateTime.now();
  String? _selectedTimeLabel;
  bool _isLoadingTimes = true;
  List<AvailabilitySlot> _providerSlots = const [];
  final Set<String> _blockedDateTimes = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _visibleStartDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    _selectedTimeLabel = widget.request.appointmentTime.trim().isEmpty
        ? null
        : widget.request.appointmentTime.trim();
    _loadAvailabilityData();
  }

  List<DateTime> get _dateOptions {
    final dates = <DateTime>[];
    final weekStart = _startOfWeek(_visibleStartDate);
    for (var offset = 0; offset < 7; offset++) {
      dates.add(
        DateTime(weekStart.year, weekStart.month, weekStart.day + offset),
      );
    }
    return dates;
  }

  String _monthYear(DateTime date) {
    final monthNames = context.l10n.isArabic
        ? const [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  String _shortDay(DateTime? d) {
    final names = context.l10n.isArabic
        ? const [
            'الاثنين',
            'الثلاثاء',
            'الأربعاء',
            'الخميس',
            'الجمعة',
            'السبت',
            'الأحد',
          ]
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = _safeWeekday(d);
    if (weekday == null || weekday < 1 || weekday > 7) return '--';
    return names[weekday - 1];
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _continue() {
    if (_selectedTimeLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('booking.dateTime.chooseFirst'))),
      );
      return;
    }

    final request = widget.request.copyWith(
      appointmentDate: _selectedDate.toIso8601String().split('T').first,
      appointmentTime: _to24h(_selectedTimeLabel!),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectVisitLocationScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedTimeLabel != null;
    final options = _timeOptionsForSelectedDate;

    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: context.l10n.isArabic
            ? 'اختر التاريخ والوقت'
            : context.tr('booking.dateTime.title'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: p.pageBg,
            border: Border(top: BorderSide(color: p.stroke)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: PatientPrimaryButton(
            height: 54,
            icon: Icons.arrow_forward_rounded,
            onPressed: canContinue ? _continue : null,
            label: context.tr('booking.continue'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BookingStepIndicator(currentStep: BookingFlowStep.dateTime),
            const SizedBox(height: 12),
            BookingProviderSummary(request: widget.request, compact: true),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: p.isDark
                    ? const Color(0xFF132A26)
                    : const Color(0xFFE8F7F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.isDark
                      ? const Color(0xFF1B3D37)
                      : const Color(0xFFCDEEEA),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.isArabic
                              ? 'اختر التاريخ'
                              : 'Choose a date',
                          style: TextStyle(
                            color: p.isDark
                                ? const Color(0xFF7FE2D1)
                                : const Color(0xFF0F7A69),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.isArabic
                              ? 'اختر يوماً من الأسبوع أو افتح التقويم لعرض المزيد من المواعيد.'
                              : 'Choose a day from the week or open the calendar to see more appointments.',
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 12.2,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  _monthYear(_selectedDate),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                PatientPressable(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openCalendarPicker,
                  child: Container(
                    width: 42,
                    height: 38,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.stroke),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dateOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final d = _dateOptions[index];
                  final selected = _isSameDay(d, _selectedDate);
                  final available = !_isDateDisabled(d);
                  return PatientPressable(
                    onTap: available ? () => _selectDate(d) : null,
                    enabled: available,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: context.l10n.isArabic ? 82 : 64,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : available
                            ? p.surface
                            : p.surfaceSoft.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : available
                              ? AppColors.primary.withValues(alpha: 0.28)
                              : p.stroke,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _shortDay(d),
                                maxLines: 1,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFFCDEEEA)
                                      : available
                                      ? p.inkMuted
                                      : p.inkMuted.withValues(alpha: 0.52),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : available
                                  ? p.inkDark
                                  : p.inkMuted.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('booking.dateTime.selectTime'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: options.map((time) {
                final selected = _selectedTimeLabel == time;
                return PatientPressable(
                  onTap: () => setState(() => _selectedTimeLabel = time),
                  enabled: true,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : p.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.primary : p.stroke,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: selected ? Colors.white : p.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            color: selected ? Colors.white : p.inkDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_isLoadingTimes)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: p.surfaceSoft,
                ),
              ),
            if (!_isLoadingTimes && options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  context.tr('booking.dateTime.noTimes'),
                  style: TextStyle(color: p.inkMuted),
                ),
              ),
            if (_selectedTimeLabel != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                            context.l10n.isArabic
                                ? 'الموعد المختار: ${_selectedDate.day} ${intl.DateFormat.MMMM('ar').format(_selectedDate)} • $_selectedTimeLabel'
                                : 'Selected appointment: ${intl.DateFormat.MMM('en').format(_selectedDate)} ${_selectedDate.day} • $_selectedTimeLabel',
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }

  Future<void> _loadAvailabilityData() async {
    setState(() => _isLoadingTimes = true);
    try {
      final providerJson = await ApiService().getProviderById(
        widget.request.providerId,
        realAvailability: true,
      );
      final provider = ProviderModel.fromJson(providerJson);
      final blockedSlots = await ApiService().getProviderBlockedSlots(
        widget.request.providerId,
      );

      final blocked = <String>{};
      for (final scheduledAt in blockedSlots) {
        if (scheduledAt.isEmpty) continue;
        blocked.add(scheduledAt);
      }

      if (!mounted) return;
      if (provider.availableSlots.isEmpty) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _providerSlots = provider.availableSlots;
        _blockedDateTimes
          ..clear()
          ..addAll(blocked);
        final firstDate = _firstSelectableDateFrom(_today);
        if (firstDate != null) {
          _selectedDate = firstDate;
          _visibleStartDate = _startOfWeek(firstDate);
          final availableTimesForFirstDate = _timeOptionsForDate(firstDate);
          if (availableTimesForFirstDate.length == 1) {
            _selectedTimeLabel = availableTimesForFirstDate.first;
          } else {
            _selectedTimeLabel = null;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _providerSlots = const [];
        _blockedDateTimes.clear();
      });
    } finally {
      if (mounted) setState(() => _isLoadingTimes = false);
    }
  }

  List<String> get _timeOptionsForSelectedDate {
    return _timeOptionsForDate(_selectedDate);
  }

  List<String> _timeOptionsForDate(DateTime? date) {
    if (date == null) return const [];
    final d = DateTime(date.year, date.month, date.day);
    if (_providerSlots.isEmpty) return const [];
    final targetWeekday = _safeWeekday(d);
    if (targetWeekday == null) return const [];
    final weekdayMap = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final sameDaySlots = _providerSlots.where((slot) {
      final dayRaw = slot.day.toString().trim().toLowerCase();
      if (dayRaw.isEmpty) return false;
      final weekday = weekdayMap[dayRaw];
      return weekday == null || weekday == targetWeekday;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final unique = <String>{};
    final formatted = <String>[];
    for (final slot in sameDaySlots) {
      final time24 = _normalizeTime(slot.startTime);
      if (time24 == null) continue;
      if (_isTimeInPast(d, time24)) continue;
      if (_isBlockedDateTime(d, time24)) continue;
      if (unique.add(time24)) {
        formatted.add(_to12h(time24));
      }
    }
    return formatted;
  }

  int? _safeWeekday(DateTime? value) {
    if (value == null) return null;
    try {
      return value.weekday;
    } catch (_) {
      return null;
    }
  }

  bool _isBlockedDateTime(DateTime date, String time24) {
    final datePart = date.toIso8601String().split('T').first;
    final exact = '$datePart $time24';
    final withSeconds = '$datePart $time24:00';
    return _blockedDateTimes.contains(exact) ||
        _blockedDateTimes.contains(withSeconds);
  }

  bool _isTimeInPast(DateTime date, String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return slotDateTime.isBefore(DateTime.now());
  }

  bool _isDateDisabled(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized.isBefore(_today)) return true;
    return _timeOptionsForDate(normalized).isEmpty;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  void _selectDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (_isDateDisabled(normalized)) return;
    setState(() {
      _selectedDate = normalized;
      _visibleStartDate = _startOfWeek(normalized);
      final times = _timeOptionsForDate(normalized);
      if (times.length == 1) {
        _selectedTimeLabel = times.first;
      } else {
        _selectedTimeLabel = null;
      }
    });
  }

  Future<void> _openCalendarPicker() async {
    DateTime visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final p = CarelinkPalette.of(context);
            final firstMonth = DateTime(_today.year, _today.month);
            final lastMonth = DateTime(_today.year + 1, 12);
            final canGoBack = visibleMonth.isAfter(firstMonth);
            final canGoForward = visibleMonth.isBefore(lastMonth);
            final firstOfMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month,
            );
            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;
            final leadingBlanks = firstOfMonth.weekday - DateTime.monday;
            final totalCells = leadingBlanks + daysInMonth;
            final rows = (totalCells / 7).ceil();
            final cellCount = rows * 7;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.stroke),
                boxShadow: [_cardShadow(p)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _monthYear(visibleMonth),
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: canGoBack
                            ? () => setModalState(() {
                                visibleMonth = DateTime(
                                  visibleMonth.year,
                                  visibleMonth.month - 1,
                                );
                              })
                            : null,
                        icon: Icon(
                          context.l10n.isArabic
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                        ),
                        color: AppColors.primary,
                      ),
                      IconButton(
                        onPressed: canGoForward
                            ? () => setModalState(() {
                                visibleMonth = DateTime(
                                  visibleMonth.year,
                                  visibleMonth.month + 1,
                                );
                              })
                            : null,
                        icon: Icon(
                          context.l10n.isArabic
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(7, (index) {
                      final date = DateTime(2026, 6, DateTime.monday + index);
                      return Expanded(
                        child: Center(
                          child: Text(
                            _shortDay(date),
                            style: TextStyle(
                              color: p.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cellCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemBuilder: (context, index) {
                      final day = index - leadingBlanks + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(
                        visibleMonth.year,
                        visibleMonth.month,
                        day,
                      );
                      return _calendarDayCell(context, p, date);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        context.l10n.isArabic
                            ? 'أيام فيها مواعيد متاحة'
                            : 'Available dates',
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked != null && mounted) _selectDate(picked);
  }

  Widget _calendarDayCell(
    BuildContext context,
    CarelinkPalette p,
    DateTime date,
  ) {
    final available = !_isDateDisabled(date);
    final selected = _isSameDay(date, _selectedDate);
    final muted = date.isBefore(_today) || !available;

    return PatientPressable(
      onTap: available ? () => Navigator.pop(context, date) : null,
      enabled: available,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : available
              ? AppColors.primary.withValues(alpha: p.isDark ? 0.13 : 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : available
                ? AppColors.primary.withValues(alpha: 0.20)
                : p.stroke.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : muted
                    ? p.inkMuted.withValues(alpha: 0.46)
                    : p.inkDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: available
                    ? (selected ? Colors.white : AppColors.primary)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _firstSelectableDateFrom(DateTime start) {
    for (var i = 0; i < 60; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      if (!_isDateDisabled(d)) return d;
    }
    return null;
  }

  String? _normalizeTime(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _to12h(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return time24;
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    if (context.l10n.isArabic) {
      final period = hour >= 12 ? 'م' : 'ص';
      return '${normalizedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${normalizedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _to24h(String time12) {
    final arabic = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(ص|م)$',
    ).firstMatch(time12.trim());
    if (arabic != null) {
      final hour12 = int.tryParse(arabic.group(1)!);
      final minute = int.tryParse(arabic.group(2)!);
      final period = arabic.group(3)!;
      if (hour12 == null || minute == null) return time12;
      var hour24 = hour12 % 12;
      if (period == 'م') hour24 += 12;
      return '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(time12.trim());
    if (match == null) return time12;
    final hour12 = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (hour12 == null || minute == null) return time12;
    var hour24 = hour12 % 12;
    if (period == 'PM') hour24 += 12;
    return '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
