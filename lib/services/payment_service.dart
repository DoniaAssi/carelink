import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/payment_method.dart';
import '../models/payment_transaction.dart';

class PaymentService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  static Future<List<PaymentMethod>> getPaymentMethods(int providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/payment_methods.php?providerId=$providerId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List methods = data['methods'] ?? [];
          return methods.map((item) => PaymentMethod.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Get payment methods error: $e');
    }
    return [];
  }

  static Future<List<PaymentTransaction>> getPaymentHistory(int providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/payment_history.php?providerId=$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List history = data['history'] ?? [];
          return history.map((item) => PaymentTransaction.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Get payment history error: $e');
    }
    return [];
  }

  static Future<bool> addPaymentMethod(int providerId, String type, String details, bool isDefault) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/add_payment_method.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
          'type': type,
          'details': details,
          'isDefault': isDefault ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Add payment method error: $e');
    }
    return false;
  }

  static Future<bool> updatePaymentMethod(int providerId, int methodId, String type, String details, bool isDefault) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/update_payment_method.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
          'methodId': methodId,
          'type': type,
          'details': details,
          'isDefault': isDefault ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Update payment method error: $e');
    }
    return false;
  }

  static Future<bool> deletePaymentMethod(int providerId, int methodId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/delete_payment_method.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
          'methodId': methodId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Delete payment method error: $e');
    }
    return false;
  }

  static Future<bool> requestPayment(int providerId, int transactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/request_payment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
          'transactionId': transactionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Request payment error: $e');
    }
    return false;
  }
}
