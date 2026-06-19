import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/patient/screens/select_visit_location_screen.dart';

class SmartRebookModal extends StatefulWidget {
  final BookingRequestModel request;
  final VoidCallback onSuccess;

  const SmartRebookModal({
    super.key,
    required this.request,
    required this.onSuccess,
  });

  @override
  State<SmartRebookModal> createState() => _SmartRebookModalState();
}

class _SmartRebookModalState extends State<SmartRebookModal> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  DateTime? _nearestDate;
  String? _nearestTime;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final providerJson = await _api.getProviderById(
        widget.request.providerId,
        realAvailability: true,
      );
      final blocked = (await _api.getProviderBlockedSlots(widget.request.providerId)).toSet();

      final availableSlots = (providerJson['availableSlots'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ?? [];

      DateTime? nearestDate;
      String? nearestTime;

      final now = DateTime.now();
      for (var offset = 0; offset < 365; offset++) {
        final date = DateTime(now.year, now.month, now.day + offset);
        for (final slot in availableSlots) {
          final time = (slot['startTime'] ?? '').toString();
          if (time.isEmpty) continue;

          final slotDateStr = slot['date']?.toString();
          if (slotDateStr != null && slotDateStr.isNotEmpty) {
             final parsed = DateTime.tryParse(slotDateStr);
             if (parsed == null || parsed.year != date.year || parsed.month != date.month || parsed.day != date.day) continue;
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
             if (weekdays[slotDay] != date.weekday) continue;
          }

          final timeParts = time.split(':');
          if (timeParts.length < 2) continue;
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final min = int.tryParse(timeParts[1]) ?? 0;
          final slotDateTime = DateTime(date.year, date.month, date.day, hour, min);

          if (slotDateTime.isBefore(now)) continue;
          if (blocked.contains('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $time')) continue;

          nearestDate = date;
          nearestTime = time;
          break;
        }
        if (nearestDate != null) break;
      }

      if (!mounted) return;
      setState(() {
        _nearestDate = nearestDate;
        _nearestTime = nearestTime;
        _isLoading = false;

        if (nearestDate == null) {
          _errorMessage = context.l10n.isArabic
              ? 'لا توجد مواعيد متاحة حالياً.'
              : 'No available appointments right now.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _useThisAppointment() async {
    if (_nearestDate == null || _nearestTime == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Revalidate Availability (to ensure it wasn't taken moments ago)
      final providerJson = await _api.getProviderById(
        widget.request.providerId,
        realAvailability: true,
      );
      final blocked = (await _api.getProviderBlockedSlots(widget.request.providerId)).toSet();

      final availableSlots = (providerJson['availableSlots'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ?? [];
      bool stillAvailable = false;

      for (final slot in availableSlots) {
         final time = (slot['startTime'] ?? '').toString();
        if (time != _nearestTime) continue;

         final slotDateStr = slot['date']?.toString();
         if (slotDateStr != null && slotDateStr.isNotEmpty) {
             final parsed = DateTime.tryParse(slotDateStr);
             if (parsed != null && parsed.year == _nearestDate!.year && parsed.month == _nearestDate!.month && parsed.day == _nearestDate!.day) {
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
             if (weekdays[slotDay] == _nearestDate!.weekday) {
                 stillAvailable = true;
                 break;
             }
         }
      }

      if (!stillAvailable || blocked.contains('${_nearestDate!.year}-${_nearestDate!.month.toString().padLeft(2, '0')}-${_nearestDate!.day.toString().padLeft(2, '0')} $_nearestTime')) {
         if (!mounted) return;
         setState(() => _isSaving = false);
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
         _loadAvailability();
         return;
      }

      // 2. Check Duplicate
      final dateStr = '${_nearestDate!.year}-${_nearestDate!.month.toString().padLeft(2, '0')}-${_nearestDate!.day.toString().padLeft(2, '0')}';
      final isDuplicate = await _api.checkDuplicateBooking(
        patientId: widget.request.patientId,
        providerId: widget.request.providerId,
        serviceType: widget.request.serviceType,
        date: dateStr,
        time: _nearestTime!,
      );

      if (!mounted) return;

      if (isDuplicate) {
        setState(() => _isSaving = false);
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

      setState(() => _isSaving = false);

      final newRequest = widget.request.copyWith(
        appointmentDate: dateStr,
        appointmentTime: _nearestTime,
      );

      widget.onSuccess();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectVisitLocationScreen(request: newRequest),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _chooseAnotherTime() {
    widget.onSuccess();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(request: widget.request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final isAr = context.l10n.isArabic;
    final bottomInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _buildBody(p, isAr),
        ),
      ),
    );
  }

  Widget _buildBody(CarelinkPalette p, bool isAr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.stroke,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isAr ? 'احجز مجدداً' : 'Book Again',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: p.inkDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: p.inkMuted),
                style: IconButton.styleFrom(backgroundColor: p.surfaceSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _isLoading
                ? _buildLoadingSkeleton(p)
                : _errorMessage != null
                    ? _buildErrorState(p, isAr)
                    : _buildNearestAppointmentContent(p, isAr),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoadingSkeleton(CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            context.l10n.isArabic ? 'جاري البحث عن مواعيد...' : 'Finding available slots...',
            style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CarelinkPalette p, bool isAr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.calendar_today_rounded, size: 48, color: p.inkMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkDark, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          PatientPrimaryButton(
            onPressed: () {
               widget.onSuccess();
               ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                     content: Text(
                        isAr ? 'سنقوم بإعلامك عند توفر مواعيد.' : 'We will notify you when appointments become available.',
                     ),
                  ),
               );
            },
            label: isAr ? 'أعلمني عند توفر مواعيد' : 'Notify me when available',
            icon: Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 12),
          PatientSecondaryButton(
            onPressed: () {
              widget.onSuccess();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            label: isAr ? 'اختيار مقدم آخر' : 'Choose another provider',
            icon: Icons.groups_2_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildNearestAppointmentContent(CarelinkPalette p, bool isAr) {
    final monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final monthName = isAr ? monthsAr[_nearestDate!.month - 1] : monthsEn[_nearestDate!.month - 1];
    final dateStr = '${_nearestDate!.day} $monthName ${_nearestDate!.year}';

    final hour = int.parse(_nearestTime!.split(':')[0]);
    final minute = _nearestTime!.split(':')[1];
    final suffixEn = hour >= 12 ? 'PM' : 'AM';
    final suffixAr = hour >= 12 ? 'م' : 'ص';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$hour12:$minute ${isAr ? suffixAr : suffixEn}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'أقرب موعد متاح' : 'Nearest available appointment',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: widget.request.providerImageUrl.isNotEmpty
                        ? NetworkImage(widget.request.providerImageUrl)
                        : null,
                    child: widget.request.providerImageUrl.isEmpty
                        ? const Icon(Icons.person_rounded, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.providerName,
                          style: TextStyle(
                            color: p.inkDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.request.serviceType,
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PatientPrimaryButton(
          onPressed: _useThisAppointment,
          isLoading: _isSaving,
          label: isAr ? 'استخدام هذا الموعد' : 'Use this appointment',
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(height: 12),
        PatientSecondaryButton(
          onPressed: _isSaving ? null : _chooseAnotherTime,
          label: isAr ? 'اختر موعداً آخر' : 'Choose another time',
          icon: Icons.calendar_month_outlined,
        ),
      ],
    );
  }
}
