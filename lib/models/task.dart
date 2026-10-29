
class Task {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String taskType;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.priority = 'Trung bình',
    this.status = 'Chưa thực hiện',
    this.taskType = 'Được tạo',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      priority: json['priority']?.toString() ?? 'Trung bình',
      status: json['status']?.toString() ?? 'Chưa thực hiện',
      taskType: json['taskType']?.toString() ?? 'Được tạo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'status': status,
    };
  }
}
