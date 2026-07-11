import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class RescheduleModal extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback onSuccess;

  const RescheduleModal({
    super.key,
    required this.appointment,
    required this.onSuccess,
  });

  @override
  State<RescheduleModal> createState() => _RescheduleModalState();
}

class _AppointmentSlot {
  const _AppointmentSlot({required this.date, required this.time});

  final DateTime date;
  final String time;
}

class _RescheduleModalState extends State<RescheduleModal> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<AvailabilitySlot> _providerSlots = const [];
  List<dynamic> _existingAppointments = const [];
  DateTime _weekStart = _startOfWeek(DateTime.now());
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _visibleDays = 14;
  bool _showCalendar = false;
  bool _showInlineConfirm = false;

  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadAvailabilityAndBookings();
  }

  Future<void> _loadAvailabilityAndBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final providerJson = await _api.getProviderById(
        widget.appointment.providerUserId,
        realAvailability: true,
      );
      final provider = ProviderModel.fromJson(providerJson);
      final appointments = await _api.getProviderAppointments(
        widget.appointment.providerUserId,
      );

      if (!mounted) return;
      setState(() {
        _providerSlots = provider.availableSlots;
        _existingAppointments = appointments;
        _isLoading = false;
      });

      final nearest = _nearestSlot;
      if (nearest != null && mounted) {
        setState(() {
          _selectedDate = nearest.date;
          _selectedTime = nearest.time;
          _weekStart = _startOfWeek(nearest.date);
          _visibleMonth = DateTime(nearest.date.year, nearest.date.month);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.userMessage(e);
        _isLoading = false;
      });
    }
  }

  _AppointmentSlot? get _nearestSlot {
    final today = _today;
    for (var offset = 0; offset < 180; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final times = _availableTimeSlots(date);
      if (times.isNotEmpty) {
        return _AppointmentSlot(date: date, time: times.first);
      }
    }
    return null;
  }

  DateTime? get _currentAppointment => widget.appointment.scheduledAt;

  List<DateTime> get _visibleWeekDates {
    return List.generate(
      _visibleDays,
      (index) =>
          DateTime(_weekStart.year, _weekStart.month, _weekStart.day + index),
    );
  }

  bool get _canSave =>
      _selectedDate != null && _selectedTime != null && !_isSaving;

  bool get _requiresProviderApproval =>
      widget.appointment.status.toLowerCase().trim() == 'confirmed';

  Future<void> _beginRescheduleConfirmation() async {
    if (!_canSave) return;

    final date = _selectedDate!;
    final time24 = _format24Hour(_selectedTime!);
    final current = _currentAppointment;
    if (current != null &&
        DateUtils.isSameDay(current, date) &&
        _formatTime24(current) == time24) {
      _showSnack(
        context.l10n.isArabic
            ? 'اختر موعداً مختلفاً عن موعدك الحالي.'
            : 'Choose a different time from your current appointment.',
        isError: true,
      );
      return;
    }

    final available = _availableTimeSlots(date).contains(_selectedTime);
    if (!available || _slotDateTime(date, time24).isBefore(DateTime.now())) {
      _showSnack(
        context.l10n.isArabic
            ? 'هذا الموعد غير متاح حالياً، اختر موعداً آخر.'
            : 'This time is not available. Please choose another time.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isDuplicate = await _api.checkDuplicateBooking(
        patientId: widget.appointment.patientUserId,
        providerId: widget.appointment.providerUserId,
        serviceType: widget.appointment.specialization,
        date: _formatIsoDate(date),
        time: time24,
      );
      if (!mounted) return;

      if (isDuplicate) {
        setState(() => _isSaving = false);
        _showSnack(
          context.l10n.isArabic
              ? 'لديك طلب حجز موجود بالفعل لهذا الموعد.'
              : 'You already have a booking request for this appointment.',
          isError: true,
        );
        return;
      }

      setState(() {
        _isSaving = false;
        _showInlineConfirm = true;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        context.l10n.isArabic
            ? 'تعذر التحقق من الموعد، حاول مرة أخرى'
            : 'Failed to verify this appointment, please try again',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reschedule() async {
    if (!_canSave) return;

    final date = _selectedDate!;
    final time24 = _format24Hour(_selectedTime!);
    
    print('--- FLUTTER UI DEBUG ---');
    print('Current appointment status before submit: ${widget.appointment.status}');
    print('----------------------------');

    setState(() => _isSaving = true);
    try {
      await _api.rescheduleAppointment(
        appointmentId: widget.appointment.appointmentId,
        date: _formatIsoDate(date),
        time: time24,
      );
      if (!mounted) return;

      _showSnack(
        context.l10n.isArabic
            ? (_requiresProviderApproval
                  ? 'طلب تغيير الموعد بانتظار الموافقة'
                  : 'تم تعديل الموعد بنجاح')
            : (_requiresProviderApproval
                  ? 'Reschedule request pending approval'
                  : 'Appointment updated successfully'),
      );
      widget.onSuccess();
    } catch (e, st) {
      print('--- RESCHEDULE EXCEPTION ---');
      print(e);
      print(st);
      print('----------------------------');
      if (!mounted) return;
      
      String errMsg = e.toString().replaceAll('Exception: ', '');
      if (errMsg.trim().isEmpty || errMsg.toLowerCase().contains('failed to edit')) {
        errMsg = context.l10n.isArabic
            ? 'تعذر تعديل الموعد، حاول مرة أخرى'
            : 'Failed to edit appointment, please try again';
      }

      _showSnack(
        errMsg,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? p.pageBg : const Color(0xFFF0FAF7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: p.stroke.withValues(alpha: 0.5), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(0.18),
            blurRadius: 34,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _buildBody(p),
        ),
      ),
    );
  }

  Widget _buildBody(CarelinkPalette p) {
    final isAr = context.l10n.isArabic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 5,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: p.inkMuted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            _sheetIconButton(
              p,
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr ? 'إعادة جدولة الموعد' : 'Reschedule Appointment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: p.inkDark,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isAr
                        ? 'اختر تاريخاً ووقتاً مناسبين لك'
                        : 'Choose a new date and time',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _sheetIconButton(
              p,
              icon: Icons.calendar_month_rounded,
              onTap: _showInlineConfirm
                  ? () => setState(() => _showInlineConfirm = false)
                  : () => setState(() => _showCalendar = !_showCalendar),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : _errorMessage != null
                ? _buildError(p)
                : _showInlineConfirm
                ? _buildInlineConfirmation(p, isAr)
                : _buildPicker(p, isAr),
          ),
        ),
        if (!_isLoading && _errorMessage == null) ...[
          const SizedBox(height: 16),
          _showInlineConfirm
              ? _buildInlineConfirmActions(p, isAr)
              : PatientPrimaryButton(
                  height: 56,
                  icon: Icons.event_available_rounded,
                  isLoading: _isSaving,
                  onPressed: _canSave ? _beginRescheduleConfirmation : null,
                  label: isAr
                      ? (_requiresProviderApproval
                            ? 'إرسال طلب تغيير الموعد'
                            : 'تأكيد الموعد الجديد')
                      : (_requiresProviderApproval
                            ? 'Submit reschedule request'
                            : 'Confirm New Appointment'),
                ),
        ],
      ],
    );
  }

  Widget _sheetIconButton(
    CarelinkPalette p, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: p.cardShadowColor(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 25),
      ),
    );
  }

  Widget _pickerCard(CarelinkPalette p, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInlineConfirmation(CarelinkPalette p, bool isAr) {
    final date = _selectedDate;
    final time = _selectedTime;
    final dateLabel = date == null ? '' : _formatDateTitle(date, isAr);

    return _pickerCard(
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'تأكيد إعادة الجدولة' : 'Confirm Reschedule',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _requiresProviderApproval
                ? (isAr
                      ? 'سيتم إرسال طلب تغيير الموعد إلى مقدم الرعاية وسيبقى موعدك الحالي فعالاً حتى تتم الموافقة.'
                      : 'Your appointment will be updated to the selected date and time and will wait for the provider\'s approval.')
                : (isAr
                      ? 'سيتم تحديث طلب الحجز إلى التاريخ والوقت المحددين.'
                      : 'Your booking request will be updated to the selected date and time.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.stroke.withValues(alpha: 0.65)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  time ?? '',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
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

  Widget _buildInlineConfirmActions(CarelinkPalette p, bool isAr) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving
                ? null
                : () => setState(() => _showInlineConfirm = false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: p.inkDark,
              side: BorderSide(color: p.stroke),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(isAr ? 'رجوع' : 'Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PatientPrimaryButton(
            height: 56,
            icon: Icons.check_circle_rounded,
            isLoading: _isSaving,
            onPressed: _canSave ? _reschedule : null,
            label: isAr ? 'تأكيد' : 'Confirm',
          ),
        ),
      ],
    );
  }

  Widget _buildPicker(CarelinkPalette p, bool isAr) {
    final nearest = _nearestSlot;
    if (nearest == null) return _buildEmptyState(p, isAr);

    return _pickerCard(
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            p,
            isAr ? 'اختر تاريخاً جديداً' : 'Choose a new date',
            isAr
                ? 'الأيام المتاحة فقط للاختيار'
                : 'Only available days can be selected.',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 14),
          _buildWeekSelector(p, isAr),
          if (_showCalendar) ...[
            const SizedBox(height: 14),
            _buildMonthCalendar(p, isAr),
          ],
          const SizedBox(height: 20),
          Divider(color: p.stroke.withValues(alpha: 0.55), height: 1),
          const SizedBox(height: 20),
          _sectionTitle(
            p,
            isAr ? 'اختر وقتاً متاحاً' : 'Choose an available time',
            isAr
                ? 'اختر الوقت الأنسب من المواعيد المتاحة'
                : 'Pick the time that works best for you.',
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(height: 14),
          _buildTimeChips(p),
          const SizedBox(height: 16),
          _buildInfoBanner(
            p: p,
            isAr: isAr,
            color: AppColors.primary,
            icon: Icons.info_outline_rounded,
            textAr: 'جميع الأوقات معروضة بتوقيتك المحلي.',
            textEn: 'All times are shown in your local timezone.',
          ),
          if (_requiresProviderApproval) ...[
            const SizedBox(height: 10),
            _buildInfoBanner(
              p: p,
              isAr: isAr,
              color: AppColors.warning,
              icon: Icons.hourglass_bottom_rounded,
              textAr:
                  'موعدك الحالي يبقى فعالاً حتى يوافق مقدم الرعاية على الموعد الجديد.',
              textEn:
                  'Your current appointment remains active until the provider approves the new time.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required CarelinkPalette p,
    required bool isAr,
    required Color color,
    required IconData icon,
    required String textAr,
    required String textEn,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: p.isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAr ? textAr : textEn,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCurrentAppointmentCard(CarelinkPalette p, bool isAr) {
    final a = widget.appointment;
    final dateStr = a.scheduledAt != null
        ? _formatShortDate(a.scheduledAt!, isAr)
        : '';
    final timeStr = a.scheduledAt != null
        ? _formatTo12Hour(_formatTime24(a.scheduledAt!))
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isAr ? 'موعدك الحالي' : 'Current appointment',
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniSummary(
                  p,
                  icon: Icons.person_rounded,
                  label: isAr ? 'مقدم الرعاية' : 'Provider',
                  value: a.providerName.isNotEmpty
                      ? a.providerName
                      : (isAr ? 'مقدم الرعاية' : 'Provider'),
                ),
              ),
              Expanded(
                child: _miniSummary(
                  p,
                  icon: Icons.medical_services_rounded,
                  label: isAr ? 'الخدمة' : 'Service',
                  value: a.specialization.isNotEmpty
                      ? a.specialization
                      : (isAr ? 'خدمة رعاية' : 'Care Service'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniSummary(
                  p,
                  icon: Icons.calendar_today_rounded,
                  label: isAr ? 'التاريخ' : 'Date',
                  value: dateStr.isNotEmpty
                      ? dateStr
                      : (isAr ? 'غير متوفر' : 'Unavailable'),
                ),
              ),
              Expanded(
                child: _miniSummary(
                  p,
                  icon: Icons.access_time_rounded,
                  label: isAr ? 'الوقت' : 'Time',
                  value: timeStr.isNotEmpty
                      ? timeStr
                      : (isAr ? 'غير متوفر' : 'Unavailable'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniSummary(
                  p,
                  icon: Icons.info_outline_rounded,
                  label: isAr ? 'الحالة' : 'Status',
                  value: isAr ? 'حجز حالي' : 'Current booking',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniSummary(
    CarelinkPalette p, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildNearestCard(
    CarelinkPalette p,
    bool isAr,
    _AppointmentSlot nearest,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF123A36) : const Color(0xFFE8F7F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.35 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'أقرب موعد متاح' : 'Nearest available appointment',
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDateTitle(nearest.date, isAr),
            style: TextStyle(
              color: p.inkDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            nearest.time,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PatientPrimaryButton(
                  height: 46,
                  icon: Icons.check_rounded,
                  onPressed: () {
                    setState(() {
                      _selectedDate = nearest.date;
                      _selectedTime = nearest.time;
                      _weekStart = _startOfWeek(nearest.date);
                      _visibleMonth = DateTime(
                        nearest.date.year,
                        nearest.date.month,
                      );
                    });
                  },
                  label: isAr ? 'استخدم هذا الموعد' : 'Use this appointment',
                ),
              ),
            ],
          ),
          if (!_showCalendar) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _showCalendar = true;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: p.inkDark,
                side: BorderSide(color: p.stroke),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isAr ? 'اختيار موعد آخر' : 'Choose another time',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekSelector(CarelinkPalette p, bool isAr) {
    final dates = _visibleWeekDates;
    return Column(
      children: [
        Row(
          children: [
            _weekNavButton(
              p,
              icon: isAr
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              onTap: _weekStart.isAfter(_startOfWeek(_today))
                  ? () => setState(() {
                      _weekStart = _weekStart.subtract(const Duration(days: 7));
                    })
                  : null,
            ),
            Expanded(
              child: Text(
                '${_formatShortDate(dates.first, isAr)} - ${_formatShortDate(dates.last, isAr)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.inkDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            _weekNavButton(
              p,
              icon: isAr
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              onTap: () => setState(() {
                _weekStart = _weekStart.add(const Duration(days: 7));
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: dates.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == dates.length) {
                return _loadMoreDayButton(p, isAr);
              }
              return _datePill(p, isAr, dates[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _weekNavButton(
    CarelinkPalette p, {
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return PatientPressable(
      enabled: onTap != null,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: p.surfaceSoft.withValues(alpha: onTap == null ? 0.45 : 1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap == null
              ? p.inkMuted.withValues(alpha: 0.35)
              : AppColors.primary,
          size: 24,
        ),
      ),
    );
  }

  Widget _loadMoreDayButton(CarelinkPalette p, bool isAr) {
    return PatientPressable(
      onTap: () => setState(() => _visibleDays += 7),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke.withValues(alpha: 0.8)),
        ),
        child: Text(
          isAr ? 'المزيد' : 'More',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _datePill(CarelinkPalette p, bool isAr, DateTime date) {
    final available = _isDateAvailable(date);
    final selected =
        _selectedDate != null && DateUtils.isSameDay(_selectedDate, date);
    final dayLabel = _weekdayShort(date, isAr);

    return PatientPressable(
      enabled: available,
      onTap: available
          ? () => setState(() {
              _selectedDate = date;
              final times = _availableTimeSlots(date);
              _selectedTime = times.contains(_selectedTime)
                  ? _selectedTime
                  : null;
              _visibleMonth = DateTime(date.year, date.month);
            })
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : available
              ? p.surface
              : p.surfaceSoft.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : available
                ? p.stroke.withValues(alpha: 0.85)
                : p.stroke.withValues(alpha: 0.45),
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : available
                    ? AppColors.primary
                    : p.inkMuted.withValues(alpha: 0.42),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : available
                    ? p.inkDark
                    : p.inkMuted.withValues(alpha: 0.42),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('selected'),
                      color: Colors.white,
                      size: 14,
                    )
                  : SizedBox(
                      key: const ValueKey('spacer'),
                      height: 14,
                      child: Text(
                        _monthName(date.month, isAr, short: true),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: available
                              ? p.inkMuted
                              : p.inkMuted.withValues(alpha: 0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMonthCalendar(CarelinkPalette p, bool isAr) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month);
    final leading = first.weekday - DateTime.monday;
    final days = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _canShowPreviousMonth
                    ? () => setState(() {
                        _visibleMonth = DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month - 1,
                        );
                      })
                    : null,
                icon: Icon(
                  isAr
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
              ),
              Expanded(
                child: Text(
                  _monthTitle(_visibleMonth, isAr),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                }),
                icon: Icon(
                  isAr
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(7, (index) {
              final date = DateTime(2026, 6, DateTime.monday + index);
              return Expanded(
                child: Text(
                  _weekdayShort(date, isAr),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                day,
              );
              return _calendarCell(p, date);
            },
          ),
        ],
      ),
    );
  }

  bool get _canShowPreviousMonth {
    final current = DateTime(_today.year, _today.month);
    return _visibleMonth.isAfter(current);
  }

  Widget _calendarCell(CarelinkPalette p, DateTime date) {
    final available = _isDateAvailable(date);
    final selected =
        _selectedDate != null && DateUtils.isSameDay(_selectedDate, date);
    return PatientPressable(
      enabled: available,
      onTap: available
          ? () => setState(() {
              _selectedDate = date;
              final times = _availableTimeSlots(date);
              _selectedTime = times.contains(_selectedTime)
                  ? _selectedTime
                  : null;
              _weekStart = _startOfWeek(date);
            })
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : available
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : available
                ? AppColors.primary.withValues(alpha: 0.24)
                : p.stroke.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: selected
                ? Colors.white
                : available
                ? p.inkDark
                : p.inkMuted.withValues(alpha: 0.38),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChips(CarelinkPalette p) {
    if (_selectedDate == null) {
      return _softNotice(p, context.tr('booking.dateTime.chooseFirst'));
    }

    final times = _availableTimeSlots(_selectedDate!);
    if (times.isEmpty) {
      return _softNotice(p, context.tr('booking.dateTime.noTimes'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 430 ? 3 : 2;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: times.map((time) {
            final selected = _selectedTime == time;
            return SizedBox(
              width: itemWidth,
              child: PatientPressable(
                onTap: () => setState(() {
                  _showInlineConfirm = false;
                  _selectedTime = time;
                }),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.42),
                      width: 1.1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          time,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.primary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionTitle(
    CarelinkPalette p,
    String title,
    String subtitle, {
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(CarelinkPalette p, bool isAr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, color: p.inkMuted, size: 44),
          const SizedBox(height: 14),
          Text(
            isAr ? 'لا توجد مواعيد متاحة حالياً' : 'No appointments available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'مقدم الرعاية لا يملك أوقاتاً شاغرة خلال الفترة القادمة.'
                : 'This provider has no open times in the upcoming period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadAvailabilityAndBookings,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(isAr ? 'تحديث المواعيد' : 'Refresh availability'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadAvailabilityAndBookings,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('booking.tryAgain')),
          ),
        ],
      ),
    );
  }

  Widget _softNotice(CarelinkPalette p, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: p.inkMuted, fontSize: 13),
      ),
    );
  }

  List<String> _availableTimeSlots(DateTime date) {
    final slots =
        _providerSlots.where((slot) => _slotMatchesDate(slot, date)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final unique = <String>{};
    final times = <String>[];
    for (final slot in slots) {
      final time24 = _normalizeTime24(slot.startTime);
      if (time24 == null) continue;
      if (_slotDateTime(date, time24).isBefore(DateTime.now())) continue;
      if (_isSlotBooked(date, time24)) continue;
      if (unique.add(time24)) times.add(_formatTo12Hour(time24));
    }
    return times;
  }

  bool _isDateAvailable(DateTime date) {
    if (DateTime(date.year, date.month, date.day).isBefore(_today)) {
      return false;
    }
    return _availableTimeSlots(date).isNotEmpty;
  }

  bool _slotMatchesDate(AvailabilitySlot slot, DateTime date) {
    final exactDate = DateTime.tryParse(slot.date.trim());
    if (exactDate != null) {
      return DateUtils.isSameDay(exactDate, date);
    }
    final weekday = _weekdayName(date.weekday);
    return slot.day.toLowerCase().trim() == weekday;
  }

  bool _isSlotBooked(DateTime date, String time24) {
    for (final app in _existingAppointments) {
      final map = app is Map ? app : const {};
      final requestId = (map['appointmentId'] ?? map['requestId'] ?? '')
          .toString();
      if (requestId == widget.appointment.appointmentId) continue;

      final status = (map['status'] ?? '').toString().toLowerCase().trim();
      if (![
        'confirmed',
        'accepted',
        'approved',
        'scheduled',
        'in_progress',
      ].contains(status)) {
        continue;
      }

      final scheduled = DateTime.tryParse(
        (map['scheduledAt'] ?? '').toString().replaceFirst(' ', 'T'),
      );
      if (scheduled == null || !DateUtils.isSameDay(scheduled, date)) continue;
      if (_formatTime24(scheduled) == time24) return true;
    }
    return false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _weekdayName(int weekday) {
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

  String _weekdayShort(DateTime date, bool isAr) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ar = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return (isAr ? ar : en)[date.weekday - 1];
  }

  String _monthTitle(DateTime date, bool isAr) {
    return '${_monthName(date.month, isAr)} ${date.year}';
  }

  String _formatDateTitle(DateTime date, bool isAr) {
    final weekday = _weekdayShort(date, isAr);
    final month = _monthName(date.month, isAr);
    return isAr
        ? '$weekday، ${date.day} $month'
        : '$weekday, $month ${date.day}';
  }

  String _formatShortDate(DateTime date, bool isAr) {
    final month = _monthName(date.month, isAr, short: true);
    return isAr ? '${date.day} $month' : '$month ${date.day}';
  }

  String _monthName(int month, bool isAr, {bool short = false}) {
    const en = [
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
    const enShort = [
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
    const ar = [
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
    ];
    return isAr ? ar[month - 1] : (short ? enShort : en)[month - 1];
  }

  String? _normalizeTime24(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatTo12Hour(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = parts[1].padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$min $suffix';
  }

  String _format24Hour(String time12) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(time12.trim());
    if (match == null) return time12;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = match.group(2)!.padLeft(2, '0');
    final suffix = match.group(3)!.toUpperCase();
    hour = hour % 12;
    if (suffix == 'PM') hour += 12;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  String _formatTime24(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  DateTime _slotDateTime(DateTime date, String time24) {
    final parts = time24.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _formatIsoDate(DateTime date) =>
      date.toIso8601String().split('T').first;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }
}
