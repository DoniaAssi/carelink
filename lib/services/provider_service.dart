import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/provider.dart';

class ProviderService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  // الحصول على جميع الأطباء
  static Future<List<Provider>> getProviders({String? specialization, String? role}) async {
    try {
      String url = '$baseUrl/api/providers.php';
      bool first = true;

      if (specialization != null && specialization.isNotEmpty) {
        url += '?specialization=$specialization';
        first = false;
      }

      if (role != null && role.isNotEmpty) {
        url += first ? '?role=$role' : '&role=$role';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          List<Provider> providers = [];
          for (var item in data['providers']) {
            providers.add(Provider.fromJson(item));
          }
          return providers;
        }
      }
      return [];
    } catch (e) {
      print('Get providers error: $e');
      return [];
    }
  }

  // البحث عن الأطباء
  static Future<List<Provider>> searchProviders(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/search_providers.php?q=$query'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          List<Provider> providers = [];
          for (var item in data['providers']) {
            providers.add(Provider.fromJson(item));
          }
          return providers;
        }
      }
      return [];
    } catch (e) {
      print('Search providers error: $e');
      return [];
    }
  }

  // الحصول على طلبات الطبيب
  static Future<List<dynamic>> getProviderRequests(int providerId, {String? status}) async {
    try {
      String url = '$baseUrl/api/provider/requests.php?providerId=$providerId';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['requests'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Get provider requests error: $e');
      return [];
    }
  }
}
