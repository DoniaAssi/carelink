import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  MedicalRecordService({http.Client? client})
    : _client = client ?? http.Client();

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

  void _logRequest({
    required Uri url,
    required String method,
    int? statusCode,
    String? error,
  }) {
    if (kDebugMode) {
      debugPrint(
        '[MedicalRecordService] Request URL: $url | '
        'HTTP method: $method | '
        'Status code: ${statusCode?.toString() ?? 'n/a'}'
        '${error == null || error.isEmpty ? '' : ' | Error message: $error'}',
      );
    }
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

  Future<Map<String, dynamic>> uploadPatientRecord({
    required String patientId,
    required String title,
    required String category,
    required String notes,
    required bool usedForAiMatching,
    required bool aiReady,
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    final uri = _uri('/medical-records/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(
      _headers(requesterUserId: patientId, requesterRole: 'patient'),
    );

    request.fields['patientId'] = patientId;
    request.fields['patient_id'] = patientId;
    request.fields['title'] = title;
    request.fields['category'] = category;
    request.fields['notes'] = notes;
    request.fields['description'] = notes;
    request.fields['usedForAiMatching'] = usedForAiMatching ? 'true' : 'false';
    request.fields['used_for_ai_matching'] = usedForAiMatching
        ? 'true'
        : 'false';
    request.fields['aiReady'] = aiReady ? 'true' : 'false';
    request.fields['ai_ready'] = aiReady ? 'true' : 'false';
    request.fields['source'] = 'patient_upload';

    if (fileBytes != null && fileBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else if (filePath != null && filePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    } else {
      throw Exception('No file data provided for upload');
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 40),
    );
    final response = await http.Response.fromStream(streamedResponse);

    _logRequest(url: uri, method: 'POST', statusCode: response.statusCode);

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }

    if (response.statusCode == 404) {
      _logRequest(
        url: uri,
        method: 'POST',
        statusCode: response.statusCode,
        error: 'Upload endpoint not found',
      );
      throw Exception(
        'Upload endpoint not found.\n'
        'Requested URL: $uri\n'
        'Status code: ${response.statusCode}',
      );
    }

    throw _err(response, 'Failed to upload medical record');
  }

  Future<void> deletePatientRecord({
    required String recordId,
    required String patientId,
  }) async {
    final res = await _client
        .delete(
          _uri('/medical-records/upload/$recordId'),
          headers: _headers(
            requesterUserId: patientId,
            requesterRole: 'patient',
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw _err(res, 'Failed to delete record');
  }

  Exception _err(http.Response res, String fallback) {
    try {
      final map = jsonDecode(res.body);
      if (map is Map) {
        final err = map['error']?.toString();
        final errs = map['errors'];
        if (errs is List) {
          return Exception('$err: ${errs.map((e) => e.toString()).join('; ')}');
        }
        if (err != null && err.isNotEmpty) return Exception(err);
      }
    } catch (_) {}
    return Exception('$fallback (${res.statusCode})');
  }
}
