class TaskActivity {
  final String id;
  final String action;
  final String userName;
  final String message;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  TaskActivity({
    required this.id,
    required this.action,
    required this.userName,
    required this.message,
    required this.details,
    this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    final user = json['userId'];

    final details = json['details'] is Map
        ? Map<String, dynamic>.from(json['details'])
        : <String, dynamic>{};

    return TaskActivity(
      id: json['_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      userName: user is Map
          ? user['fullName']?.toString() ?? 'Người dùng'
          : 'Người dùng',
      message: details['message']?.toString() ?? '',
      details: details,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}