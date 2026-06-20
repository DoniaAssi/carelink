import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'select_visit_location_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class BookingScreen extends StatefulWidget {
  final BookingRequestModel request;
  final bool previousTimeUnavailable;

  const BookingScreen({
    super.key,
    required this.request,
    this.previousTimeUnavailable = false,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _api = ApiService();
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
    _selectedTimeLabel =
        widget.previousTimeUnavailable ||
            widget.request.appointmentTime.trim().isEmpty
        ? null
        : widget.request.appointmentTime.trim();
    _loadAvailabilityData();
  }

  // ignore: unused_element
  List<DateTime> get _dateOptions {
    final dates = <DateTime>[];
    final weekStart = _startOfWeek(_selectedDate);
    for (var offset = 0; offset < 14; offset++) {
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

  bool _isChecking = false;

  Future<void> _continue() async {
    if (_selectedTimeLabel == null ||
        !_timeOptionsForSelectedDate.contains(_selectedTimeLabel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('booking.dateTime.chooseFirst'))),
      );
      return;
    }

    setState(() => _isChecking = true);

    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      final time24 = _to24h(_selectedTimeLabel!);

      // Re-validate availability
      final providerJson = await _api.getProviderById(
        widget.request.providerId,
        realAvailability: true,
      );
      final blocked = (await _api.getProviderBlockedSlots(
        widget.request.providerId,
      )).toSet();

      final availableSlots =
          (providerJson['availableSlots'] as List?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ??
          [];
      bool stillAvailable = false;
      for (final slot in availableSlots) {
        final time = (slot['startTime'] ?? '').toString();
        if (_normalizeTime(time) != time24) continue;

        final slotDateStr = slot['date']?.toString();
        if (slotDateStr != null && slotDateStr.isNotEmpty) {
          final parsed = DateTime.tryParse(slotDateStr);
          if (parsed != null &&
              parsed.year == _selectedDate.year &&
              parsed.month == _selectedDate.month &&
              parsed.day == _selectedDate.day) {
            stillAvailable = true;
            break;
          }
        } else {
          final slotDay = (slot['day'] ?? '').toString().toLowerCase();
          const weekdays = {
            'monday': DateTime.monday,
            'tuesday': DateTime.tuesday,
            'wednesday': DateTime.wednesday,
            'thursday': DateTime.thursday,
            'friday': DateTime.friday,
            'saturday': DateTime.saturday,
            'sunday': DateTime.sunday,
          };
          if (weekdays[slotDay] == _selectedDate.weekday) {
            stillAvailable = true;
            break;
          }
        }
      }

      if (!stillAvailable ||
          blocked.contains(
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} $time24',
          )) {
        if (!mounted) return;
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isArabic
                  ? 'عذراً، تم حجز هذا الموعد للتو. الرجاء اختيار وقت آخر.'
                  : 'Sorry, this appointment was just booked. Please choose another time.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadAvailabilityData();
        return;
      }

      // Duplicate booking check
      final isDuplicate = await _api.checkDuplicateBooking(
        patientId: widget.request.patientId,
        providerId: widget.request.providerId,
        serviceType: widget.request.serviceType,
        date: dateStr,
        time: time24,
      );

      if (!mounted) return;

      if (isDuplicate) {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isArabic
                  ? 'لديك طلب حجز موجود بالفعل لهذا الموعد.'
                  : 'You already have a booking request for this appointment.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() => _isChecking = false);

      final request = widget.request.copyWith(
        appointmentDate: dateStr,
        appointmentTime: time24,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectVisitLocationScreen(request: request),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _timeOptionsForSelectedDate;
    final canContinue =
        _selectedTimeLabel != null && options.contains(_selectedTimeLabel);

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
            onPressed: canContinue && !_isChecking ? _continue : null,
            isLoading: _isChecking,
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
            _providerSummaryCard(p),
            const SizedBox(height: 16),
            _dateSelector(p),
            const SizedBox(height: 18),
            Text(
              context.tr('booking.dateTime.selectTime'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: p.inkDark,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.previousTimeUnavailable) ...[
              _previousTimeUnavailableNotice(p),
              const SizedBox(height: 10),
            ],
            _timeSelector(p, options),
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
                  context.l10n.isArabic
                      ? 'لا توجد أوقات متاحة لهذا التاريخ. يرجى اختيار تاريخ آخر.'
                      : 'No available times for this date. Please choose another date.',
                  style: TextStyle(color: p.inkMuted),
                ),
              ),
            if (_selectedTimeLabel != null) ...[
              const SizedBox(height: 18),
              _selectedAppointmentSummary(p),
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

  Widget _previousTimeUnavailableNotice(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFF57F17),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.isArabic
                  ? 'وقت الموعد السابق لم يعد متاحاً. يرجى اختيار وقت متاح آخر.'
                  : 'Previous appointment time is no longer available.\nPlease choose another available time.',
              style: const TextStyle(
                color: Color(0xFFF57F17),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerSummaryCard(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
        boxShadow: [_cardShadow(p)],
      ),
      child: Row(
        children: [
          _providerAvatar(p),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.request.providerName.trim().isEmpty
                            ? (context.l10n.isArabic
                                  ? 'مقدم الرعاية'
                                  : 'Care provider')
                            : widget.request.providerName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.request.specialization.trim().isEmpty
                      ? widget.request.providerRole
                      : widget.request.specialization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.home_work_outlined,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.request.serviceType.trim().isEmpty
                              ? (context.l10n.isArabic ? 'الخدمة' : 'Service')
                              : widget.request.serviceType.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerAvatar(CarelinkPalette p) {
    final url = _imageUrl(widget.request.providerImageUrl);
    final name = widget.request.providerName.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: p.isDark ? 0.20 : 0.10),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'CL' : initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceSoft,
        border: Border.all(color: p.stroke.withValues(alpha: 0.6)),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _dateSelector(CarelinkPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.isArabic ? 'اختر تاريخاً' : 'Choose a date',
              style: TextStyle(
                color: p.inkDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            PatientPressable(
              borderRadius: BorderRadius.circular(12),
              onTap: _openCalendarPicker,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.stroke.withValues(alpha: 0.6)),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dateOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = _dateOptions[index];
              return _horizontalDateCard(p, date);
            },
          ),
        ),
      ],
    );
  }

  Widget _horizontalDateCard(CarelinkPalette p, DateTime date) {
    final selected = _isSameDay(date, _selectedDate);
    final available = !_isDateDisabled(date);
    return PatientPressable(
      enabled: available,
      onTap: available ? () => _selectDate(date) : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : available
                ? p.surface
                : p.surfaceSoft.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : available
                  ? p.stroke.withValues(alpha: 0.8)
                  : p.stroke.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _shortDay(date),
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.9)
                      : available
                      ? p.inkMuted
                      : p.inkMuted.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : available
                      ? p.inkDark
                      : p.inkMuted.withValues(alpha: 0.4),
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                intl.DateFormat.MMM('en').format(date),
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.9)
                      : available
                      ? p.inkMuted
                      : p.inkMuted.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeSelector(CarelinkPalette p, List<String> options) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((time) {
        final selected = _selectedTimeLabel == time;
        return PatientPressable(
          onTap: () => setState(() => _selectedTimeLabel = time),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : p.stroke.withValues(alpha: 0.7),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              time,
              style: TextStyle(
                color: selected ? Colors.white : p.inkDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _selectedAppointmentSummary(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.isArabic
                      ? 'Selected Appointment'
                      : 'Selected Appointment',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${intl.DateFormat.MMM('en').format(_selectedDate)} ${_selectedDate.day} • $_selectedTimeLabel',
                  style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _imageUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return value.startsWith('/')
        ? '${ApiService.baseUrl}$value'
        : '${ApiService.baseUrl}/$value';
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
      if (!ProviderBookingEligibility.canBook(provider)) {
        setState(() {
          _providerSlots = const [];
          _blockedDateTimes.clear();
          _selectedTimeLabel = null;
        });
        return;
      }

      _providerSlots = provider.availableSlots;
      _blockedDateTimes
        ..clear()
        ..addAll(blocked);
      final initialDate = _initialSelectableDate();
      if (initialDate == null) {
        setState(() {
          _selectedTimeLabel = null;
        });
        return;
      }

      setState(() {
        _selectedDate = initialDate;
        _visibleStartDate = DateTime(initialDate.year, initialDate.month);
        if (_selectedTimeLabel != null &&
            !_timeOptionsForDate(initialDate).contains(_selectedTimeLabel)) {
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
      final exactDate = DateTime.tryParse(slot.date.trim());
      if (exactDate != null) {
        return _isSameDay(exactDate, d);
      }
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

  DateTime get _visibleMonth =>
      DateTime(_visibleStartDate.year, _visibleStartDate.month);

  bool _canGoToPreviousMonth() {
    final current = _visibleMonth;
    final first = DateTime(_today.year, _today.month);
    return current.isAfter(first);
  }

  bool _canGoToNextMonth() {
    final current = _visibleMonth;
    final last = DateTime(_today.year + 1, 12);
    return current.isBefore(last);
  }

  void _changeVisibleMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final first = DateTime(_today.year, _today.month);
    final last = DateTime(_today.year + 1, 12);
    if (next.isBefore(first) || next.isAfter(last)) return;
    setState(() => _visibleStartDate = next);
  }

  // ignore: unused_element
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
      _visibleStartDate = DateTime(normalized.year, normalized.month);
      final times = _timeOptionsForDate(normalized);
      if (times.length == 1) {
        _selectedTimeLabel = times.first;
      } else {
        _selectedTimeLabel = null;
      }
    });
  }

  // ignore: unused_element
  Widget _buildInlineMonthCalendar(CarelinkPalette p) {
    final visibleMonth = _visibleMonth;
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthYear(visibleMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _monthNavButton(
                p,
                icon: context.l10n.isArabic
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                enabled: _canGoToPreviousMonth(),
                onTap: () => _changeVisibleMonth(-1),
              ),
              const SizedBox(width: 8),
              _monthNavButton(
                p,
                icon: context.l10n.isArabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                enabled: _canGoToNextMonth(),
                onTap: () => _changeVisibleMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(7, (index) {
              final labelDate = DateTime(2024, 1, DateTime.monday + index);
              return Expanded(
                child: Center(
                  child: Text(
                    _shortDay(labelDate),
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 9),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingBlanks + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(visibleMonth.year, visibleMonth.month, day);
              return _calendarDayCell(
                context,
                p,
                date,
                onSelected: () => _selectDate(date),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                context.l10n.isArabic ? 'Available dates' : 'Available dates',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthNavButton(
    CarelinkPalette p, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return PatientPressable(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? p.surface : p.surfaceSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: p.stroke.withValues(alpha: 0.72)),
        ),
        child: Icon(
          icon,
          color: enabled
              ? AppColors.primary
              : p.inkMuted.withValues(alpha: 0.42),
          size: 19,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openCalendarPicker() async {
    DateTime visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    DateTime sheetSelectedDate = _selectedDate;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.48),
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

            return FractionallySizedBox(
              heightFactor: 0.88,
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(color: p.stroke.withValues(alpha: 0.7)),
                    boxShadow: [_cardShadow(p)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.inkMuted.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _monthYear(visibleMonth),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.inkDark,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _monthNavButton(
                            p,
                            icon: context.l10n.isArabic
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            enabled: canGoBack,
                            onTap: () => setModalState(() {
                              visibleMonth = DateTime(
                                visibleMonth.year,
                                visibleMonth.month - 1,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          _monthNavButton(
                            p,
                            icon: context.l10n.isArabic
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            enabled: canGoForward,
                            onTap: () => setModalState(() {
                              visibleMonth = DateTime(
                                visibleMonth.year,
                                visibleMonth.month + 1,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: List.generate(7, (index) {
                          final date = DateTime(
                            2026,
                            6,
                            DateTime.monday + index,
                          );
                          return Expanded(
                            child: Center(
                              child: Text(
                                _shortDay(date),
                                style: TextStyle(
                                  color: p.inkMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cellCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
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
                          return _calendarDayCell(
                            context,
                            p,
                            date,
                            selectedDate: sheetSelectedDate,
                            onSelected: () => setModalState(() {
                              sheetSelectedDate = date;
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
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
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: p.isDark ? 0.16 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${intl.DateFormat.MMM('en').format(sheetSelectedDate)} ${sheetSelectedDate.day}, ${sheetSelectedDate.year}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.inkDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PatientPrimaryButton(
                        height: 52,
                        icon: Icons.check_rounded,
                        label: context.l10n.isArabic ? 'تم' : 'Done',
                        onPressed: () => Navigator.pop(
                          context,
                          DateTime(
                            sheetSelectedDate.year,
                            sheetSelectedDate.month,
                            sheetSelectedDate.day,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
    DateTime date, {
    DateTime? selectedDate,
    VoidCallback? onSelected,
  }) {
    final available = !_isDateDisabled(date);
    final selected = _isSameDay(date, selectedDate ?? _selectedDate);
    final muted = date.isBefore(_today) || !available;

    return PatientPressable(
      onTap: available
          ? (onSelected ?? () => Navigator.pop(context, date))
          : null,
      enabled: available,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.94,
          heightFactor: 0.94,
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : available
                  ? AppColors.primary.withValues(alpha: p.isDark ? 0.15 : 0.10)
                  : p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : available
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : p.stroke.withValues(alpha: 0.62),
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
                        ? p.inkMuted.withValues(alpha: 0.58)
                        : p.inkDark,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 5.5,
                  height: 5.5,
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

  DateTime? _initialSelectableDate() {
    final oldDate = DateTime.tryParse(widget.request.appointmentDate.trim());
    if (widget.previousTimeUnavailable && oldDate != null) {
      final normalizedOld = DateTime(oldDate.year, oldDate.month, oldDate.day);
      if (!_isDateDisabled(normalizedOld)) return normalizedOld;
    }
    return _firstSelectableDateFrom(_today);
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
