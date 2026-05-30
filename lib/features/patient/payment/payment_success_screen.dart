import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';

import 'patient_visa_payment_copy.dart';

/// Shown after a successful [PaymentService.createPayment] call.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({
    super.key,
    this.patientUserId,
    this.displayName,
    required this.providerName,
    required this.providerRole,
    this.serviceType,
    required this.appointmentDate,
    required this.appointmentTime,
    this.location,
    this.paymentMethod,
    this.paymentStatus,
    this.amount,
    this.currencyCode = 'JOD',
    this.visaLast4,
  });

  final String? patientUserId;
  final String? displayName;
  final String providerName;
  final String providerRole;
  final String? serviceType;
  final String? appointmentDate;
  final String? appointmentTime;
  final String? location;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? amount;
  final String currencyCode;
  final String? visaLast4;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              CarelinkBrandLogo(
                height: 40,
                fallbackTextColor: p.inkDark,
                forceDarkLogo: p.isDark,
              ),
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                paymentStatus?.toLowerCase() == 'paid'
                    ? 'Payment successful'
                    : 'Payment recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitleMessage(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if ((paymentStatus ?? '').toLowerCase() == 'paid') ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    PatientVisaPaymentCopy.paidLine(context, visaLast4),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: p.inkDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('payment.summary.appointment'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.inkDark,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _line(Icons.person_outline, providerName, p),
                    _line(Icons.badge_outlined, providerRole, p),
                    if ((serviceType ?? '').trim().isNotEmpty)
                      _line(Icons.medical_services_outlined, serviceType!.trim(), p),
                    if ((appointmentDate ?? '').toString().isNotEmpty)
                      _line(Icons.calendar_today_outlined, appointmentDate!, p),
                    if ((appointmentTime ?? '').toString().isNotEmpty)
                      _line(Icons.schedule, appointmentTime!, p),
                    if ((location ?? '').toString().trim().isNotEmpty)
                      _line(Icons.place_outlined, location!.trim(), p),
                    if (amount != null) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Text(
                            context.tr('payment.summary.amount'),
                            style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${amount!.toStringAsFixed(2)} $currencyCode',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((paymentStatus ?? '').isNotEmpty &&
                        (paymentStatus ?? '').toLowerCase() != 'paid')
                      _line(
                        Icons.flag_outlined,
                        'Status: ${paymentStatus!}',
                        p,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final uid = patientUserId;
                    if (uid != null && uid.isNotEmpty) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/patient-home',
                        (route) => false,
                        arguments: {
                          'userId': uid,
                          'displayName': displayName,
                        },
                      );
                    } else {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.tr('payment.backHome'),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleMessage(BuildContext context) {
    final s = (paymentStatus ?? '').toLowerCase();
    if (s == 'paid') {
      return context.tr('payment.demoNoCharge');
    }
    if (s == 'pending') {
      return context.tr('payment.pendingCheckout');
    }
    return context.tr('payment.savedBooking');
  }

  static Widget _line(IconData icon, String text, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: p.inkDark,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
