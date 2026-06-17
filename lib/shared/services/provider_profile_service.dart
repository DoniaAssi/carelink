import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/api_service.dart';

class ProviderProfileService {
  static const String _phpBaseUrl = 'http://127.0.0.1/carelink';

  static String get baseUrl => ApiService.baseUrl;
  static String? lastError;

  static void _logError(String message) {
    if (kDebugMode) {
      debugPrint('[ProviderProfileService] $message');
    }
  }

  /// Patient app: legacy PHP provider profile (unchanged path).
  static Future<ProviderProfile?> getProfileLegacy(int providerId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_phpBaseUrl/api/provider/profile.php?providerId=$providerId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ProviderProfile.fromJson(
            Map<String, dynamic>.from(data['profile'] as Map),
          );
        }
      }
    } catch (e) {
      _logError('Error message: $e');
    }
    return null;
  }

  /// Nurse app: REST profile on the Node API.
  static Future<ProviderProfile?> getProfile(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/profile/$providerId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProviderProfile.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      _logError('Error message: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(ProviderProfile profile) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/profile/${profile.providerId}'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      _logError('Error message: $e');
    }
    return false;
  }

  static Future<bool> uploadCertification(
    String providerId,
    String documentName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nurse/certifications/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({'name': documentName}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      _logError('Error message: $e');
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getAvailability(
    String providerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nurse/availability/$providerId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
    } catch (e) {
      _logError('Error message: $e');
    }
    return [];
  }

  static Future<bool> saveAvailability(
    String providerId,
    List<Map<String, dynamic>> slots,
  ) async {
    lastError = null;
    await _publishProviderAvailability(providerId, slots.isNotEmpty);
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/availability/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({'slots': slots}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      lastError =
          _responseError(response.body) ?? 'HTTP ${response.statusCode}';
      final fallbackSaved = await _saveAvailabilityThroughSchedule(
        providerId,
        slots,
      );
      if (fallbackSaved) {
        return true;
      }
      _logError(
        'Request URL: ${response.request?.url} | HTTP method: PUT | '
        'Status code: ${response.statusCode} | Error message: ${lastError ?? 'Save availability failed'}',
      );
    } catch (e) {
      lastError = e.toString();
      final fallbackSaved = await _saveAvailabilityThroughSchedule(
        providerId,
        slots,
      );
      if (fallbackSaved) {
        return true;
      }
      _logError('Error message: $e');
    }
    return false;
  }

  static Future<void> _publishProviderAvailability(
    String providerId,
    bool isAvailable,
  ) async {
    final cleanProviderId = providerId.trim();
    if (cleanProviderId.isEmpty) {
      return;
    }

    try {
      await http.put(
        Uri.parse('$baseUrl/nurse/profile/$cleanProviderId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': cleanProviderId,
          'specialization': 'Home Nursing',
          'serviceType': 'Home visit',
          'bio': 'Home Nursing',
          'isAvailable': isAvailable,
        }),
      );
    } catch (e) {
      _logError('Availability publish failed: $e');
    }
  }

  static Future<bool> _saveAvailabilityThroughSchedule(
    String providerId,
    List<Map<String, dynamic>> slots,
  ) async {
    final cleanProviderId = providerId.trim();
    if (cleanProviderId.isEmpty) {
      lastError = 'Missing provider id';
      return false;
    }

    var clearedExistingSlots = false;
    try {
      final existingResponse = await http.get(
        Uri.parse('$baseUrl/doctor/schedule/$cleanProviderId'),
      );
      if (existingResponse.statusCode >= 200 &&
          existingResponse.statusCode < 300) {
        final data = jsonDecode(existingResponse.body);
        if (data is List) {
          for (final item in data) {
            if (item is! Map) {
              continue;
            }
            final slotId = (item['slot_id'] ?? item['slotId'] ?? '').toString();
            if (slotId.isEmpty) {
              continue;
            }
            await http.delete(
              Uri.parse('$baseUrl/doctor/schedule/$cleanProviderId/$slotId'),
            );
          }
        }
        clearedExistingSlots = true;
      }
    } catch (e) {
      _logError('Schedule fallback cleanup failed: $e');
    }

    if (slots.isEmpty) {
      if (clearedExistingSlots) {
        lastError = null;
      }
      return clearedExistingSlots;
    }

    var savedAnySlot = false;
    for (final slot in slots) {
      final day = (slot['day'] ?? '').toString().trim();
      final startTime = (slot['startTime'] ?? slot['start'] ?? '')
          .toString()
          .trim();
      final endTime = (slot['endTime'] ?? slot['end'] ?? '').toString().trim();
      if (day.isEmpty || startTime.isEmpty || endTime.isEmpty) {
        continue;
      }

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/doctor/schedule/$cleanProviderId'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode({
            'day': day,
            'startTime': startTime,
            'endTime': endTime,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          savedAnySlot = true;
        } else {
          lastError =
              _responseError(response.body) ?? 'HTTP ${response.statusCode}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (savedAnySlot) {
      lastError = null;
    }
    return savedAnySlot;
  }

  static String? _responseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? null : body.trim();
  }
}
