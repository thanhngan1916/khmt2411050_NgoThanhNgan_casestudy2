// Thông tin người phụ trách công việc
class TaskAssignee {
  final String id;
  final String fullName;

  TaskAssignee({
    required this.id,
    required this.fullName,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fullName: json['fullName']?.toString() ?? '',
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String taskType;

  // Danh sách người được giao phụ trách công việc
  final List<TaskAssignee> assignedTo;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.startDate,
    this.dueDate,
    this.priority = 'Trung bình',
    this.status = 'Chưa thực hiện',
    this.taskType = 'Được tạo',
    this.assignedTo = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',

      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,

      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,

      priority: json['priority']?.toString() ?? 'Trung bình',
      status: json['status']?.toString() ?? 'Chưa thực hiện',
      taskType: json['taskType']?.toString() ?? 'Được tạo',

      // Đọc danh sách người phụ trách từ API
      assignedTo: (json['assignedTo'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => TaskAssignee.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'status': status,
      'assignedTo': assignedTo.map((item) => item.id).toList(),
    };
  }
}