import 'package:flutter/foundation.dart';

import 'package:carelink/shared/services/api_service.dart';

/// Thrown for expected auth/validation failures (show message to user).
class AuthServiceException implements Exception {
  AuthServiceException(this.message, {this.retryAfterSeconds});

  final String message;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

/// Purposes accepted by CareLink verification APIs.
abstract final class VerificationPurpose {
  static const String signup = 'signup';
  static const String passwordReset = 'password_reset';
}

class SendVerificationResult {
  SendVerificationResult({required this.userMessage, this.devCode});

  final String userMessage;
  /// Only present when backend runs in non-production and opts in to dev exposure.
  final String? devCode;
}

/// High-level auth flows. Uses [ApiService] for HTTP.
class AuthService {
  AuthService([ApiService? api]) : _api = api ?? ApiService();

  final ApiService _api;

  static final RegExp emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmailFormat(String email) =>
      emailFormat.hasMatch(email.trim());

  static String normalizePhoneDigits(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  static bool isValidPhoneLength(String digitsOnly) {
    final n = digitsOnly.length;
    return n >= 8 && n <= 15;
  }

  Never _throwFromException(Object e) {
    if (e is AuthServiceException) throw e;
    final s = e.toString().replaceFirst('Exception: ', '');
    throw AuthServiceException(s);
  }

  Future<SendVerificationResult> sendEmailVerificationCode({
    required String email,
    required String purpose,
  }) async {
    final trimmed = email.trim().toLowerCase();
    if (!isValidEmailFormat(trimmed)) {
      throw AuthServiceException('Invalid email address');
    }
    try {
      final map = await _api.sendEmailVerificationCode(
        email: trimmed,
        purpose: purpose,
      );
      final msg = map['message']?.toString() ??
          'Verification code sent to your email';
      final dev = map['devVerificationCode']?.toString();
      return SendVerificationResult(
        userMessage: msg,
        devCode: (dev != null && dev.isNotEmpty) ? dev : null,
      );
    } catch (e) {
      _throwFromException(e);
    }
  }

  Future<SendVerificationResult> sendPhoneVerificationCode({
    required String phoneDigits,
    required String purpose,
  }) async {
    final d = normalizePhoneDigits(phoneDigits);
    if (!isValidPhoneLength(d)) {
      throw AuthServiceException(
        'Enter a valid phone number (8–15 digits)',
      );
    }
    try {
      final map = await _api.sendPhoneVerificationCode(
        phoneDigits: d,
        purpose: purpose,
      );
      final msg = map['message']?.toString() ??
          'Verification code sent to your phone';
      final dev = map['devVerificationCode']?.toString();
      return SendVerificationResult(
        userMessage: msg,
        devCode: (dev != null && dev.isNotEmpty) ? dev : null,
      );
    } catch (e) {
      _throwFromException(e);
    }
  }

  /// Signup → `emailVerificationToken`. Password reset → `resetToken` for [completePasswordReset].
  Future<({String? emailVerificationToken, String? resetToken})>
      verifyEmailCode({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final trimmed = email.trim().toLowerCase();
    if (!isValidEmailFormat(trimmed)) {
      throw AuthServiceException('Invalid email address');
    }
    final c = code.trim();
    if (c.isEmpty) {
      throw AuthServiceException('Enter the verification code');
    }
    try {
      final map = await _api.verifyEmailCode(
        email: trimmed,
        code: c,
        purpose: purpose,
      );
      if (map['verified'] != true) {
        throw AuthServiceException('Invalid verification code');
      }
      if (purpose == VerificationPurpose.signup) {
        final t = map['emailVerificationToken']?.toString() ?? '';
        if (t.isEmpty) {
          throw AuthServiceException('Email verification incomplete');
        }
        return (emailVerificationToken: t, resetToken: null);
      }
      final t = map['resetToken']?.toString() ?? '';
      if (t.isEmpty) {
        throw AuthServiceException('Could not continue password reset');
      }
      return (emailVerificationToken: null, resetToken: t);
    } catch (e) {
      final s = e.toString().replaceFirst('Exception: ', '');
      if (s.toLowerCase().contains('invalid') ||
          s.toLowerCase().contains('expired') ||
          s.toLowerCase().contains('too many')) {
        throw AuthServiceException(s);
      }
      _throwFromException(e);
    }
  }

  Future<({String? phoneVerificationToken, String? resetToken})>
      verifyPhoneCode({
    required String phoneDigits,
    required String code,
    required String purpose,
  }) async {
    final d = normalizePhoneDigits(phoneDigits);
    if (!isValidPhoneLength(d)) {
      throw AuthServiceException('Invalid phone number');
    }
    final c = code.trim();
    if (c.isEmpty) {
      throw AuthServiceException('Enter the verification code');
    }
    try {
      final map = await _api.verifyPhoneVerificationCode(
        phoneDigits: d,
        code: c,
        purpose: purpose,
      );
      if (map['verified'] != true) {
        throw AuthServiceException('Invalid verification code');
      }
      if (purpose == VerificationPurpose.signup) {
        final t = map['phoneVerificationToken']?.toString() ?? '';
        if (t.isEmpty) {
          throw AuthServiceException('Phone verification incomplete');
        }
        return (phoneVerificationToken: t, resetToken: null);
      }
      final t = map['resetToken']?.toString() ?? '';
      if (t.isEmpty) {
        throw AuthServiceException('Could not continue password reset');
      }
      return (phoneVerificationToken: null, resetToken: t);
    } catch (e) {
      final s = e.toString().replaceFirst('Exception: ', '');
      if (s.toLowerCase().contains('invalid') ||
          s.toLowerCase().contains('expired') ||
          s.toLowerCase().contains('too many')) {
        throw AuthServiceException(s);
      }
      _throwFromException(e);
    }
  }

  Future<Map<String, dynamic>> completePasswordReset({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      throw AuthServiceException('Passwords do not match');
    }
    return _api.resetPassword(token: resetToken, newPassword: newPassword);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _api.login(email.trim().toLowerCase(), password);
  }

  /// Shows dev code in debug console only — never user-facing for production builds.
  static void logDevCodeIfAny(String? devCode) {
    if (!kDebugMode || devCode == null || devCode.isEmpty) return;
    // ignore: avoid_print
    print('[CareLink dev] Server returned verification code (dev only): $devCode');
  }
}
