import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/payment/visa_demo_validation.dart';
import 'package:carelink/shared/services/payment_service.dart';

/// Realistic Visa demo checkout (matches backend test cards).
Future<Map<String, dynamic>?> showVisaDemoCheckoutSheet({
  required BuildContext context,
  required String appointmentId,
  required String patientUserId,
  required String providerUserId,
  required double amount,
  required String currencyCode,
  required String providerName,
  required String serviceName,
  String? billingEmailHint,
  PaymentService? paymentService,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return _VisaCheckoutBody(
        appointmentId: appointmentId,
        patientUserId: patientUserId,
        providerUserId: providerUserId,
        amount: amount,
        currencyCode: currencyCode,
        providerName: providerName,
        serviceName: serviceName,
        billingEmailHint: billingEmailHint,
        paymentService: paymentService ?? PaymentService(),
      );
    },
  );
}

class _VisaCheckoutBody extends StatefulWidget {
  const _VisaCheckoutBody({
    required this.appointmentId,
    required this.patientUserId,
    required this.providerUserId,
    required this.amount,
    required this.currencyCode,
    required this.providerName,
    required this.serviceName,
    this.billingEmailHint,
    required this.paymentService,
  });

  final String appointmentId;
  final String patientUserId;
  final String providerUserId;
  final double amount;
  final String currencyCode;
  final String providerName;
  final String serviceName;
  final String? billingEmailHint;
  final PaymentService paymentService;

  @override
  State<_VisaCheckoutBody> createState() => _VisaCheckoutBodyState();
}

class _VisaCheckoutBodyState extends State<_VisaCheckoutBody> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _email = TextEditingController();

  bool _busy = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    final hint = widget.billingEmailHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      _email.text = hint;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _fieldError = null;
    });
    try {
      VisaDemoRules.validateCardholder(_name.text);
      final pan = VisaDemoRules.digitsOnly(_number.text);
      if (pan.isEmpty) {
        throw FormatException('Card number is required.');
      }
      if (VisaDemoRules.classifyPan(pan) == null) {
        throw FormatException(VisaDemoRules.demoPanErrorMessage());
      }
      VisaDemoRules.validateExpiryMmYy(_expiry.text);
      VisaDemoRules.validateCvv(_cvv.text);
    } on FormatException catch (e) {
      setState(() => _fieldError = e.message);
      return;
    }

    setState(() => _busy = true);
    try {
      final out = await widget.paymentService.payWithVisaDemo(
        appointmentId: widget.appointmentId,
        patientUserId: widget.patientUserId,
        providerUserId: widget.providerUserId,
        amountHint: widget.amount,
        cardholderName: _name.text.trim(),
        cardNumber: _number.text,
        expiryMmYy: _expiry.text.trim(),
        cvv: _cvv.text.trim(),
        billingEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _fieldError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final p = CarelinkPalette.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.stroke,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.payment_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Pay with Visa',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: const Text('Visa • Demo'),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.amount.toStringAsFixed(2)} ${widget.currencyCode} · ${widget.providerName}',
              style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
            ),
            if (widget.serviceName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.serviceName.trim(),
                style: TextStyle(color: p.inkMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            _field(
              controller: _name,
              label: 'Cardholder name',
              keyboard: TextInputType.name,
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _number,
              label: 'Card number',
              keyboard: TextInputType.number,
              hint: '4242 4242 4242 4242',
              formatters: [VisaCardNumberFormatter()],
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _expiry,
                    label: 'Expiry MM/YY',
                    keyboard: TextInputType.datetime,
                    hint: '12/29',
                    formatters: [VisaExpiryMmYyFormatter()],
                    enabled: !_busy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _cvv,
                    label: 'CVV',
                    keyboard: TextInputType.number,
                    obscure: true,
                    maxLen: 4,
                    enabled: !_busy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              controller: _email,
              label: 'Billing email (optional)',
              keyboard: TextInputType.emailAddress,
              enabled: !_busy,
            ),
            if ((_fieldError ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _fieldError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing payment…',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      )
                    : const Text(
                        'Pay with Visa',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Demo only: successful 4242…4242 • failed 4000…0002 • declined 4000…9995',
              style: TextStyle(fontSize: 11, color: p.inkMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboard,
    String? hint,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    int? maxLen,
    required bool enabled,
  }) {
    final p = CarelinkPalette.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      inputFormatters: formatters,
      maxLength: maxLen,
      enabled: enabled,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
