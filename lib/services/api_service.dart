import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // غيّري هذا الـ IP إلى IPv4 تبع جهازك إذا كنتِ تشغلين التطبيق على هاتف حقيقي
  static const String _machineIp = '192.168.1.15';

  // إذا كنتِ تستخدمين Android Emulator خليها true
  static const bool _useAndroidEmulator = false;

  static const String _androidEmulatorBase = 'http://10.0.2.2:3000';
  static const String _webBase = 'http://localhost:3000';
  static const String _desktopBase = 'http://127.0.0.1:3000';
  static const String _realDeviceBase = 'http://$_machineIp:3000';

  // ممكن تمرري الرابط وقت التشغيل:
  // flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    String rawUrl;

    if (_envBaseUrl.isNotEmpty) {
      rawUrl = _envBaseUrl;
    } else if (kIsWeb) {
      rawUrl = _webBase;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          rawUrl = _useAndroidEmulator ? _androidEmulatorBase : _realDeviceBase;
          break;
        case TargetPlatform.iOS:
          rawUrl = _realDeviceBase;
          break;
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
          rawUrl = _desktopBase;
          break;
        default:
          rawUrl = _realDeviceBase;
      }
    }

    return rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Uri _endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    debugPrint('[API] Request URL: $uri');
    return uri;
  }

  Future<http.Response> _sendRequest(Future<http.Response> request) async {
    try {
      final response = await request.timeout(const Duration(seconds: 20));
      debugPrint(
        '[API] Response: ${response.request?.method ?? 'UNKNOWN'} '
        '${response.request?.url ?? baseUrl} -> ${response.statusCode}',
      );
      return response;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[API] Timeout at $baseUrl: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception(
        'Request timed out. Backend may be down or unreachable at $baseUrl',
      );
    } on http.ClientException catch (e, stackTrace) {
      debugPrint(
        '[API] ClientException URL: ${e.uri ?? baseUrl}; error: ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Network request failed: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[API] Network error at $baseUrl: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Network error: $e');
    }
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null) return decoded['message'].toString();
        if (decoded['error'] != null) return decoded['error'].toString();
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {}

    if (response.body.trim().isNotEmpty) {
      return response.body;
    }

    return fallback;
  }

  Future<void> pingServer() async {
    final response = await _sendRequest(
      http.get(_endpoint('/'), headers: _jsonHeaders),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend responded with status ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected login response format');
    }

    throw Exception(_extractErrorMessage(response, 'Failed to login'));
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/forgot-password'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email.trim()}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected forgot-password response format');
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to send reset instructions'),
    );
  }

  Future<Map<String, dynamic>> getSocialAuthConfig() async {
    final response = await _sendRequest(
      http.get(_endpoint('/auth/social/config'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected social-config response format');
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load social auth config'),
    );
  }

  Future<Map<String, dynamic>> socialLoginWithGoogle({
    required String idToken,
    String role = 'patient',
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/social/google'),
        headers: _jsonHeaders,
        body: jsonEncode({'idToken': idToken, 'role': role}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected Google login response format');
    }

    throw Exception(_extractErrorMessage(response, 'Google login failed'));
  }

  Future<Map<String, dynamic>> socialLoginWithFacebook({
    required String accessToken,
    String role = 'patient',
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/social/facebook'),
        headers: _jsonHeaders,
        body: jsonEncode({'accessToken': accessToken, 'role': role}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected Facebook login response format');
    }

    throw Exception(_extractErrorMessage(response, 'Facebook login failed'));
  }

  Future<Map<String, dynamic>> socialLoginWithApple({
    required String identityToken,
    String? email,
    Map<String, dynamic>? fullName,
    String role = 'patient',
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/social/apple'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'identityToken': identityToken,
          'email': email,
          'fullName': fullName,
          'role': role,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected Apple login response format');
    }

    throw Exception(_extractErrorMessage(response, 'Apple login failed'));
  }

  Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String phone,
    String password,
    String role, {
    String? specialization,
    String? addressText,
    double? gpsLat,
    double? gpsLng,
    String? confirmPassword,
    String? dateOfBirth,
    String? gender,
    String? profileImageUrl,
    int? experienceYears,
    String? licenseNumber,
    String? serviceType,
  }) async {
    final Map<String, dynamic> body = {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'role': role,
    };

    if (confirmPassword != null) {
      body['confirmPassword'] = confirmPassword;
    }
    if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty) {
      body['profileImageUrl'] = profileImageUrl.trim();
    }

    if (role == 'patient') {
      if (addressText == null || addressText.trim().isEmpty) {
        throw Exception('Patient registration requires address');
      }
      body['addressText'] = addressText.trim();
      body['gpsLat'] = gpsLat;
      body['gpsLng'] = gpsLng;
      if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
        body['dateOfBirth'] = dateOfBirth.trim();
      }
      if (gender != null && gender.trim().isNotEmpty) {
        body['gender'] = gender.trim();
      }
    } else if (role == 'doctor' || role == 'nurse') {
      if (specialization == null || specialization.trim().isEmpty) {
        throw Exception('Doctor/Nurse registration requires specialization');
      }
      body['specialization'] = specialization.trim();
      body['gpsLat'] = gpsLat;
      body['gpsLng'] = gpsLng;
      body['addressText'] = addressText?.trim();
      if (experienceYears != null) {
        body['experienceYears'] = experienceYears;
      }
      if (licenseNumber != null && licenseNumber.trim().isNotEmpty) {
        body['licenseNumber'] = licenseNumber.trim();
      }
      if (serviceType != null && serviceType.trim().isNotEmpty) {
        body['serviceType'] = serviceType.trim();
      }
    }

    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected register response format');
    }

    throw Exception(_extractErrorMessage(response, 'Failed to register'));
  }

  Future<List<dynamic>> getproviders() async {
    final response = await _sendRequest(
      http.get(_endpoint('/providers/providers'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to load providers'));
  }

  Future<Map<String, dynamic>> getDoctorById(String userId) async {
    final response = await _sendRequest(
      http.get(_endpoint('/providers/doctor/$userId'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load doctor details'),
    );
  }

  Future<Map<String, dynamic>> getPatientProfile(String userId) async {
    final response = await _sendRequest(
      http.get(_endpoint('/patient/profile/$userId'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to load profile'));
  }

  Future<Map<String, dynamic>> updatePatientProfile(
    String userId,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/patient/profile/$userId'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to update profile'));
  }

  Future<Map<String, dynamic>> updatePatientLocation({
    required String userId,
    required double gpsLat,
    required double gpsLng,
    String? addressText,
  }) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/patient/location/$userId'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'gpsLat': gpsLat,
          'gpsLng': gpsLng,
          'addressText': addressText,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to update location'),
    );
  }

  Future<List<dynamic>> getMedicalRecords(String patientUserId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/medical-record/$patientUserId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load medical records'),
    );
  }

  Future<Map<String, dynamic>> createMedicalRecord(
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/medical-record'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to save medical record'),
    );
  }

  Future<Map<String, dynamic>> updateMedicalRecord(
    String recordId,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/patient/medical-record/$recordId'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to update medical record'),
    );
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/appointments'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to create appointment'),
    );
  }

  Future<List<dynamic>> getNotifications(String userId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/notifications/$userId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load notifications'),
    );
  }

  Future<List<dynamic>> getMessages(String userId) async {
    final response = await _sendRequest(
      http.get(_endpoint('/patient/messages/$userId'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to load messages'));
  }

  Future<List<dynamic>> getChatMessages(String userId, String doctorId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/chat/$userId/$doctorId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load chat messages'),
    );
  }

  Future<Map<String, dynamic>> sendChatMessage(
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/chat/send'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to send chat message'),
    );
  }

  Future<Map<String, dynamic>> createBooking({
    required String patientId,
    required String providerId,
    required String date,
    required String time,
    String? notes,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/appointments'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'patientUserId': patientId,
          'providerUserId': providerId,
          'date': date,
          'time': time,
          'notes': notes?.trim() ?? '',
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to create booking'));
  }

  Future<List<dynamic>> getAppointments(
    String patientUserId, {
    String? status,
  }) async {
    final suffix = status == null || status.isEmpty ? '' : '?status=$status';
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/appointments/$patientUserId$suffix'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load appointments'),
    );
  }

  Future<List<dynamic>> getUpcomingAppointments(String patientUserId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/appointments/upcoming/$patientUserId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load upcoming appointments'),
    );
  }

  Future<List<dynamic>> getAppointmentHistory(String patientUserId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/appointments/history/$patientUserId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load appointment history'),
    );
  }

  Future<Map<String, dynamic>> getAppointmentDetails(
    String appointmentId,
  ) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/appointments/details/$appointmentId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load appointment details'),
    );
  }

  Future<Map<String, dynamic>> cancelAppointment({
    required String appointmentId,
    required String patientUserId,
    String? reason,
  }) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/patient/appointments/$appointmentId/cancel'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'patientUserId': patientUserId,
          'reason': reason ?? '',
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to cancel appointment'),
    );
  }

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> body) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/payments'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to create payment'));
  }

  Future<List<dynamic>> getPayments(String patientUserId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/patient/payments/$patientUserId'),
        headers: _jsonHeaders,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to load payments'));
  }

  Future<List<dynamic>> getProviders() async {
    final response = await _sendRequest(
      http.get(_endpoint('/providers'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception(_extractErrorMessage(response, 'Failed to load providers'));
  }

  Future<Map<String, dynamic>> getProviderById(String userId) async {
    final response = await _sendRequest(
      http.get(_endpoint('/providers/provider/$userId'), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to load provider details'),
    );
  }

  Future<dynamic> get(String endpoint) async {
    final response = await _sendRequest(
      http.get(_endpoint(endpoint), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(_extractErrorMessage(response, 'GET request failed'));
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await _sendRequest(
      http.post(
        _endpoint(endpoint),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(_extractErrorMessage(response, 'POST request failed'));
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await _sendRequest(
      http.put(
        _endpoint(endpoint),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(_extractErrorMessage(response, 'PUT request failed'));
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await _sendRequest(
      http.delete(_endpoint(endpoint), headers: _jsonHeaders),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(_extractErrorMessage(response, 'DELETE request failed'));
  }
}
