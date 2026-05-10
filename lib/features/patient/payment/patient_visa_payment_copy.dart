import 'package:flutter/widgets.dart';

import 'package:carelink/core/app_localizations.dart';

/// Localized copy for CareLink **Visa-only** demo checkout.
abstract final class PatientVisaPaymentCopy {
  static String unpaidPayWithVisa(BuildContext context) =>
      context.tr('payment.line.unpaidPay');

  static String unpaidNextStep(BuildContext context) =>
      context.tr('payment.line.unpaidNext');

  static String paidLine(BuildContext context, String? cardLast4) {
    final f = (cardLast4 ?? '').trim();
    if (f.length == 4) {
      return context.tr('payment.line.paidLast4', args: {'last4': f});
    }
    return context.tr('payment.line.paid');
  }
}
