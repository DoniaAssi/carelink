import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/payment_method.dart';
import 'package:carelink/shared/models/payment_transaction.dart';
import 'package:carelink/shared/services/api_service.dart';

/// Patient flows use instance [createPayment]. Nurse screens use static helpers
/// that talk to `/nurse/...` on [ApiService.baseUrl].
class PaymentService {
  PaymentService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static String get baseUrl => ApiService.baseUrl;

  /// [appointmentId] is the UUID returned by `POST /patient/appointments`.
  ///
  /// [method]: `cash` | `card` | `wallet`.
  Future<Map<String, dynamic>> createPayment({
    required String appointmentId,
    required String patientId,
    required String providerId,
    required double amount,
    required String method,
  }) async {
    return _api.postJson(
      '/payments/create',
      {
        'appointmentId': appointmentId,
        'patientId': patientId,
        'providerId': providerId,
        'amount': amount,
        'method': method.trim().toLowerCase(),
      },
      errorFallback: 'Payment could not be processed',
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
            .map((item) => PaymentMethod.fromJson(Map<String, dynamic>.from(item as Map)))
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
              (item) =>
                  PaymentTransaction.fromJson(Map<String, dynamic>.from(item as Map)),
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
