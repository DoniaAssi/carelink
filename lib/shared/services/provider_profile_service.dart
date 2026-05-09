import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/provider_profile.dart';
import 'package:carelink/shared/services/api_service.dart';

class ProviderProfileService {
  static const String _phpBaseUrl = 'http://127.0.0.1/carelink';

  static String get baseUrl => ApiService.baseUrl;

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
      // ignore: avoid_print
      print('Get provider profile (PHP) error: $e');
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
      // ignore: avoid_print
      print('Get provider profile error: $e');
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
      // ignore: avoid_print
      print('Update provider profile error: $e');
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
        body: jsonEncode({
          'name': documentName,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Upload certification error: $e');
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
          return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Get availability error: $e');
    }
    return [];
  }

  static Future<bool> saveAvailability(
    String providerId,
    List<Map<String, dynamic>> slots,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/nurse/availability/$providerId'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({'slots': slots}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      // ignore: avoid_print
      print('Save availability failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      // ignore: avoid_print
      print('Save availability error: $e');
    }
    return false;
  }
}
