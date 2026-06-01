import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class RescheduleModal extends StatefulWidget {
  final String appointmentId;
  final String providerUserId;
  final VoidCallback onSuccess;
  final String? oldDateTime;

  const RescheduleModal({
    super.key,
    required this.appointmentId,
    required this.providerUserId,
    required this.onSuccess,
    this.oldDateTime,
  });

  @override
  State<RescheduleModal> createState() => _RescheduleModalState();
}

class _RescheduleModalState extends State<RescheduleModal> {
  final ApiService _api = ApiService();
  bool isLoading = true;
  String? errorMessage;

  List<AvailabilitySlot> _providerSlots = [];
  List<dynamic> _existingAppointments = [];

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailabilityAndBookings();
  }

  Future<void> _loadAvailabilityAndBookings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Fetch provider slots
      final providerJson = await _api.getProviderById(widget.providerUserId);
      final provider = ProviderModel.fromJson(providerJson);
      _providerSlots = provider.availableSlots;

      // 2. Fetch existing appointments
      _existingAppointments = await _api.getProviderAppointments(
        widget.providerUserId,
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
          isLoading = false;
        });
      }
    }
  }

  // Get day name of week in lowercase
  String _getWeekdayName(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  // Check if a time slot is already booked for a specific date
  bool _isSlotBooked(DateTime date, AvailabilitySlot slot) {
    final slotTimeParts = slot.startTime.split(':');
    if (slotTimeParts.length < 2) return false;
    final slotHour = int.tryParse(slotTimeParts[0]) ?? 0;
    final slotMin = int.tryParse(slotTimeParts[1]) ?? 0;

    for (final app in _existingAppointments) {
      final status = (app['status'] ?? '').toString().toLowerCase().trim();
      if (status == 'cancelled' || status == 'canceled') continue;

      final rawScheduled = app['scheduledAt'];
      if (rawScheduled == null) continue;

      final scheduledDate = DateTime.tryParse(
        rawScheduled.toString().replaceFirst(' ', 'T'),
      );
      if (scheduledDate == null) continue;

      if (scheduledDate.year == date.year &&
          scheduledDate.month == date.month &&
          scheduledDate.day == date.day &&
          scheduledDate.hour == slotHour &&
          scheduledDate.minute == slotMin) {
        return true; // Already booked!
      }
    }
    return false;
  }

  // Get list of available time slots for a given date
  List<String> _getAvailableTimeSlots(DateTime date) {
    final weekdayName = _getWeekdayName(date.weekday);
    final slotsForDay = _providerSlots
        .where((s) => s.day.toLowerCase().trim() == weekdayName)
        .toList();

    // Sort slots by start time
    slotsForDay.sort((a, b) => a.startTime.compareTo(b.startTime));

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final availableTimes = <String>[];
    for (final slot in slotsForDay) {
      if (isToday) {
        final slotTimeParts = slot.startTime.split(':');
        if (slotTimeParts.length >= 2) {
          final slotHour = int.tryParse(slotTimeParts[0]) ?? 0;
          final slotMin = int.tryParse(slotTimeParts[1]) ?? 0;
          if (slotHour < now.hour ||
              (slotHour == now.hour && slotMin <= now.minute)) {
            continue; // Skip past time slots for today
          }
        }
      }
      if (!_isSlotBooked(date, slot)) {
        availableTimes.add(_formatTo12Hour(slot.startTime));
      }
    }
    return availableTimes;
  }

  // Check if date has any available slots
  bool _isDateAvailable(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today)) return false; // Past dates are unavailable

    return _getAvailableTimeSlots(date).isNotEmpty;
  }

  String _formatTo12Hour(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$min $suffix';
  }

  String _format24Hour(String time12) {
    // Expected format: "9:00 AM" or "10:30 PM"
    final parts = time12.split(' ');
    if (parts.isEmpty) return time12;

    final timePart = parts[0];
    final suffix = parts.length > 1 ? parts[1].toUpperCase() : 'AM';

    final timeParts = timePart.split(':');
    if (timeParts.length < 2) return time12;

    int hour = int.tryParse(timeParts[0]) ?? 0;
    final min = timeParts[1];

    if (suffix == 'PM' && hour < 12) {
      hour += 12;
    } else if (suffix == 'AM' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:${min.padLeft(2, '0')}';
  }

  Future<void> _reschedule() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'الرجاء اختيار تاريخ الحجز أولاً'
                : 'Please select a date first',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'الرجاء اختيار وقت الحجز أولاً'
                : 'Please select a time first',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_isSaving) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate!.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'لا يمكن اختيار تاريخ في الماضي'
                : 'Cannot select a date in the past',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final time24 = _format24Hour(_selectedTime!);
    final timeParts = time24.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final min = int.tryParse(timeParts[1]) ?? 0;

    if (_selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day) {
      if (hour < now.hour || (hour == now.hour && min <= now.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isArabic
                  ? 'لا يمكن اختيار وقت في الماضي'
                  : 'Cannot select a time in the past',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T').first;
      await _api.rescheduleAppointment(
        appointmentId: widget.appointmentId,
        date: dateStr,
        time: time24,
      );

      if (!mounted) return;

      final successMsg = context.l10n.isArabic
          ? 'تم تعديل الموعد بنجاح'
          : 'Appointment updated successfully';

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Notify parent to close modal and refresh data
      try {
        widget.onSuccess();
      } catch (_) {
        // Fallback: close the sheet if parent callback fails
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final rawErr = e.toString().replaceFirst('Exception: ', '').trim();
      final err =
          (rawErr.toLowerCase().contains('html') ||
              rawErr.contains('<!') ||
              rawErr.contains('<html') ||
              rawErr.contains('<body>'))
          ? (context.l10n.isArabic
                ? 'تعذر تعديل الموعد، حاول مرة أخرى'
                : 'Failed to edit appointment, please try again')
          : (context.l10n.isArabic
                ? 'تعذر تعديل الموعد، حاول مرة أخرى'
                : 'Failed to edit appointment, please try again');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.stroke, width: 0.5),
      ),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Keep the modal within the visible viewport and allow scrolling when space is limited
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('schedule.edit.title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: p.inkDark,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: p.inkMuted),
                      style: IconButton.styleFrom(
                        backgroundColor: p.surfaceSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAvailabilityAndBookings,
                          child: Text(context.tr('booking.tryAgain')),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Date Selection Header
                  Text(
                    context.tr('booking.dateTime.selectDate'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: p.inkDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Calendar View
                  _buildCalendarPicker(p),
                  const SizedBox(height: 20),

                  // Time Selection Section
                  if (_selectedDate != null) ...[
                    Text(
                      context.tr('schedule.edit.selectTime'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.inkDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTimeSlotsSection(p),
                    const SizedBox(height: 24),
                  ],

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          _selectedDate == null ||
                              _selectedTime == null ||
                              _isSaving
                          ? null
                          : _reschedule,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: p.stroke,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.tr('schedule.edit.save'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPicker(CarelinkPalette p) {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstDayOffset =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final totalCells = daysInMonth + firstDayOffset;

    final monthNameEn = [
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
    ][_focusedMonth.month - 1];

    final monthNameAr = [
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
    ][_focusedMonth.month - 1];

    final monthLabel = context.l10n.isArabic
        ? '$monthNameAr ${_focusedMonth.year}'
        : '$monthNameEn ${_focusedMonth.year}';

    final weekHeaders = context.l10n.isArabic
        ? ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
        : ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          // Month Switcher Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final isCurrentOrPastMonth =
                      _focusedMonth.year < now.year ||
                      (_focusedMonth.year == now.year &&
                          _focusedMonth.month <= now.month);
                  return IconButton(
                    onPressed: isCurrentOrPastMonth
                        ? null
                        : () {
                            setState(() {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month - 1,
                              );
                            });
                          },
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isCurrentOrPastMonth
                          ? p.inkMuted.withValues(alpha: 0.3)
                          : p.inkDark,
                    ),
                  );
                },
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: p.inkDark,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    );
                  });
                },
                icon: Icon(Icons.chevron_right_rounded, color: p.inkDark),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Week Headers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekHeaders.map((h) {
              return SizedBox(
                width: 32,
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.inkMuted,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) {
                return const SizedBox.shrink();
              }

              final dayNum = index - firstDayOffset + 1;
              final cellDate = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNum,
              );
              final isAvailable = _isDateAvailable(cellDate);

              final isSelected =
                  _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;

              return GestureDetector(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _selectedDate = cellDate;
                          _selectedTime = null;
                        });
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isAvailable && !isSelected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected || isAvailable
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isAvailable
                          ? p.inkDark
                          : p.inkMuted.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsSection(CarelinkPalette p) {
    final availableTimes = _getAvailableTimeSlots(_selectedDate!);

    if (availableTimes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            context.tr('booking.dateTime.noTimes'),
            style: TextStyle(color: p.inkMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: availableTimes.map((time) {
        final isSel = _selectedTime == time;
        return Material(
          color: isSel ? AppColors.primary : p.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTime = time;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 90, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? AppColors.primary : p.stroke,
                  width: 1,
                ),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSel ? Colors.white : p.inkDark,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
