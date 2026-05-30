import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/payment_method.dart';
import 'package:carelink/shared/models/payment_transaction.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Patient Visa demo ledger: **`POST /api/payments/create`** then **`confirm`** with test cards only.
/// Nurse screens use static helpers that talk to `/nurse/...` on [ApiService.baseUrl].
class PaymentService {
  PaymentService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static String get baseUrl => ApiService.baseUrl;

  /// Creates a pending **`visa_card`** row, validates demo PAN server-side, never stores PAN/CVV.
  Future<Map<String, dynamic>> payWithVisaDemo({
    required String appointmentId,
    required String patientUserId,
    required String providerUserId,
    double? amountHint,
    required String cardholderName,
    required String cardNumber,
    required String expiryMmYy,
    required String cvv,
    String? billingEmail,
  }) async {
    final created = await _api.postJson(
      '/api/payments/create',
      {
        'appointmentId': appointmentId,
        'patientUserId': patientUserId,
        'providerUserId': providerUserId,
        'paymentMethod': 'visa_card',
        if (amountHint != null) 'amount': amountHint,
      },
      errorFallback: 'Payment could not be started',
    );

    final paymentId = (created['paymentId'] ?? '').toString().trim();
    final confirmBody = <String, dynamic>{
      if (paymentId.isNotEmpty) 'paymentId': paymentId,
      'appointmentId': appointmentId,
      'patientUserId': patientUserId,
      'cardholderName': cardholderName.trim(),
      'cardNumber': cardNumber.replaceAll(RegExp(r'\s'), ''),
      'expiry': expiryMmYy.trim(),
      'cvv': cvv.trim(),
      if (billingEmail != null && billingEmail.trim().isNotEmpty)
        'billingEmail': billingEmail.trim(),
    };

    final confirmed = await _api.postJson(
      '/api/payments/confirm',
      confirmBody,
      errorFallback: 'Payment failed. Please try another test Visa card.',
    );

    final merged = <String, dynamic>{
      ...created,
      ...confirmed,
      'success': true,
      'paymentStatus': (confirmed['paymentStatus'] ?? created['paymentStatus'])
          ?.toString() ??
          '',
    };
    merged['status'] = merged['paymentStatus'];
    return merged;
  }

  /// @deprecated Use [payWithVisaDemo] with the Visa checkout sheet.
  Future<Map<String, dynamic>> payForBooking({
    required String appointmentId,
    required String patientUserId,
    required String providerUserId,
    double? amountHint,
    required String paymentMethod,
  }) async {
    return _api.postJson(
      '/api/payments/create',
      {
        'appointmentId': appointmentId,
        'patientUserId': patientUserId,
        'providerUserId': providerUserId,
        'paymentMethod': 'visa_card',
        if (amountHint != null) 'amount': amountHint,
      },
      errorFallback: 'Payment could not be processed',
    );
  }

  /// [appointmentId] is the UUID returned by `POST /patient/appointments`.
  /// Opens Visa checkout in UI — this helper is not used directly; prefer [payWithVisaDemo].
  Future<Map<String, dynamic>> createPayment({
    required String appointmentId,
    required String patientId,
    required String providerId,
    required double amount,
    required String method,
  }) async {
    return payForBooking(
      appointmentId: appointmentId,
      patientUserId: patientId,
      providerUserId: providerId,
      amountHint: amount,
      paymentMethod: method,
    );
  }

  static Future<List<PaymentMethod>> getPaymentMethods(
    String providerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/payment-methods/$providerId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List methods = data is List ? data : [];
        return methods
            .map(
              (item) => PaymentMethod.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Get payment methods error: $e');
    }
    return [];
  }

  static Future<List<PaymentTransaction>> getPaymentHistory(
    String providerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/payments/$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List history = data is List ? data : [];
        return history
            .map(
              (item) => PaymentTransaction.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Get payment history error: $e');
    }
    return [];
  }

  static Future<Map<String, double>> getPaymentSummary(
    String providerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/payments/$providerId/summary'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'thisMonth': _parseDouble(data['thisMonth']),
          'thisWeek': _parseDouble(data['thisWeek']),
          'today': _parseDouble(data['today']),
        };
      }
    } catch (e) {
      // ignore: avoid_print
      print('Get payment summary error: $e');
    }
    return {'thisMonth': 0, 'thisWeek': 0, 'today': 0};
  }

  static Future<bool> addPaymentMethod(
    String providerId,
    String type,
    String details,
    bool isDefault,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nurse/payment-methods/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'details': details,
          'isDefault': isDefault ? 1 : 0,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Add payment method error: $e');
    }
    return false;
  }

  static Future<bool> updatePaymentMethod(
    String providerId,
    String methodId,
    String type,
    String details,
    bool isDefault,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/payment-methods/$providerId/$methodId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'details': details,
          'isDefault': isDefault ? 1 : 0,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Update payment method error: $e');
    }
    return false;
  }

  static Future<bool> deletePaymentMethod(
    String providerId,
    String methodId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/nurse/payment-methods/$providerId/$methodId'),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Delete payment method error: $e');
    }
    return false;
  }

  static Future<bool> requestPayment(
    String providerId,
    String transactionId,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/payments/$providerId/$transactionId/status'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': 'paid',
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Request payment error: $e');
    }
    return false;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
