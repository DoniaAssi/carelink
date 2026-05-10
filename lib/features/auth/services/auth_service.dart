import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/carelink_api_config.dart';

/// Phone OTP signup against **CareLink Node** (`backend` on port 3000).
///
/// - `POST /auth/send-phone-otp`
/// - `POST /auth/register-with-phone-otp`
class AuthService {
  AuthService({String? baseUrl}) : _nodeRoot = _apiRootOrFallback(baseUrl);

  final String _nodeRoot;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _coerceSegment(Object? o) {
    if (o == null) return '';
    if (o is String) return o;
    try {
      return o.toString();
    } catch (_) {
      return '';
    }
  }

  static String _apiRootOrFallback(String? baseUrl) {
    final r = _normalizeRoot(baseUrl ?? CarelinkApiConfig.origin);
    return r.isEmpty ? 'http://localhost:3000' : r;
  }

  static String _normalizeRoot(Object? s) {
    try {
      return _coerceSegment(s).trim().replaceAll(RegExp(r'/+$'), '');
    } catch (_) {
      return '';
    }
  }

  Uri _auth(String path) {
    try {
      final root = _nodeRoot.replaceAll(RegExp(r'/+$'), '');
      final p = path.startsWith('/') ? path : '/$path';
      return Uri.parse('$root$p');
    } catch (_) {
      return Uri.parse('http://localhost:3000/auth/send-phone-otp');
    }
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message']?.toString();
        if (m != null && m.trim().isNotEmpty) return m.trim();
        final e = decoded['error']?.toString();
        if (e != null && e.trim().isNotEmpty) return e.trim();
        final errs = decoded['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
        }
      }
    } catch (_) {}
    return 'Request failed ($statusCode)';
  }

  /// `POST /auth/send-phone-otp`
  Future<SendOtpResult> sendOtp({required String phoneDigits}) async {
    try {
      final response = await http.post(
        _auth('/auth/send-phone-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phoneDigits, 'purpose': 'signup'}),
      );

      final body = response.body;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? map;
        try {
          final d = jsonDecode(body);
          if (d is Map<String, dynamic>) map = d;
        } catch (_) {}
        final note =
            map?['smsDeliveryNote']?.toString() ?? map?['message']?.toString();
        return SendOtpResult(note: note);
      }

      throw AuthApiException(
        _extractError(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } on AuthApiException {
      rethrow;
    } on http.ClientException catch (e, st) {
      debugPrint('[AuthService.sendOtp] ClientException: $e');
      debugPrint('$st');
      throw AuthApiException(
        'Cannot reach Node API at ${_auth('/auth/send-phone-otp')} — run `cd backend && node server.js` (port 3000).',
      );
    } catch (e, st) {
      debugPrint('[AuthService.sendOtp] $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// `POST /auth/register-with-phone-otp`
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneDigits,
    required String password,
    required String role,
    required String otp,
    String? addressText,
    String? dateOfBirth,
    String? gender,
    String? chronicDiseases,
    String? allergies,
    String? currentMedications,
    String? specialization,
    String? licenseNumber,
    String? experienceYears,
    String? serviceType,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'phone': phoneDigits,
      'password': password,
      'role': role,
      'otp': otp.trim(),
    };
    final mail = email.trim();
    if (mail.isNotEmpty) {
      payload['email'] = mail;
    }
    void addIfNotEmpty(String key, String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) payload[key] = trimmed;
    }

    addIfNotEmpty('addressText', addressText);
    addIfNotEmpty('dateOfBirth', dateOfBirth);
    addIfNotEmpty('gender', gender);
    addIfNotEmpty('chronicDiseases', chronicDiseases);
    addIfNotEmpty('allergies', allergies);
    addIfNotEmpty('currentMedications', currentMedications);
    addIfNotEmpty('specialization', specialization);
    addIfNotEmpty('licenseNumber', licenseNumber);
    addIfNotEmpty('experienceYears', experienceYears);
    addIfNotEmpty('serviceType', serviceType);
    if (gpsLat != null) payload['gpsLat'] = gpsLat;
    if (gpsLng != null) payload['gpsLng'] = gpsLng;

    try {
      final response = await http.post(
        _auth('/auth/register-with-phone-otp'),
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );

      final body = response.body;
      Map<String, dynamic>? decoded;
      try {
        final d = jsonDecode(body);
        if (d is Map<String, dynamic>) decoded = d;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded ?? <String, dynamic>{'raw': body};
      }

      throw AuthApiException(
        decoded != null
            ? _extractError(body, response.statusCode)
            : (body.isNotEmpty ? body : 'Registration failed'),
        statusCode: response.statusCode,
      );
    } on AuthApiException {
      rethrow;
    } on http.ClientException catch (e, st) {
      debugPrint('[AuthService.register] ClientException: $e');
      debugPrint('$st');
      throw AuthApiException(
        'Cannot reach Node API at ${_auth('/auth/register-with-phone-otp')}.',
      );
    } catch (e, st) {
      debugPrint('[AuthService.register] $e');
      debugPrint('$st');
      rethrow;
    }
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SendOtpResult {
  SendOtpResult({this.devCode, this.note});

  final String? devCode;
  final String? note;
}
