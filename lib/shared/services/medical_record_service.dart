import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/services/api_service.dart';

/// Care brand for medical records UI.
abstract final class MedicalRecordsBrand {
  static const int primary = 0xFF0F766E;
  static const int primaryDark = 0xFF0A5F5A;
  static const int background = 0xFFE8F5F2;
  static const int card = 0xFFFFFFFF;
  static const int textDark = 0xFF1E1E1E;
}

/// Official visit reports: `/medical-records/*`.
class MedicalRecordService {
  MedicalRecordService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({
    required String requesterUserId,
    required String requesterRole,
  }) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-user-id': requesterUserId,
      'x-user-role': requesterRole,
    };
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiService.baseUrl}$p');
  }

  Future<List<Map<String, dynamic>>> listForPatient(
    String patientId, {
    required String requesterUserId,
    required String requesterRole,
  }) async {
    final res = await _client
        .get(
          _uri('/medical-records/patient/$patientId'),
          headers: _headers(
            requesterUserId: requesterUserId,
            requesterRole: requesterRole,
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw _err(res, 'Failed to load medical records');
  }

  Future<Map<String, dynamic>> getVisitReportById(
    String recordId, {
    required String requesterUserId,
    required String requesterRole,
  }) async {
    final res = await _client
        .get(
          _uri('/medical-records/visit-report/$recordId'),
          headers: _headers(
            requesterUserId: requesterUserId,
            requesterRole: requesterRole,
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw _err(res, 'Failed to load record');
  }

  Future<Map<String, dynamic>> submitVisitReport(
    Map<String, dynamic> body, {
    required String requesterUserId,
    required String requesterRole,
  }) async {
    final res = await _client
        .post(
          _uri('/medical-records/visit-report'),
          headers: _headers(
            requesterUserId: requesterUserId,
            requesterRole: requesterRole,
          ),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw _err(res, 'Failed to submit visit report');
  }

  Exception _err(http.Response res, String fallback) {
    try {
      final map = jsonDecode(res.body);
      if (map is Map) {
        final err = map['error']?.toString();
        final errs = map['errors'];
        if (errs is List) {
          return Exception(
            '$err: ${errs.map((e) => e.toString()).join('; ')}',
          );
        }
        if (err != null && err.isNotEmpty) return Exception(err);
      }
    } catch (_) {}
    return Exception('$fallback (${res.statusCode})');
  }
}
