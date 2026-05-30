import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/visa_demo_checkout_sheet.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';
import 'package:carelink/shared/widgets/secure_payment_notice.dart';
import 'patient_visa_payment_copy.dart';
import 'payment_success_screen.dart';

/// After booking: pay with **Visa** (demo test cards) via CareLink ledger.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.providerId,
    required this.providerName,
    required this.providerRole,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.amount,
    this.serviceType,
    this.location,
    this.currencyCode = 'JOD',
  });

  final String appointmentId;
  final String patientId;
  final String providerId;
  final String providerName;
  final String providerRole;
  final String appointmentDate;
  final String appointmentTime;
  final double amount;
  final String? serviceType;
  final String? location;
  final String currencyCode;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _opening = false;

  Future<void> _openVisaCheckout() async {
    if (widget.amount <= 0) {
      _toast(context.tr('payment.amountPositive'));
      return;
    }
    setState(() => _opening = true);
    try {
      final result = await showVisaDemoCheckoutSheet(
        context: context,
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientId,
        providerUserId: widget.providerId,
        amount: widget.amount,
        currencyCode: widget.currencyCode,
        providerName: widget.providerName,
        serviceName: widget.serviceType ?? 'Care visit',
      );
      if (!mounted || result == null) return;

      final status =
          (result['paymentStatus'] ?? result['status'] ?? '').toString();
      if (status.toLowerCase() != 'paid') {
        _toast(context.tr('payment.notCompleted'));
        return;
      }

      final rawAmt = result['amount'];
      final paidAmount = rawAmt is num
          ? rawAmt.toDouble()
          : double.tryParse(rawAmt?.toString() ?? '') ?? widget.amount;
      final last4 = (result['cardLast4'] ?? '').toString().trim();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            patientUserId: widget.patientId,
            providerName: widget.providerName,
            providerRole: widget.providerRole,
            serviceType: widget.serviceType,
            appointmentDate: widget.appointmentDate,
            appointmentTime: widget.appointmentTime,
            location: widget.location,
            paymentMethod: 'visa_card',
            paymentStatus: status,
            amount: paidAmount,
            currencyCode: widget.currencyCode,
            visaLast4: last4.isNotEmpty ? last4 : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _toast(msg.isEmpty ? context.tr('payment.genericError') : msg);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _toast(String message) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title: CarelinkAppBarTitle.forPatient(
          context,
          context.tr('patient.title.payment'),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              CarelinkBrandLogo(
                height: 36,
                fallbackTextColor: p.inkDark,
                forceDarkLogo: p.isDark,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('payment.completeTitle'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                PatientVisaPaymentCopy.unpaidPayWithVisa(context),
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('payment.completeSubtitleDemo'),
                style: TextStyle(color: p.inkMuted, fontSize: 13.5, height: 1.35),
              ),
              const SizedBox(height: 20),
              _SummaryCard(
                palette: p,
                providerName: widget.providerName,
                providerRole: widget.providerRole,
                date: widget.appointmentDate,
                time: widget.appointmentTime,
                amount: widget.amount,
                currencyCode: widget.currencyCode,
                serviceType: widget.serviceType,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('payment.visaCheckout'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: p.inkDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('payment.visaOnlyNote'),
                style: TextStyle(fontSize: 13, color: p.inkMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              const SecurePaymentNotice(),
            ],
          ),
          if (_opening)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: AppColors.primary),
                        const SizedBox(height: 14),
                        Text(context.tr('payment.openingCheckout')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.amount.toStringAsFixed(2)} ${widget.currencyCode}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _opening ? null : _openVisaCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
            child: Text(
              context.tr('payment.payWithVisa'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.palette,
    required this.providerName,
    required this.providerRole,
    required this.date,
    required this.time,
    required this.amount,
    required this.currencyCode,
    this.serviceType,
  });

  final CarelinkPalette palette;
  final String providerName;
  final String providerRole;
  final String date;
  final String time;
  final double amount;
  final String currencyCode;
  final String? serviceType;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: p.inkDark,
                      ),
                    ),
                    Text(
                      providerRole,
                      style: TextStyle(color: p.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((serviceType ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              serviceType!.trim(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const Divider(height: 22),
          _row('Date', date, p),
          _row('Time', time, p),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${amount.toStringAsFixed(2)} $currencyCode',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
