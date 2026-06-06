import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/visit_report.dart';

class ReportService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  static Future<List<VisitReport>> getReports(int providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/reports.php?providerId=$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List reports = data['reports'] ?? [];
          return reports.map((item) => VisitReport.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Get reports error: $e');
    }
    return [];
  }

  static Future<bool> createReport({
    required int providerId,
    required int patientId,
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
        Uri.parse('$baseUrl/api/provider/create_report.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Create report error: $e');
    }
    return false;
  }

  static Future<bool> updateReport({
    required int reportId,
    required int providerId,
    required String visitSummary,
    required String vitalSigns,
    required String medications,
    required String observations,
    required String recommendations,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/update_report.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': reportId,
          'providerId': providerId,
          'visitSummary': visitSummary,
          'vitalSigns': vitalSigns,
          'medications': medications,
          'observations': observations,
          'recommendations': recommendations,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Update report error: $e');
    }
    return false;
  }
}
