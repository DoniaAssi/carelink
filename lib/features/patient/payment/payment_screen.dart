import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      // 1. Simulate mock card payment success locally
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // 2. Create the booking, or reuse the matching existing booking.
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
        paymentMethod: 'card',
        paymentStatus: 'paid',
        status: 'pending_provider_approval',
        recommendationId: widget.request.recommendationId,
      );

      final appointmentId = (booking['appointmentId'] ?? '').toString();
      if (appointmentId.isEmpty) {
        throw Exception('Booking created but appointment id is missing');
      }
      final recommendationId = widget.request.recommendationId?.trim() ?? '';
      if (recommendationId.isNotEmpty) {
        api
            .markRecommendationBookingCreated(
              recommendationId: recommendationId,
              relatedBookingId: appointmentId,
            )
            .catchError((error) {
              debugPrint(
                '[AIRecommendations] failed to mark booking created: $error',
              );
            });
      }

      // 3. Record the payment in the ledger
      final result = await _paymentService.createPayment(
        appointmentId: appointmentId,
        patientId: widget.request.patientId,
        providerId: widget.request.providerId,
        amount: widget.request.totalAmount,
        method: 'card',
      );
      debugPrint('[BookingDebug] payment ledger result: $result');

      if (result['success'] != true && result['exists'] != true) {
        throw Exception(
          result['error']?.toString() ?? 'Ledger error, but booking created',
        );
      }

      if (!mounted) return;
      _toast(
        context.l10n.isArabic
            ? 'تم الدفع بنجاح'
            : 'Payment completed successfully',
      );
      Navigator.pop(context, {'success': true, 'appointmentId': appointmentId});
    } catch (e) {
      if (!mounted) return;
      _toast(context.l10n.userMessage(e));
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

    final baseTheme = Theme.of(context);
    final paymentTheme = isArabic
        ? baseTheme.copyWith(
            textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
            primaryTextTheme: GoogleFonts.cairoTextTheme(
              baseTheme.primaryTextTheme,
            ),
          )
        : baseTheme;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Theme(
        data: paymentTheme,
        child: PatientScaffold(
          backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF2FAF8),
          appBar: PatientAppBar(
            title: isArabic ? 'الدفع' : context.tr('payment.title'),
            showLanguage: true,
            showTheme: true,
          ),
          body: Stack(
            children: [
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AmountSummaryCard(
                        palette: p,
                        providerName: widget.request.providerName,
                        serviceName:
                            widget.request.serviceType.trim().isNotEmpty
                            ? widget.request.serviceType.trim()
                            : widget.request.providerRole,
                        amount: widget.request.totalAmount,
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 24),
                      _CardForm(
                        palette: p,
                        formKey: _formKey,
                        isArabic: isArabic,
                        nameController: _nameController,
                        cardController: _cardController,
                        expiryController: _expiryController,
                        cvvController: _cvvController,
                        submitting: _submitting,
                        onPay: _pay,
                      ),
                    ],
                  ),
                ),
              ),
              if (_submitting)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
    final isArabic = context.l10n.isArabic;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.isDark ? palette.stroke : const Color(0xFFE5EEEC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: palette.isDark ? 0.18 : 0.055,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF0F766E,
                  ).withValues(alpha: palette.isDark ? 0.20 : 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xFF0F766E),
                  size: 24,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: palette.stroke.withValues(alpha: 0.75)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? 'المبلغ الإجمالي' : 'Total amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'ILS ${amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    required this.submitting,
    required this.onPay,
  });

  final CarelinkPalette palette;
  final GlobalKey<FormState> formKey;
  final bool isArabic;
  final TextEditingController nameController;
  final TextEditingController cardController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final bool submitting;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: palette.isDark ? palette.stroke : const Color(0xFFE5EEEC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: palette.isDark ? 0.18 : 0.055,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: isArabic
                  ? 'بيانات البطاقة'
                  : context.tr('payment.cardDetails'),
              palette: palette,
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'أدخل بيانات البطاقة لإتمام عملية الدفع بأمان.'
                  : 'Enter your card details to complete payment securely.',
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _LabeledField(
              palette: palette,
              label: isArabic
                  ? 'اسم حامل البطاقة'
                  : context.tr('payment.cardHolderName'),
              controller: nameController,
              hint: context.tr('payment.cardHolderHint'),
              icon: Icons.person_outline_rounded,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value!.trim().isEmpty ? context.tr('payment.required') : null,
            ),
            const SizedBox(height: 18),
            _LabeledField(
              palette: palette,
              label: isArabic
                  ? 'رقم البطاقة'
                  : context.tr('payment.cardNumber'),
              controller: cardController,
              hint: '0000 0000 0000 0000',
              icon: Icons.credit_card_rounded,
              suffix: const Text(
                'VISA',
                style: TextStyle(
                  color: Color(0xFF1A2C9B),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
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
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    palette: palette,
                    label: isArabic
                        ? 'تاريخ الانتهاء'
                        : context.tr('payment.expiry'),
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
            const SizedBox(height: 20),
            const _CompactSecurityNote(),
            const SizedBox(height: 16),
            _GradientPaymentButton(
              onPressed: submitting ? null : onPay,
              isLoading: submitting,
              label: isArabic ? 'تأكيد الدفع' : 'Confirm Payment',
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientPaymentButton extends StatelessWidget {
  const _GradientPaymentButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
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
    this.suffix,
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
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.inkDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.35,
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
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF0F766E), size: 20),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(end: 14),
                    child: Center(widthFactor: 1, child: suffix),
                  ),
            filled: true,
            fillColor: palette.isDark
                ? palette.surfaceSoft
                : const Color(0xFFF8FAFA),
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
      borderRadius: BorderRadius.circular(16),
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
    final isArabic = context.l10n.isArabic;
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    final lastFour = cleanNumber.isEmpty
        ? ''
        : cleanNumber
              .substring(cleanNumber.length > 4 ? cleanNumber.length - 4 : 0)
              .padLeft(4, '0');
    final number = cleanNumber.isEmpty
        ? '0000 0000 0000 0000'
        : '•••• •••• •••• $lastFour';
    final holder = cardHolder.trim().isEmpty
        ? (isArabic ? 'حامل البطاقة' : 'CARD HOLDER')
        : cardHolder.trim().toUpperCase();
    final expiry = expiryDate.trim().isEmpty ? 'MM/YY' : expiryDate.trim();

    return SizedBox(
      height: 220,
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
                          Color(0xFF14B8A6),
                          Color(0xFF0F766E),
                          Color(0xFF0B5F59),
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
                              'VISA',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.96),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                fontStyle: FontStyle.italic,
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
                              label: isArabic ? 'الانتهاء' : 'EXPIRY',
                              value: expiry,
                              alignEnd: false,
                            ),
                            const Spacer(),
                            Flexible(
                              flex: 2,
                              child: _CardMetaBlock(
                                label: isArabic
                                    ? 'حامل البطاقة'
                                    : 'CARD HOLDER',
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
        Flexible(
          child: Text(
            context.l10n.isArabic
                ? 'الدفع آمن ومشفّر'
                : 'Payment is safe and encrypted',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
