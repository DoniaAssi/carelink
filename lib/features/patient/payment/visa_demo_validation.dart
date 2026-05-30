import 'package:flutter/services.dart';

/// Stripe-style demo Visa numbers only (must match backend).
abstract final class VisaDemoRules {
  static const successPan = '4242424242424242';
  static const failPan = '4000000000000002';
  static const declinedPan = '4000000000009995';

  static String digitsOnly(String s) =>
      s.replaceAll(RegExp(r'\D'), '');

  static String? classifyPan(String digits) {
    switch (digits) {
      case successPan:
        return 'success';
      case failPan:
        return 'failed';
      case declinedPan:
        return 'declined';
      default:
        return null;
    }
  }

  static String demoPanErrorMessage() =>
      'Use a valid test Visa card number for demo mode.';

  static void validateExpiryMmYy(String raw) {
    final t = raw.replaceAll(RegExp(r'\s'), '');
    int mm;
    int yyShort;
    final slash = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(t);
    if (slash != null) {
      mm = int.parse(slash.group(1)!);
      yyShort = int.parse(slash.group(2)!);
    } else if (RegExp(r'^\d{4}$').hasMatch(t)) {
      mm = int.parse(t.substring(0, 2));
      yyShort = int.parse(t.substring(2, 4));
    } else {
      throw FormatException('Expiry must be MM/YY.');
    }
    if (mm < 1 || mm > 12) {
      throw FormatException('Invalid expiry month.');
    }
    final fullYear = 2000 + yyShort;
    final lastMs = DateTime(fullYear, mm + 1, 0, 23, 59, 59).millisecondsSinceEpoch;
    if (lastMs < DateTime.now().millisecondsSinceEpoch) {
      throw FormatException('Card has expired.');
    }
  }

  static void validateCvv(String raw) {
    final d = digitsOnly(raw);
    if (d.length < 3 || d.length > 4) {
      throw FormatException('CVV must be 3 or 4 digits.');
    }
  }

  static void validateCardholder(String name) {
    if (name.trim().length < 2) {
      throw FormatException('Cardholder name is required.');
    }
  }
}

class VisaCardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = d.length <= 16 ? d : d.substring(0, 16);
    final buf = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(capped[i]);
    }
    final t = buf.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class VisaExpiryMmYyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    var t = digits;
    if (digits.length >= 2) {
      t = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
