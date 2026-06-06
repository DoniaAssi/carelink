import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/widgets/secure_payment_notice.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'payment_success_screen.dart';

/// Checkout step after a booking is created. [appointmentId] is the backend UUID.
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
    this.servicePrice = 0,
    this.discount = 0,
    this.isRemote = false,
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
  final double servicePrice;
  final double discount;
  final bool isRemote;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _submitting = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final cardText = _cardController.text.trim();
      final last4 = cardText.length >= 4
          ? cardText.substring(cardText.length - 4)
          : 'XXXX';
      final displayMethod = 'Visa ****$last4';

      final result = await _paymentService.createPayment(
        appointmentId: widget.appointmentId,
        patientId: widget.patientId,
        providerId: widget.providerId,
        amount: widget.amount,
        method: 'mock_card',
      );

      if (result['success'] != true) {
        throw Exception(
          result['error']?.toString() ?? 'Payment was not accepted',
        );
      }

      final status = (result['paymentStatus'] ?? '').toString();
      final rawAmt = result['amount'];
      final paidAmount = rawAmt is num
          ? rawAmt.toDouble()
          : double.tryParse(rawAmt?.toString() ?? '') ?? widget.amount;

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
            paymentMethod: displayMethod,
            paymentStatus: status,
            amount: paidAmount,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _toast(msg.isEmpty ? 'Something went wrong.' : msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
      appBar: PatientAppBar(
        title: context.tr('payment.title'),
        showLanguage: true,
        showTheme: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text(
                context.tr('payment.completePayment'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('payment.enterCardInfo'),
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              _SummaryCard(
                palette: p,
                providerName: widget.providerName,
                providerRole: widget.providerRole,
                date: widget.appointmentDate,
                time: widget.appointmentTime,
                amount: widget.amount,
                serviceType: widget.serviceType,
                servicePrice: widget.servicePrice,
                discount: widget.discount,
                isRemote: widget.isRemote,
              ),
              const SizedBox(height: 20),
              _DemoCardNotice(palette: p),
              const SizedBox(height: 16),
              Text(
                context.tr('payment.cardDetails'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('payment.cardHolderName'),
                        helperText: context.tr('payment.demoName'),
                      ),
                      validator: (v) => v!.trim().isEmpty
                          ? context.tr('payment.required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        labelText: context.tr('payment.cardNumber'),
                        helperText: '4242 4242 4242 4242',
                      ),
                      validator: (v) => v!.trim().length != 16
                          ? context.tr('payment.invalidCard')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: context.tr('payment.expiry'),
                              helperText: '12/30',
                            ),
                            validator: (v) =>
                                !RegExp(
                                  r'^(0[1-9]|1[0-2])\/\d{2}$',
                                ).hasMatch(v?.trim() ?? '')
                                ? context.tr('payment.invalidExpiry')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('payment.cvv'),
                              helperText: '123',
                            ),
                            validator: (v) => v!.trim().length != 3
                                ? context.tr('payment.invalidCvv')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SecurePaymentNotice(),
            ],
          ),
          if (_submitting)
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
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(context.tr('payment.processing')),
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
          child: PatientPrimaryButton(
            onPressed: _submitting ? null : _pay,
            isLoading: _submitting,
            icon: Icons.lock_outline_rounded,
            label: context.tr(
              'payment.pay',
              args: {'amount': widget.amount.toStringAsFixed(2)},
            ),
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
    this.serviceType,
    this.servicePrice = 0,
    this.discount = 0,
    this.isRemote = false,
  });

  final CarelinkPalette palette;
  final String providerName;
  final String providerRole;
  final String date;
  final String time;
  final double amount;
  final String? serviceType;
  final double servicePrice;
  final double discount;
  final bool isRemote;

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
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
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
          _row(context.tr('payment.date'), date, p),
          _row(context.tr('payment.time'), time, p),
          const SizedBox(height: 6),
          if (servicePrice > 0) ...[
            _pricingRow(context.tr('payment.servicePrice'), servicePrice, p),
            if (discount > 0)
              _pricingRow(
                context.tr('payment.remoteDiscount'),
                -discount,
                p,
                isNegative: true,
              ),
          ],
          const Divider(height: 16),
          Row(
            children: [
              Text(
                context.tr('payment.totalAmount'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${amount.toStringAsFixed(2)} ${context.tr('payment.currencySymbol')}',
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
              style: TextStyle(
                color: p.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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

  static Widget _pricingRow(
    String label,
    double value,
    CarelinkPalette p, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontSize: 13),
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${value.abs().toStringAsFixed(2)} ILS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isNegative ? AppColors.primary : p.inkDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCardNotice extends StatelessWidget {
  const _DemoCardNotice({required this.palette});

  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: palette.isDark ? 0.16 : 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.credit_card_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('payment.demoCardDetails'),
              style: TextStyle(
                color: palette.inkDark,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
