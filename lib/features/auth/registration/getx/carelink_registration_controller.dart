import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:carelink/features/auth/registration/getx/carelink_registration_models.dart';
import 'package:carelink/features/auth/services/auth_service.dart';
import 'package:carelink/shared/models/user.dart';

class CarelinkRegistrationController extends GetxController {
  CarelinkRegistrationController({AuthService? api})
    : _api = api ?? AuthService();

  final AuthService _api;

  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final pinController = TextEditingController();
  final addressText = TextEditingController();
  final dateOfBirth = TextEditingController();
  final chronicDiseases = TextEditingController();
  final allergies = TextEditingController();
  final currentMedications = TextEditingController();
  final specialization = TextEditingController();
  final licenseNumber = TextEditingController();
  final experienceYears = TextEditingController();
  final serviceType = TextEditingController();

  final stepIndex = 0.obs;
  final isBusy = false.obs;
  final errorText = RxnString();
  final resendSeconds = 0.obs;

  CarelinkRegistrationRole role = CarelinkRegistrationRole.patient;
  String gender = 'prefer_not_to_say';
  double? gpsLat;
  double? gpsLng;

  Timer? _resendTimer;
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  void setRole(CarelinkRegistrationRole value) {
    role = value;
    update();
  }

  void setGender(String value) {
    gender = value;
    update();
  }

  void setLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    addressText.text = address;
    gpsLat = latitude;
    gpsLng = longitude;
    update();
  }

  /// Web-safe read; [TextEditingController.text] can misbehave if disposed.
  static String safeControllerText(TextEditingController? c) {
    if (c == null) return '';
    try {
      return _safeString(c.text, '');
    } catch (_) {
      return '';
    }
  }

  static String _safeString(Object? o, String fallback) {
    if (o == null) return fallback;
    if (o is String) return o;
    try {
      return o.toString();
    } catch (_) {
      return fallback;
    }
  }

  /// Strips non-digits; accepts any object (web may pass odd validator values).
  static String digitsOnly(Object? raw) {
    try {
      final s = _safeString(raw, '');
      return s.replaceAll(RegExp(r'\D'), '');
    } catch (_) {
      return '';
    }
  }

  String _digitsFromPhone() => digitsOnly(safeControllerText(phone));

  bool _validateStep1Fields() {
    try {
      final name = safeControllerText(fullName).trim();
      if (name.length < 2) {
        errorText.value = 'Please enter your full name';
        return false;
      }
      final mail = safeControllerText(email).trim();
      if (mail.isNotEmpty && !_emailRegex.hasMatch(mail)) {
        errorText.value = 'Invalid email or leave empty';
        return false;
      }
      final d = _digitsFromPhone();
      if (d.isEmpty || d.length < 8 || d.length > 15) {
        errorText.value = 'Enter a valid phone number (8–15 digits)';
        return false;
      }
      if (safeControllerText(password).length < 8) {
        errorText.value = 'Password must be at least 8 characters';
        return false;
      }
      if (role == CarelinkRegistrationRole.patient) {
        if (safeControllerText(addressText).trim().length < 3) {
          errorText.value = 'Please enter your address';
          return false;
        }
      } else {
        if (safeControllerText(specialization).trim().length < 2) {
          errorText.value = 'Please enter your specialization';
          return false;
        }
        if (safeControllerText(licenseNumber).trim().length < 3) {
          errorText.value = 'Please enter your license number';
          return false;
        }
        final exp = safeControllerText(experienceYears).trim();
        if (exp.isNotEmpty) {
          final n = int.tryParse(exp);
          if (n == null || n < 0 || n > 80) {
            errorText.value = 'Experience must be between 0 and 80 years';
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      errorText.value = 'Please check your details and try again';
      return false;
    }
  }

  Future<void> submitSendOtp() async {
    errorText.value = null;
    if (!_validateStep1Fields()) return;

    isBusy.value = true;
    try {
      final digits = _digitsFromPhone();
      if (digits.isEmpty) {
        errorText.value = 'Enter a valid phone number (8–15 digits)';
        return;
      }
      await _api.sendOtp(phoneDigits: digits);
      pinController.clear();
      stepIndex.value = 1;
      _startResendCountdown(59);
    } on AuthApiException catch (e) {
      errorText.value = e.message;
    } catch (e) {
      errorText.value = e.toString();
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (resendSeconds.value > 0) return;
    errorText.value = null;
    isBusy.value = true;
    try {
      final digits = _digitsFromPhone();
      if (digits.isEmpty) {
        errorText.value = 'Enter a valid phone number (8–15 digits)';
        return;
      }
      await _api.sendOtp(phoneDigits: digits);
      _startResendCountdown(59);
    } on AuthApiException catch (e) {
      errorText.value = e.message;
    } catch (e) {
      errorText.value = e.toString();
    } finally {
      isBusy.value = false;
    }
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    resendSeconds.value = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSeconds.value <= 0) {
        t.cancel();
        return;
      }
      resendSeconds.value = resendSeconds.value - 1;
    });
  }

  void goBackToStep1() {
    if (stepIndex.value == 0) return;
    stepIndex.value = 0;
    _resendTimer?.cancel();
    resendSeconds.value = 0;
    pinController.clear();
    errorText.value = null;
  }

  /// Returns parsed [User] on success; `null` on validation / API error.
  Future<User?> submitRegister() async {
    final otp = safeControllerText(pinController).trim();
    if (otp.length != 6) {
      errorText.value = 'Enter the 6-digit code';
      return null;
    }
    errorText.value = null;
    isBusy.value = true;
    try {
      final body = await _api.register(
        fullName: safeControllerText(fullName).trim(),
        email: safeControllerText(email).trim(),
        phoneDigits: _digitsFromPhone(),
        password: safeControllerText(password),
        role: role.apiValue,
        otp: otp,
        addressText: safeControllerText(addressText).trim(),
        dateOfBirth: safeControllerText(dateOfBirth).trim(),
        gender: role == CarelinkRegistrationRole.patient ? gender : null,
        chronicDiseases: safeControllerText(chronicDiseases).trim(),
        allergies: safeControllerText(allergies).trim(),
        currentMedications: safeControllerText(currentMedications).trim(),
        specialization: safeControllerText(specialization).trim(),
        licenseNumber: safeControllerText(licenseNumber).trim(),
        experienceYears: safeControllerText(experienceYears).trim(),
        serviceType: safeControllerText(serviceType).trim(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
      );
      final raw = _extractUserMap(body);
      if (raw == null) {
        errorText.value = 'Registration succeeded but user payload was missing';
        return null;
      }
      return User.fromJson(raw);
    } on AuthApiException catch (e) {
      errorText.value = e.message;
      return null;
    } catch (e) {
      errorText.value = e.toString();
      return null;
    } finally {
      isBusy.value = false;
    }
  }

  Map<String, dynamic>? _extractUserMap(Map<String, dynamic> body) {
    final u = body['user'] ?? body['data'];
    if (u is Map<String, dynamic>) return u;
    if (body.containsKey('id') ||
        body.containsKey('userId') ||
        body.containsKey('email')) {
      return body;
    }
    return null;
  }

  String formattedPhoneDisplay() {
    try {
      final d = _digitsFromPhone();
      if (d.length >= 10) {
        return '${d.substring(0, 3)} ${d.substring(3)}';
      }
      return d.isEmpty ? '—' : d;
    } catch (_) {
      return '—';
    }
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    fullName.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    pinController.dispose();
    addressText.dispose();
    dateOfBirth.dispose();
    chronicDiseases.dispose();
    allergies.dispose();
    currentMedications.dispose();
    specialization.dispose();
    licenseNumber.dispose();
    experienceYears.dispose();
    serviceType.dispose();
    super.onClose();
  }
}
