import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:carelink/shared/services/api_service.dart';

class PatientFavoritesService {
  static Future<List<Map<String, dynamic>>> getFavorites(String patientUserId) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/patient/favorites/$patientUserId');
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> isFavorite(String patientUserId, String providerId) async {
    final favorites = await getFavorites(patientUserId);
    return favorites.any((element) => element['providerId'] == providerId);
  }

  static Future<void> addFavorite(String patientUserId, String providerId) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/patient/favorites');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patientUserId': patientUserId,
          'providerUserId': providerId,
        }),
      );
    } catch (e) {
      // Ignore error for now
    }
  }

  static Future<void> removeFavorite(String patientUserId, String providerId) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/patient/favorites/$patientUserId/$providerId');
      await http.delete(url, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      // Ignore error for now
    }
  }

  static Future<void> toggleFavorite(String patientUserId, String providerId) async {
    final isFav = await isFavorite(patientUserId, providerId);
    if (isFav) {
      await removeFavorite(patientUserId, providerId);
    } else {
      await addFavorite(patientUserId, providerId);
    }
  }
}

