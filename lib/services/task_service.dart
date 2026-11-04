import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskPermissionException implements Exception {
  final String message;

  TaskPermissionException(this.message);

  @override
  String toString() => message;
}
class TaskService {
  static const String baseUrl = 'http://10.0.2.2:3000';



  Future<List<Task>> getTasks({
    required String token,
    String sortBy = 'createdAt',
    String order = 'desc',
    String scope = 'all',
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks').replace(
      queryParameters: {
        'sortBy': sortBy,
        'order': order,
        'scope': scope,
      },
    );

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

  // ================= CHIA SẺ CÔNG VIỆC =================

// 1. Chia sẻ công việc cho một hoặc nhiều người
  Future<void> shareTask({
    required String token,
    required String taskId,
    required List<String> userIds,
    required String permission,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$taskId/shares');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userIds': userIds,
        'permission': permission,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return;
    }

    throw Exception(
      data['message'] ?? 'Không thể chia sẻ công việc.',
    );
  }

// 2. Lấy danh sách người được chia sẻ
  Future<List<dynamic>> getTaskShares({
    required String token,
    required String taskId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$taskId/shares');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['shares'] ?? [];
    }

    throw Exception(
      data['message'] ?? 'Không thể lấy danh sách chia sẻ.',
    );
  }
  // Lấy danh sách người được giao phụ trách công việc
  Future<List<TaskAssignee>> getTaskAssignees({
    required String token,
    required String taskId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/tasks/$taskId/assignees',
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Backend trả về dữ liệu không hợp lệ.');
    }

    if (response.statusCode == 200) {
      final List<dynamic> assignees = data['assignees'] ?? [];

      return assignees
          .whereType<Map<String, dynamic>>()
          .map((item) => TaskAssignee.fromJson(item))
          .toList();
    }

    throw Exception(
      data is Map
          ? data['message'] ?? 'Không thể lấy danh sách người được giao.'
          : 'Không thể lấy danh sách người được giao.',
    );
  }

// 3. Cập nhật quyền chia sẻ
  Future<void> updateTaskShare({
    required String token,
    required String taskId,
    required String shareId,
    required String permission,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/tasks/$taskId/shares/$shareId',
    );

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'permission': permission,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      data['message'] ?? 'Không thể cập nhật quyền chia sẻ.',
    );
  }

// 4. Thu hồi quyền chia sẻ
  Future<void> deleteTaskShare({
    required String token,
    required String taskId,
    required String shareId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/tasks/$taskId/shares/$shareId',
    );

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
      data['message'] ?? 'Không thể thu hồi quyền chia sẻ.',
    );
  }
  Future<void> assignTask({
    required String token,
    required String taskId,
    required List<String> assigneeIds,
    required String primaryAssigneeId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/tasks/$taskId/assignees',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'assigneeIds': assigneeIds,
        'primaryAssigneeId': primaryAssigneeId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      data['message'] ?? 'Không thể giao công việc.',
    );
  }
  // CẬP NHẬT NGƯỜI PHỤ TRÁCH CHÍNH
  Future<void> updatePrimaryAssignee({
    required String token,
    required String taskId,
    required String userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/tasks/$taskId/assignees/$userId',
    );

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Backend trả về dữ liệu không hợp lệ.');
    }

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      data is Map
          ? data['message'] ?? 'Không thể cập nhật người phụ trách chính.'
          : 'Không thể cập nhật người phụ trách chính.',
    );
  }

  Future<List<TaskAssignee>> getUsers({
    required String token,
    String keyword = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/users/search').replace(
      queryParameters: {
        'q': keyword.trim().isEmpty ? 'an' : keyword.trim(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> users = data['users'] ?? [];

      return users
          .map((item) => TaskAssignee.fromJson(
        item as Map<String, dynamic>,
      ))
          .toList();
    }

    throw Exception(
      data['message'] ??
          'Không thể tìm kiếm người dùng. Mã lỗi: ${response.statusCode}',
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
    List<String> assignedTo = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks');

    final body = {
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'assignedTo': assignedTo,
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
        return Task.fromJson(
          data['task'] as Map<String, dynamic>,
        );
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

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Backend trả về dữ liệu không hợp lệ.');
    }

    if (response.statusCode == 200) {
      final taskData = data['task'] ?? data;
      return Task.fromJson(
        taskData as Map<String, dynamic>,
      );
    }

// Người dùng không có quyền chỉnh sửa
    if (response.statusCode == 403) {
      final message = data is Map
          ? data['message']?.toString()
          : null;

      throw TaskPermissionException(
        message ?? 'Bạn không có quyền chỉnh sửa công việc này.',
      );
    }

    throw Exception(
      data is Map
          ? data['message'] ?? 'Không thể cập nhật công việc.'
          : 'Không thể cập nhật công việc.',
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