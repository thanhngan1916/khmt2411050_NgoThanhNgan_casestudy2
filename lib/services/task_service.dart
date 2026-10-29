import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<List<Task>> getTasks({
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> tasks = data['tasks'] ?? [];

      return tasks
          .map((item) => Task.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Phiên đăng nhập hết hạn hoặc không hợp lệ.');
    }

    throw Exception(
      'Không thể tải danh sách công việc. Mã lỗi: ${response.statusCode}',
    );
  }


  Future<Task> createTask({
    required String token,
    required String title,
    required String description,
    required String priority,
    String status = 'Chưa thực hiện',
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks');

    final body = {
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      if (startDate != null)
        'startDate': startDate.toIso8601String(),
      if (dueDate != null)
        'dueDate': dueDate.toIso8601String(),
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    // Kiểm tra phản hồi từ Backend
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Backend trả về dữ liệu không hợp lệ. '
            'Mã lỗi: ${response.statusCode}. '
            'Nội dung: ${response.body}',
      );
    }

    if (response.statusCode == 201) {
      if (data is Map<String, dynamic> &&
          data['task'] is Map<String, dynamic>) {
        return Task.fromJson(data['task'] as Map<String, dynamic>);
      }

      throw Exception(
        'Tạo công việc thành công nhưng dữ liệu trả về '
            'không có trường task. Nội dung: ${response.body}',
      );
    }

    final message = data is Map<String, dynamic>
        ? data['message']?.toString()
        : null;

    throw Exception(
      message ?? 'Không thể tạo công việc. '
          'Mã lỗi: ${response.statusCode}',
    );
  }


  Future<Task> updateTask({
    required String token,
    required String id,
    required String title,
    String description = '',
    DateTime? startDate,
    DateTime? dueDate,
    String priority = 'Trung bình',
    String status = 'Chưa thực hiện',
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$id');

    final body = {
      'title': title,
      'description': description,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'status': status,
    };

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final taskData = data['task'] ?? data;
      return Task.fromJson(taskData as Map<String, dynamic>);
    }

    throw Exception(
      data['message'] ?? 'Không thể cập nhật công việc.',
    );
  }

  Future<void> deleteTask({
    required String token,
    required String id,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$id');

    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      data['message'] ?? 'Không thể xóa công việc.',
    );
  }
}