import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/service_request.dart';

class ServiceRequestService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  // الحصول على طلبات المريض
  static Future<List<ServiceRequest>> getPatientRequests(int patientId, {String? status}) async {
    try {
      String url = '$baseUrl/api/patient/requests.php?patientId=$patientId';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          List<ServiceRequest> requests = [];
          for (var item in data['requests']) {
            requests.add(ServiceRequest.fromJson(item));
          }
          return requests;
        }
      }
      return [];
    } catch (e) {
      print('Get patient requests error: $e');
      return [];
    }
  }

  // إنشاء طلب خدمة جديد
  static Future<bool> createRequest({
    required int patientId,
    required int providerId,
    required String serviceType,
    required String location,
    required DateTime scheduledDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/patient/create_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patientId': patientId,
          'providerId': providerId,
          'serviceType': serviceType,
          'location': location,
          'scheduledDate': scheduledDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Create request error: $e');
      return false;
    }
  }

  // تحديث حالة الطلب
  static Future<bool> updateRequestStatus(int requestId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/update_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': requestId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Update status error: $e');
      return false;
    }
  }

  // الحصول على طلبات المزود (للممرض)
  static Future<List<ServiceRequest>> getProviderRequests(int providerId, {String? status}) async {
    try {
      String url = '$baseUrl/api/provider/requests.php?providerId=$providerId';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          List<ServiceRequest> requests = [];
          for (var item in data['requests']) {
            requests.add(ServiceRequest.fromJson(item));
          }
          return requests;
        }
      }
      return [];
    } catch (e) {
      print('Get provider requests error: $e');
      return [];
    }
  }
}
