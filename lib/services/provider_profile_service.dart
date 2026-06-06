import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/provider_profile.dart';

class ProviderProfileService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  static Future<ProviderProfile?> getProfile(int providerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/profile.php?providerId=$providerId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return ProviderProfile.fromJson(data['profile']);
        }
      }
    } catch (e) {
      print('Get provider profile error: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(ProviderProfile profile) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/update_profile.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Update provider profile error: $e');
    }
    return false;
  }

  static Future<bool> uploadCertification(int providerId, String documentName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/upload_certification.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': providerId,
          'documentName': documentName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
    } catch (e) {
      print('Upload certification error: $e');
    }
    return false;
  }
}
