import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_date_picker.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'select_visit_location_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/booking_provider_summary.dart';
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
    for (var offset = 0; offset < 90 && dates.length < 8; offset++) {
      final date = DateTime(
        _visibleStartDate.year,
        _visibleStartDate.month,
        _visibleStartDate.day + offset,
      );
      if (!_isDateDisabled(date)) dates.add(date);
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
    final providerUnavailable = !_isLoadingTimes && _providerSlots.isEmpty;
    final canContinue = _selectedTimeLabel != null && !providerUnavailable;
    final options = _timeOptionsForSelectedDate;

    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(title: context.tr('booking.dateTime.title')),
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
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.stroke),
                boxShadow: [_cardShadow(p)],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('booking.dateTime.prompt'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.inkDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('booking.dateTime.promptSubtitle'),
                          style: TextStyle(color: p.inkMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.schedule_rounded, color: AppColors.primary),
                ],
              ),
            ),
            if (providerUnavailable) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: p.isDark
                      ? const Color(0xFF311C1A)
                      : const Color(0xFFFFF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: p.isDark
                        ? const Color(0xFF67413D)
                        : const Color(0xFFF0C9C6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      color: Color(0xFFC64A44),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('booking.dateTime.notAvailable'),
                        style: const TextStyle(
                          color: Color(0xFF9F3E38),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!providerUnavailable) ...[
              Row(
                children: [
                  Text(
                    context.tr('booking.dateTime.selectDate'),
                    style: TextStyle(
                      color: p.inkDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickMonthYear,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.stroke),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: p.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _monthYear(_selectedDate),
                            style: TextStyle(
                              color: p.inkDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: p.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dateOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = _dateOptions[index];
                    final selected =
                        d.year == _selectedDate.year &&
                        d.month == _selectedDate.month &&
                        d.day == _selectedDate.day;
                    final disabled = _isDateDisabled(d);
                    return GestureDetector(
                      onTap: disabled
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = d;
                                _selectedTimeLabel = null;
                              });
                            },
                      child: Container(
                        width: context.l10n.isArabic ? 82 : 62,
                        decoration: BoxDecoration(
                          color: disabled
                              ? p.surfaceSoft.withValues(alpha: 0.72)
                              : selected
                              ? AppColors.primary
                              : p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: disabled
                                ? p.stroke
                                : selected
                                ? AppColors.primary
                                : p.stroke,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _shortDay(d),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: disabled
                                        ? p.inkMuted.withValues(alpha: 0.55)
                                        : selected
                                        ? const Color(0xFFCDEEEA)
                                        : p.inkMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                color: disabled
                                    ? p.inkMuted.withValues(alpha: 0.55)
                                    : selected
                                    ? Colors.white
                                    : p.inkDark,
                                fontWeight: FontWeight.w700,
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
              const SizedBox(height: 14),
              Text(
                context.tr('booking.dateTime.selectTime'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: options.map((time) {
                  final selected = _selectedTimeLabel == time;
                  final disabled = _isBlockedTime(time);
                  return GestureDetector(
                    onTap: disabled
                        ? null
                        : () => setState(() => _selectedTimeLabel = time),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: disabled
                            ? p.surfaceSoft.withValues(alpha: 0.72)
                            : selected
                            ? AppColors.primary
                            : p.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: disabled
                              ? p.stroke
                              : selected
                              ? AppColors.primary
                              : p.stroke,
                        ),
                      ),
                      child: Text(
                        disabled
                            ? '$time - ${context.l10n.isArabic ? 'محجوز' : 'Booked'}'
                            : time,
                        style: TextStyle(
                          color: disabled
                              ? p.inkMuted.withValues(alpha: 0.55)
                              : selected
                              ? Colors.white
                              : p.inkDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.stroke),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('booking.dateTime.approx'),
                        style: TextStyle(color: p.inkMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.stroke),
                ),
                child: Text(
                  context.tr('booking.dateTime.chooseAnotherProvider'),
                  style: TextStyle(color: p.inkMuted, fontSize: 12),
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
      final providerJson = await ApiService().getDoctorById(
        widget.request.providerId,
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
      setState(() {
        _providerSlots = provider.availableSlots;
        _blockedDateTimes
          ..clear()
          ..addAll(blocked);
        final firstDate = _firstSelectableDateFrom(_today);
        if (firstDate != null) {
          _selectedDate = firstDate;
          _visibleStartDate = firstDate;
          _selectedTimeLabel = null;
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

  bool _isBlockedTime(String label12h) {
    final time24 = _to24h(label12h);
    return _isBlockedDateTime(_selectedDate, time24);
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

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_today) ? _today : _selectedDate,
      firstDate: _today,
      lastDate: DateTime(_today.year + 1, 12, 31),
      helpText: context.tr('booking.dateTime.monthHelp'),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) => CarelinkDatePickerTheme.wrap(context, child),
    );
    if (picked == null || !mounted) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    final fallback =
        _firstSelectableDateFrom(normalized) ??
        _firstSelectableDateFrom(_today) ??
        _today;

    setState(() {
      _selectedDate = _isDateDisabled(normalized) ? fallback : normalized;
      _visibleStartDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      _selectedTimeLabel = null;
    });
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
