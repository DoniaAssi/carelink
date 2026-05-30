import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/visit_report.dart';
import 'package:carelink/shared/services/api_service.dart';

class ReportService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<List<VisitReport>> getReports(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/reports/$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List reports = data is List ? data : [];
        return reports
            .map((item) => VisitReport.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Get reports error: $e');
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
      // ignore: avoid_print
      print('Create report failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      // ignore: avoid_print
      print('Create report error: $e');
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
      // ignore: avoid_print
      print('Update report failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      // ignore: avoid_print
      print('Update report error: $e');
    }
    return false;
  }
}
