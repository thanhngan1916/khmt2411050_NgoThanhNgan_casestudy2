
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';

class UserService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<User> getProfile(String token) async {
    final response = await http
        .get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final userData = data['user'] as Map<String, dynamic>;
      return User.fromJson(userData);
    }

    throw Exception(
      data['message']?.toString() ??
          'Không thể lấy thông tin cá nhân',
    );
  }
  Future<User> updateProfile({
    required String token,
    required String fullName,
    required String email,
  }) async {
    final response = await http
        .put(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fullName': fullName.trim(),
        'email': email.trim(),
      }),
    )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final userData = data['user'] as Map<String, dynamic>;
      return User.fromJson(userData);
    }

    throw Exception(
      data['message']?.toString() ??
          'Không thể cập nhật thông tin cá nhân',
    );
  }
}
