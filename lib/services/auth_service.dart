import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  // تسجيل الدخول
  static Future<User?> login(String email, String password, String role) async {
    try {
      print('Attempting login for $email');
      final response = await http.post(
        Uri.parse('$baseUrl/api/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        try {
          final data = jsonDecode(body);
          if (data['success']) {
            return User.fromJson(data['user']);
          }
        } on FormatException catch (e) {
          print('Login parse error: $e');
          print('Login response body: $body');
        }
      } else {
        final body = utf8.decode(response.bodyBytes);
        print('Login response status: ${response.statusCode}');
        print('Login response body: $body');
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // التسجيل
  static Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    String? address,
    String? specialization,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'phone': phone,
          'role': role,
          'address': address,
          'specialization': specialization,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }
}
