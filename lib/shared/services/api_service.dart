import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // غيّري هذا الـ IP إلى IPv4 تبع جهازك إذا كنتِ تشغلين التطبيق على هاتف حقيقي
  static const String _machineIp = '192.168.1.5';

  // إذا كنتِ تستخدمين Android Emulator خليها true.
  // إذا كنتِ تستخدمين جهاز حقيقي، ضعيها false وحددي عنوان IP صحيح في _machineIp.
  static const bool _useAndroidEmulator = true;

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

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Uri _endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Future<http.Response> _sendRequest(Future<http.Response> request) async {
    try {
      return await request.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception(
        'Request timed out. Backend may be down or unreachable at $baseUrl',
      );
    } on http.ClientException catch (e) {
      throw Exception('Network request failed: ${e.message}');
    } catch (e) {
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
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected login response format');
    }

    throw Exception(_extractErrorMessage(response, 'Failed to login'));
  }

  Future<Map<String, dynamic>> sendEmailVerificationCode({
    required String email,
    required String purpose,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/send-email-code'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'purpose': purpose,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected send-email-code response');
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to send email code'),
    );
  }

  Future<Map<String, dynamic>> verifyEmailCode({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/verify-email-code'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'purpose': purpose,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected verify-email-code response');
    }

    throw Exception(
      _extractErrorMessage(response, 'Email verification failed'),
    );
  }

  Future<Map<String, dynamic>> sendPhoneVerificationCode({
    required String phoneDigits,
    required String purpose,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/send-phone-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phoneDigits, 'purpose': purpose}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected send-phone-otp response');
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to send phone code'),
    );
  }

  Future<Map<String, dynamic>> verifyPhoneVerificationCode({
    required String phoneDigits,
    required String code,
    required String purpose,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/verify-phone-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'phone': phoneDigits,
          'code': code.trim(),
          'purpose': purpose,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected verify-phone-otp response');
    }

    throw Exception(
      _extractErrorMessage(response, 'Phone verification failed'),
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/auth/reset-password'),
        headers: _jsonHeaders,
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected reset-password response format');
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to reset password'),
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
    String? chronicDiseases,
    String? allergies,
    String? currentMedications,
    String? phoneVerificationToken,
    String? emailVerificationToken,
  }) async {
    final Map<String, dynamic> body = {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'password': password,
      'role': role,
    };

    if (phoneVerificationToken != null &&
        phoneVerificationToken.trim().isNotEmpty) {
      body['phoneVerificationToken'] = phoneVerificationToken.trim();
    }
    if (emailVerificationToken != null &&
        emailVerificationToken.trim().isNotEmpty) {
      body['emailVerificationToken'] = emailVerificationToken.trim();
    }

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
      final c = chronicDiseases?.trim();
      if (c != null && c.isNotEmpty) body['chronicDiseases'] = c;
      final a = allergies?.trim();
      if (a != null && a.isNotEmpty) body['allergies'] = a;
      final m = currentMedications?.trim();
      if (m != null && m.isNotEmpty) body['currentMedications'] = m;
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

  Future<List<dynamic>> getNotifications(String userId) async {
    final response = await _sendRequest(
      http.get(
        _endpoint('/notifications/$userId'),
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
    String? serviceType,
    double? visitLatitude,
    double? visitLongitude,
    String? visitAddress,
    String? locationNote,
    String? symptoms,
    bool? isUrgent,
    String? additionalNotes,
    String? paymentMethod,
    String? paymentStatus,
    String? urgencyLevel,
  }) async {
    final urgency = (urgencyLevel ?? (isUrgent == true ? 'urgent' : 'routine'))
        .toString()
        .trim()
        .toLowerCase();
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/appointments'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'patientUserId': patientId,
          'providerUserId': providerId,
          'serviceType': serviceType ?? 'appointment',
          'date': date,
          'time': time,
          'notes': notes?.trim() ?? '',
          'visitLatitude': visitLatitude,
          'visitLongitude': visitLongitude,
          'visitAddress': visitAddress?.trim() ?? '',
          'locationNote': locationNote?.trim() ?? '',
          'symptoms': symptoms?.trim() ?? '',
          'isUrgent': isUrgent == true,
          'urgencyLevel': urgency.isEmpty ? 'routine' : urgency,
          'additionalNotes': additionalNotes?.trim() ?? '',
          'paymentMethod': paymentMethod?.trim() ?? '',
          'paymentStatus': paymentStatus?.trim() ?? '',
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

  /// Post-visit rating (1–5) after the provider marks the visit completed. Updates provider `overallRating`.
  Future<Map<String, dynamic>> rateCompletedVisit({
    required String appointmentId,
    required String patientUserId,
    required int stars,
    String? comment,
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint('/patient/appointments/$appointmentId/rate'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'patientUserId': patientUserId,
          'stars': stars,
          'comment': comment,
        }),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      _extractErrorMessage(response, 'Failed to submit rating'),
    );
  }

  /// Stores payment metadata only (method, amount, status). Card numbers / CVV must never be in [body].
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

  /// Bookings / visits assigned to a care provider (nurse, doctor).
  Future<List<dynamic>> getProviderAppointments(String providerUserId) async {
    final q = Uri.encodeQueryComponent(providerUserId);
    final response = await _sendRequest(
      http.get(
        _endpoint('/providers/appointments?providerUserId=$q'),
        headers: _jsonHeaders,
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to load provider appointments'),
    );
  }

  Future<Map<String, dynamic>> updateProviderAppointmentStatus({
    required String requestId,
    required String providerUserId,
    required String status,
  }) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/providers/appointments/$requestId/status'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'providerUserId': providerUserId,
          'status': status,
        }),
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to update appointment status'),
    );
  }

  /// Live location for an accepted visit; backend stores last position for the patient map.
  Future<Map<String, dynamic>> postProviderVisitLocation({
    required String requestId,
    required String providerUserId,
    required double lat,
    required double lng,
  }) async {
    final response = await _sendRequest(
      http.put(
        _endpoint('/providers/appointments/$requestId/location'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'providerUserId': providerUserId,
          'lat': lat,
          'lng': lng,
        }),
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to update visit location'),
    );
  }

  /// JSON object POST — feature services (e.g. payments) should wrap this, not UI.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String errorFallback = 'Request failed',
  }) async {
    final response = await _sendRequest(
      http.post(
        _endpoint(path),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response, errorFallback));
  }
}
