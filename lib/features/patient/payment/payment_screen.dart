import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/models/booking_request_model.dart';

/// Checkout for an existing booking flow.
///
/// [request] is the complete booking data. Successful
/// payment creates the booking as `pending`.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.request});

  final BookingRequestModel request;

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
  void initState() {
    super.initState();
  }

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
      // 1. Simulate mock card payment success locally
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // 2. Create the real booking now that payment is approved
      final api = ApiService();
      final booking = await api.createBooking(
        patientId: widget.request.patientId,
        providerId: widget.request.providerId,
        date: widget.request.appointmentDate,
        time: widget.request.appointmentTime,
        notes: widget.request.composedNotes,
        serviceType: widget.request.serviceType,
        appointmentType: widget.request.appointmentType,
        visitLatitude: widget.request.visitLatitude,
        visitLongitude: widget.request.visitLongitude,
        visitAddress: widget.request.visitAddress,
        locationNote: widget.request.locationNote,
        symptoms: widget.request.symptoms,
        isUrgent: widget.request.isUrgent,
        urgencyLevel: widget.request.isUrgent ? 'urgent' : 'routine',
        additionalNotes: widget.request.additionalNotes,
        paymentMethod: 'mock_card',
        paymentStatus: 'paid',
        status: 'pending',
      );

      final appointmentId = (booking['appointmentId'] ?? '').toString();
      if (appointmentId.isEmpty) {
        throw Exception('Booking created but appointment id is missing');
      }

      // 3. Record the payment in the ledger
      final result = await _paymentService.createPayment(
        appointmentId: appointmentId,
        patientId: widget.request.patientId,
        providerId: widget.request.providerId,
        amount: widget.request.totalAmount,
        method: 'mock_card',
      );

      if (result['success'] != true && result['exists'] != true) {
        throw Exception(
          result['error']?.toString() ?? 'Ledger error, but booking created',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, {'success': true, 'appointmentId': appointmentId});
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
    final isArabic = context.l10n.isArabic;

    return Scaffold(
      backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF2FAF8),
      appBar: PatientAppBar(
        title: context.tr('payment.title'),
        showLanguage: true,
        showTheme: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
            children: [
              _AmountSummaryCard(
                palette: p,
                providerName: widget.request.providerName,
                serviceName: (widget.request.serviceType).trim().isNotEmpty
                    ? widget.request.serviceType.trim()
                    : widget.request.providerRole,
                amount: widget.request.totalAmount,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _nameController,
                  _cardController,
                  _expiryController,
                ]),
                builder: (context, _) => _CreditCardPreview(
                  cardNumber: _cardController.text,
                  cardHolder: _nameController.text,
                  expiryDate: _expiryController.text,
                ),
              ),
              const SizedBox(height: 18),
              _CardForm(
                palette: p,
                formKey: _formKey,
                isArabic: isArabic,
                nameController: _nameController,
                cardController: _cardController,
                expiryController: _expiryController,
                cvvController: _cvvController,
              ),
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
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.07),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CompactSecurityNote(),
              const SizedBox(height: 10),
              PatientPrimaryButton(
                height: 56,
                onPressed: _submitting ? null : _pay,
                isLoading: _submitting,
                icon: Icons.lock_rounded,
                label: isArabic ? 'تأكيد الدفع' : 'Confirm Payment',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountSummaryCard extends StatelessWidget {
  const _AmountSummaryCard({
    required this.palette,
    required this.providerName,
    required this.serviceName,
    required this.amount,
  });

  final CarelinkPalette palette;
  final String providerName;
  final String serviceName;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.stroke.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.18 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: palette.isDark ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${amount.toStringAsFixed(2)} ${context.tr('payment.currencySymbol')}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.palette});

  final String title;
  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: palette.inkDark,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CardForm extends StatelessWidget {
  const _CardForm({
    required this.palette,
    required this.formKey,
    required this.isArabic,
    required this.nameController,
    required this.cardController,
    required this.expiryController,
    required this.cvvController,
  });

  final CarelinkPalette palette;
  final GlobalKey<FormState> formKey;
  final bool isArabic;
  final TextEditingController nameController;
  final TextEditingController cardController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.stroke.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.18 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: context.tr('payment.cardDetails'),
              palette: palette,
            ),
            const SizedBox(height: 18),
            _LabeledField(
              palette: palette,
              label: context.tr('payment.cardHolderName'),
              controller: nameController,
              hint: context.tr('payment.cardHolderHint'),
              icon: Icons.person_outline_rounded,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value!.trim().isEmpty ? context.tr('payment.required') : null,
            ),
            const SizedBox(height: 16),
            _LabeledField(
              palette: palette,
              label: context.tr('payment.cardNumber'),
              controller: cardController,
              hint: '0000 0000 0000 0000',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CardNumberInputFormatter(),
                LengthLimitingTextInputFormatter(19),
              ],
              validator: (value) =>
                  value!.replaceAll(' ', '').trim().length != 16
                  ? context.tr('payment.invalidCard')
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    palette: palette,
                    label: context.tr('payment.expiry'),
                    controller: expiryController,
                    hint: 'MM/YY',
                    icon: Icons.calendar_month_outlined,
                    keyboardType: TextInputType.datetime,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [LengthLimitingTextInputFormatter(5)],
                    validator: (value) =>
                        !RegExp(
                          r'^(0[1-9]|1[0-2])\/\d{2}$',
                        ).hasMatch(value?.trim() ?? '')
                        ? context.tr('payment.invalidExpiry')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    palette: palette,
                    label: context.tr('payment.cvv'),
                    controller: cvvController,
                    hint: 'CVV',
                    icon: Icons.lock_outline_rounded,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (value) => value!.trim().length != 3
                        ? context.tr('payment.invalidCvv')
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.palette,
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textDirection,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
  });

  final CarelinkPalette palette;
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.inkDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: textDirection,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: palette.inkMuted.withValues(alpha: 0.65),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: palette.isDark
                ? palette.surfaceSoft
                : const Color(0xFFF7FAF9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: _border(palette.stroke),
            enabledBorder: _border(palette.stroke),
            focusedBorder: _border(AppColors.primary, width: 1.6),
            errorBorder: _border(Colors.red.shade400),
            focusedErrorBorder: _border(Colors.red.shade500, width: 1.5),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CreditCardPreview extends StatelessWidget {
  const _CreditCardPreview({
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
  });

  final String cardNumber;
  final String cardHolder;
  final String expiryDate;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final number = cardNumber.trim().isEmpty
        ? '•••• •••• •••• ••••'
        : cardNumber.trim();
    final holder = cardHolder.trim().isEmpty
        ? 'CARD HOLDER'
        : cardHolder.trim().toUpperCase();
    final expiry = expiryDate.trim().isEmpty ? 'MM/YY' : expiryDate.trim();
    final cleanNumber = cardNumber.replaceAll(' ', '');
    final brand = cleanNumber.startsWith('5') ? 'Mastercard' : 'VISA';

    return AspectRatio(
      aspectRatio: 1.586,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: p.isDark ? 0.28 : 0.22,
                ),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF17B7A3),
                          Color(0xFF0B8275),
                          Color(0xFF07564F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: -54,
                  end: -28,
                  child: _CardCircle(size: 142, alpha: 0.13),
                ),
                PositionedDirectional(
                  bottom: -66,
                  start: -36,
                  child: _CardCircle(size: 166, alpha: 0.10),
                ),
                PositionedDirectional(
                  top: 38,
                  end: 52,
                  child: _CardCircle(size: 34, alpha: 0.10),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CareLink',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              brand,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.96),
                                fontWeight: FontWeight.w900,
                                fontSize: brand == 'VISA' ? 22 : 17,
                                fontStyle: brand == 'VISA'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _CardChip(),
                        const Spacer(),
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              number,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _CardMetaBlock(
                              label: 'EXPIRY',
                              value: expiry,
                              alignEnd: false,
                            ),
                            const Spacer(),
                            Flexible(
                              flex: 2,
                              child: _CardMetaBlock(
                                label: 'CARD HOLDER',
                                value: holder,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFE7D79A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 1,
              height: 28,
              color: const Color(0xFF8A7A3C).withValues(alpha: 0.45),
            ),
          ),
          Center(
            child: Container(
              width: 38,
              height: 1,
              color: const Color(0xFF8A7A3C).withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCircle extends StatelessWidget {
  const _CardCircle({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: alpha)),
        color: Colors.white.withValues(alpha: alpha * 0.45),
      ),
    );
  }
}

class _CardMetaBlock extends StatelessWidget {
  const _CardMetaBlock({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactSecurityNote extends StatelessWidget {
  const _CompactSecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.primary,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          context.l10n.isArabic
              ? 'الدفع آمن ومشفر'
              : 'Payment is safe and encrypted',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
