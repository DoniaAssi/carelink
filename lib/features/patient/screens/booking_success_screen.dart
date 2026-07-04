import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_localizations.dart';
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

    return Directionality(
      textDirection: context.l10n.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: PatientScaffold(
        backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF0FAF7),
        appBar: PatientAppBar(
          title: context.tr('payment.title'),
          showBack: true,
          showLanguage: true,
          showTheme: true,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              offset: _visible ? Offset.zero : const Offset(0, 0.04),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 380),
                opacity: _visible ? 1 : 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: p.isDark ? p.surface : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: p.isDark ? p.stroke : const Color(0xFFE5EEEC),
                    ),
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
                      const SizedBox(height: 18),
                      Text(
                        context.tr('booking.success.title'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.isDark ? p.inkDark : const Color(0xFF0F172A),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('booking.success.subtitle'),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.isDark
                              ? p.inkMuted
                              : const Color(0xFF64748B),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _StatusBadge(
                        label: context.tr('booking.success.pendingProvider'),
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
                        amountPaid:
                            _verifiedAmountPaid ?? widget.amountPaid ?? 0,
                      ),
                      const SizedBox(height: 16),
                      _BookingTimeline(palette: p),
                      const SizedBox(height: 22),
                      _TrackBookingButton(onPressed: () => _openTab(1)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () => _openTab(0),
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: Text(context.tr('booking.success.backHome')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF0F766E),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
    return text.isEmpty ? context.tr('common.notAvailable') : text;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final isAr = context.l10n.isArabic;
    final suffix = date.hour >= 12 ? (isAr ? 'م' : 'PM') : (isAr ? 'ص' : 'AM');
    return '$hour:$minute $suffix';
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

class _TrackBookingButton extends StatelessWidget {
  const _TrackBookingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('booking.success.followRequest'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.isDark ? palette.stroke : const Color(0xFFE5EEEC),
        ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryRow(
                    palette: palette,
                    icon: Icons.person_outline_rounded,
                    label: context.tr('booking.success.provider'),
                    value: providerName,
                    emphasized: true,
                  ),
                ),
                VerticalDivider(
                  width: 22,
                  thickness: 1,
                  color: palette.stroke.withValues(alpha: 0.7),
                ),
                Expanded(
                  child: _SummaryRow(
                    palette: palette,
                    icon: Icons.medical_services_outlined,
                    label: context.tr('booking.success.service'),
                    value: serviceType,
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: palette.stroke.withValues(alpha: 0.7),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryRow(
                    palette: palette,
                    icon: Icons.calendar_today_outlined,
                    label: context.tr('booking.success.date'),
                    value: appointmentDate,
                    emphasized: true,
                  ),
                ),
                VerticalDivider(
                  width: 22,
                  thickness: 1,
                  color: palette.stroke.withValues(alpha: 0.7),
                ),
                Expanded(
                  child: _SummaryRow(
                    palette: palette,
                    icon: Icons.schedule_rounded,
                    label: context.tr('booking.success.time'),
                    value: appointmentTime,
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: palette.stroke.withValues(alpha: 0.7),
            ),
          ),
          _SummaryRow(
            palette: palette,
            icon: Icons.payments_outlined,
            label: context.tr('booking.success.amountPaid'),
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
    final steps = [
      (
        title: context.tr('booking.success.timelinePaid'),
        description: context.tr('booking.success.timelinePaidDescription'),
        completed: true,
      ),
      (
        title: context.tr('booking.success.timelineSent'),
        description: context.tr('booking.success.timelineSentDescription'),
        completed: true,
      ),
      (
        title: context.tr('booking.success.timelineWaiting'),
        description: context.tr('booking.success.timelineWaitingDescription'),
        completed: false,
      ),
      (
        title: context.tr('booking.success.timelineConfirmed'),
        description: context.tr('booking.success.timelineConfirmedDescription'),
        completed: false,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surfaceSoft : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.isDark ? palette.stroke : const Color(0xFFE5EEEC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: palette.isDark ? 0.14 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < steps.length; index++)
            _TimelineStep(
              palette: palette,
              title: steps[index].title,
              description: steps[index].description,
              completed: steps[index].completed,
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
    required this.title,
    required this.description,
    required this.completed,
    required this.showLine,
  });

  final CarelinkPalette palette;
  final String title;
  final String description;
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.inkDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
