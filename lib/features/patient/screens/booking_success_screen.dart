import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({
    super.key,
    required this.patientUserId,
    this.appointmentId,
    this.providerName,
    this.serviceType,
    this.appointmentDate,
    this.appointmentTime,
    this.amountPaid,
  });

  final String patientUserId;
  final String? appointmentId;
  final String? providerName;
  final String? serviceType;
  final String? appointmentDate;
  final String? appointmentTime;
  final double? amountPaid;

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  bool _visible = false;
  String? _verifiedProviderName;
  String? _verifiedServiceType;
  String? _verifiedAppointmentDate;
  String? _verifiedAppointmentTime;
  double? _verifiedAmountPaid;

  @override
  void initState() {
    super.initState();
    _loadVerifiedSummary();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Future<void> _loadVerifiedSummary() async {
    final appointmentId = widget.appointmentId?.trim() ?? '';
    if (appointmentId.isEmpty) return;

    final api = ApiService();
    try {
      final results = await Future.wait([
        api.getAppointmentDetails(appointmentId),
        api.getAppointmentPayment(
          appointmentId: appointmentId,
          patientUserId: widget.patientUserId,
        ),
      ]);
      final appointment = AppointmentModel.fromJson(results[0]);
      final payment = results[1];
      final scheduledAt = appointment.scheduledAt;
      final amount = double.tryParse((payment['amount'] ?? '').toString());

      if (!mounted) return;
      setState(() {
        if (appointment.providerName.trim().isNotEmpty) {
          _verifiedProviderName = appointment.providerName.trim();
        }
        final verifiedService = (results[0]['serviceType'] ?? '')
            .toString()
            .trim();
        if (verifiedService.isNotEmpty) {
          _verifiedServiceType = verifiedService;
        }
        if (scheduledAt != null) {
          _verifiedAppointmentDate = _formatDate(scheduledAt);
          _verifiedAppointmentTime = _formatTime(scheduledAt);
        }
        if (amount != null) _verifiedAmountPaid = amount;
      });
    } catch (_) {
      // The reviewed booking data remains visible if refreshing fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final isArabic = context.l10n.isArabic;

    return Scaffold(
      backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF0FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            offset: _visible ? Offset.zero : const Offset(0, 0.04),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 380),
              opacity: _visible ? 1 : 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: p.stroke),
                  boxShadow: [
                    BoxShadow(
                      color: p.cardShadowColor(0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _SuccessMark(visible: _visible),
                    const SizedBox(height: 22),
                    Text(
                      isArabic ? 'تم إرسال طلب الحجز' : 'Booking request sent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.inkDark,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isArabic
                          ? 'تم الدفع بنجاح وتم إرسال طلبك إلى مقدم الرعاية.'
                          : 'Payment succeeded and your request was sent to the care provider.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _StatusBadge(
                      label: isArabic
                          ? 'بانتظار موافقة مقدم الرعاية'
                          : 'Waiting for provider approval',
                      palette: p,
                    ),
                    const SizedBox(height: 22),
                    _BookingSummary(
                      palette: p,
                      providerName: _displayText(
                        _verifiedProviderName ?? widget.providerName,
                      ),
                      serviceType: _displayText(
                        _verifiedServiceType ?? widget.serviceType,
                      ),
                      appointmentDate: _displayText(
                        _verifiedAppointmentDate ?? widget.appointmentDate,
                      ),
                      appointmentTime: _displayText(
                        _verifiedAppointmentTime ?? widget.appointmentTime,
                      ),
                      amountPaid: _verifiedAmountPaid ?? widget.amountPaid ?? 0,
                    ),
                    const SizedBox(height: 16),
                    _BookingTimeline(palette: p),
                    const SizedBox(height: 24),
                    PatientPrimaryButton(
                      height: 56,
                      onPressed: () => _openTab(1),
                      label: isArabic
                          ? 'عرض حجوزاتي'
                          : context.tr('booking.success.followRequest'),
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _openTab(0),
                        icon: const Icon(Icons.home_outlined, size: 20),
                        label: Text(
                          isArabic
                              ? 'العودة للرئيسية'
                              : context.tr('booking.success.backHome'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTab(int tab) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => PatientNavigationShell(
          userId: widget.patientUserId,
          initialTab: tab,
        ),
      ),
      (route) => false,
    );
  }

  String _displayText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? context.tr('booking.success.notAvailable') : text;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      scale: visible ? 1 : 0.55,
      child: SizedBox(
        width: 150,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 14,
              left: 24,
              child: _CelebrationDot(size: 7),
            ),
            const Positioned(
              top: 32,
              right: 18,
              child: _CelebrationDot(size: 8),
            ),
            const Positioned(
              left: 14,
              bottom: 42,
              child: _CelebrationDot(size: 5),
            ),
            const Positioned(
              right: 30,
              bottom: 22,
              child: _CelebrationDot(size: 6),
            ),
            Positioned(
              child: Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF22C55E), Color(0xFF059669)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationDot extends StatelessWidget {
  const _CelebrationDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.72),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.palette});

  final String label;
  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: palette.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.warning,
            size: 17,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB96C05),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.palette,
    required this.providerName,
    required this.serviceType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.amountPaid,
  });

  final CarelinkPalette palette;
  final String providerName;
  final String serviceType;
  final String appointmentDate;
  final String appointmentTime;
  final double amountPaid;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.stroke.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: palette.isDark ? 0.16 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(
            palette: palette,
            icon: Icons.medical_services_outlined,
            label: isArabic ? 'مقدم الرعاية' : 'Provider',
            value: providerName,
            emphasized: true,
          ),
          const SizedBox(height: 11),
          _SummaryRow(
            palette: palette,
            icon: Icons.local_hospital_outlined,
            label: isArabic ? 'الخدمة' : 'Service',
            value: serviceType,
          ),
          const SizedBox(height: 11),
          _SummaryRow(
            palette: palette,
            icon: Icons.calendar_today_outlined,
            label: isArabic ? 'التاريخ' : 'Date',
            value: appointmentDate,
          ),
          const SizedBox(height: 11),
          _SummaryRow(
            palette: palette,
            icon: Icons.schedule_rounded,
            label: isArabic ? 'الوقت' : 'Time',
            value: appointmentTime,
          ),
          const SizedBox(height: 11),
          _SummaryRow(
            palette: palette,
            icon: Icons.payments_outlined,
            label: isArabic ? 'المبلغ المدفوع' : 'Amount paid',
            value: '${amountPaid.toStringAsFixed(2)} ILS',
            valueColor: AppColors.primary,
            textDirection: TextDirection.ltr,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.textDirection,
    this.emphasized = false,
  });

  final CarelinkPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final TextDirection? textDirection;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(
              alpha: palette.isDark ? 0.16 : 0.09,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: textDirection,
                style: TextStyle(
                  color: valueColor ?? palette.inkDark,
                  fontSize: emphasized ? 14.5 : 13.5,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingTimeline extends StatelessWidget {
  const _BookingTimeline({required this.palette});

  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final steps = [
      (
        isArabic
            ? 'تم الدفع بنجاح'
            : context.tr('booking.success.timelinePaid'),
        true,
      ),
      (
        isArabic
            ? 'تم إرسال الطلب'
            : context.tr('booking.success.timelineSent'),
        true,
      ),
      (
        isArabic
            ? 'بانتظار موافقة مقدم الرعاية'
            : context.tr('booking.success.timelineWaiting'),
        false,
      ),
      (
        isArabic
            ? 'تم تأكيد الموعد'
            : context.tr('booking.success.timelineConfirmed'),
        false,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: palette.isDark
            ? palette.surfaceSoft
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.stroke.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < steps.length; index++)
            _TimelineStep(
              palette: palette,
              label: steps[index].$1,
              completed: steps[index].$2,
              showLine: index < steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.palette,
    required this.label,
    required this.completed,
    required this.showLine,
  });

  final CarelinkPalette palette;
  final String label;
  final bool completed;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.primary : palette.inkMuted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: completed ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: completed
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : palette.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Text(
                label,
                style: TextStyle(
                  color: completed ? palette.inkDark : palette.inkMuted,
                  fontSize: 12.5,
                  fontWeight: completed ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
