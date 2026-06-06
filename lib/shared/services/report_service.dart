import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/visit_report.dart';
import 'package:carelink/shared/services/api_service.dart';

class ReportService {
  static String get baseUrl => ApiService.baseUrl;

  static void _logError(String message) {
    if (kDebugMode) {
      debugPrint('[ReportService] $message');
    }
  }

  static Future<List<VisitReport>> getReports(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/reports/$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List reports = data is List ? data : [];
        return reports
            .map(
              (item) =>
                  VisitReport.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
    } catch (e) {
      _logError('Error message: $e');
    }
    return [];
  }

  static Future<bool> createReport({
    required String providerId,
    required String requestId,
    required String patientId,
    required String patientName,
    required String serviceType,
    required String location,
    required DateTime scheduledDate,
    required int durationHours,
    required String visitSummary,
    required String vitalSigns,
    required String medications,
    required String observations,
    required String recommendations,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nurse/reports/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': requestId,
          'patientId': patientId,
          'patientName': patientName,
          'serviceType': serviceType,
          'location': location,
          'scheduledDate': scheduledDate.toIso8601String(),
          'durationHours': durationHours,
          'visitSummary': visitSummary,
          'vitalSigns': vitalSigns,
          'medications': medications,
          'observations': observations,
          'recommendations': recommendations,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      _logError(
        'Request URL: ${response.request?.url} | HTTP method: POST | '
        'Status code: ${response.statusCode} | Error message: Create report failed',
      );
    } catch (e) {
      _logError('Error message: $e');
    }
    return false;
  }

  static Future<bool> updateReport({
    required String reportId,
    required String providerId,
    required String requestId,
    required String patientId,
    required String patientName,
    required String serviceType,
    required String location,
    required DateTime scheduledDate,
    required int durationHours,
    required String visitSummary,
    required String vitalSigns,
    required String medications,
    required String observations,
    required String recommendations,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nurse/reports/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': reportId,
          'requestId': requestId,
          'patientId': patientId,
          'patientName': patientName,
          'serviceType': serviceType,
          'location': location,
          'scheduledDate': scheduledDate.toIso8601String(),
          'durationHours': durationHours,
          'visitSummary': visitSummary,
          'vitalSigns': vitalSigns,
          'medications': medications,
          'observations': observations,
          'recommendations': recommendations,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      _logError(
        'Request URL: ${response.request?.url} | HTTP method: POST | '
        'Status code: ${response.statusCode} | Error message: Update report failed',
      );
    } catch (e) {
      _logError('Error message: $e');
    }
    return false;
  }
}
