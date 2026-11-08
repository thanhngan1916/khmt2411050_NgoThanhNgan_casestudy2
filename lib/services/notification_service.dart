
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification.dart';

class NotificationService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Lấy danh sách thông báo
  Future<List<AppNotification>> getNotifications() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List notifications = data['notifications'] ?? [];

      return notifications
          .map(
            (item) => AppNotification.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();
    }

    throw Exception(
      data['message'] ?? 'Không thể tải danh sách thông báo',
    );
  }

  // Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadCount() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications/unread-count'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['unreadCount'] ?? 0;
    }

    throw Exception('Không thể lấy số thông báo chưa đọc');
  }

  // Đánh dấu một thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/notifications/$notificationId/read',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        data['message'] ?? 'Không thể đánh dấu đã đọc',
      );
    }
  }

  // Đánh dấu tất cả thông báo đã đọc
  Future<void> markAllAsRead() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/notifications/read-all'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        data['message'] ?? 'Không thể đánh dấu tất cả đã đọc',
      );
    }
  }
}
