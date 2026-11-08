
class AppNotification {
  final String id;
  final String? taskId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? taskTitle;
  final String? taskStatus;

  AppNotification({
    required this.id,
    this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.taskTitle,
    this.taskStatus,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final task = json['taskId'];

    return AppNotification(
      id: json['_id']?.toString() ?? '',
      taskId: task is Map
          ? task['_id']?.toString()
          : task?.toString(),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      ) ??
          DateTime.now(),
      taskTitle: task is Map
          ? task['title']?.toString()
          : null,
      taskStatus: task is Map
          ? task['status']?.toString()
          : null,
    );
  }
}
