import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/services/api_service.dart';

class ServiceRequestService {
  static String get baseUrl => ApiService.baseUrl;

  static const String _phpBaseUrl = 'http://127.0.0.1/carelink';

  static Future<List<ServiceRequest>> getPatientRequests(
    int patientId, {
    String? status,
  }) async {
    try {
      String url = '$_phpBaseUrl/api/patient/requests.php?patientId=$patientId';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<ServiceRequest> requests = [];
          for (final item in data['requests'] as List) {
            requests.add(
              ServiceRequest.fromJson(Map<String, dynamic>.from(item as Map)),
            );
          }
          return requests;
        }
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('Get patient requests error: $e');
      return [];
    }
  }

  static Future<bool> createRequest({
    required int patientId,
    required int providerId,
    required String serviceType,
    required String location,
    required DateTime scheduledDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_phpBaseUrl/api/patient/create_request.php'),
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
      // ignore: avoid_print
      print('Create request error: $e');
      return false;
    }
  }

  static Future<bool> updateRequestStatus(
    String requestId,
    String status, {
    String? providerUserId,
  }) async {
    String apiStatus = status;
    if (status.toLowerCase() == 'scheduled') {
      apiStatus = 'confirmed';
    }
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/requests/$requestId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': apiStatus,
          if (providerUserId != null) 'providerUserId': providerUserId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      String message = 'Failed to update request status';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    } catch (e) {
      // ignore: avoid_print
      print('Update status error: $e');
      if (e is Exception) rethrow;
      return false;
    }
  }

  static Future<List<ServiceRequest>> getProviderRequests(
    String providerId, {
    String? status,
  }) async {
    try {
      String url = '$baseUrl/nurse/requests/$providerId';
      if (status != null && status.isNotEmpty) {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map(
                (item) => ServiceRequest.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('Get provider requests error: $e');
      return [];
    }
  }
}
