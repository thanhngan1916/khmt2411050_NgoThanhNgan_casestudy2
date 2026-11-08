
import 'package:flutter/material.dart';

import '../../models/notification.dart';
import '../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/task_service.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifications = await _service.getNotifications();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
  Future<void> _openTaskFromNotification(
      AppNotification notification,
      ) async {
    if (notification.taskId == null ||
        notification.taskId!.isEmpty) {
      _showMessage('Không tìm thấy công việc liên quan');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        _showMessage('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
        return;
      }

      final task = await TaskService().getTaskDetail(
        token: token,
        taskId: notification.taskId!,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(task: task),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    try {
      await _service.markAsRead(notification.id);

      if (!mounted) return;

      setState(() {
        final index = _notifications.indexWhere(
              (item) => item.id == notification.id,
        );

        if (index != -1) {
          final old = _notifications[index];

          _notifications[index] = AppNotification(
            id: old.id,
            taskId: old.taskId,
            type: old.type,
            title: old.title,
            message: old.message,
            isRead: true,
            createdAt: old.createdAt,
            taskTitle: old.taskTitle,
            taskStatus: old.taskStatus,
          );
        }
      });
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _service.markAllAsRead();

      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((item) {
          return AppNotification(
            id: item.id,
            taskId: item.taskId,
            type: item.type,
            title: item.title,
            message: item.message,
            isRead: true,
            createdAt: item.createdAt,
            taskTitle: item.taskTitle,
            taskStatus: item.taskStatus,
          );
        }).toList();
      });

      _showMessage('Đã đánh dấu tất cả thông báo là đã đọc');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'TASK_ASSIGNED':
        return Icons.assignment_ind_outlined;
      case 'TASK_SHARED':
        return Icons.share_outlined;
      case 'TASK_STATUS_CHANGED':
        return Icons.sync_alt;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((item) => !item.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadNotifications,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _notifications.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(
              child: Text('Bạn chưa có thông báo nào'),
            ),
          ],
        )
            : ListView.separated(
          itemCount: _notifications.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1),
          itemBuilder: (context, index) {
            final notification = _notifications[index];

            return ListTile(
              tileColor: notification.isRead
                  ? null
                  : Colors.deepPurple.withValues(
                alpha: 0.07,
              ),
              leading: CircleAvatar(
                backgroundColor:
                Colors.deepPurple.withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  _getIcon(notification.type),
                  color: Colors.deepPurple,
                ),
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notification.message),
                  const SizedBox(height: 6),
                  if (notification.taskTitle != null)
                    Text(
                      'Công việc: ${notification.taskTitle}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: notification.isRead
                  ? const Icon(
                Icons.check_circle,
                color: Colors.green,
              )
                  : const Icon(
                Icons.circle,
                color: Colors.deepPurple,
                size: 12,
              ),
              isThreeLine: true,
              onTap: () async {
                await _markAsRead(notification);

                if (!mounted) return;

                await _openTaskFromNotification(notification);
              },
            );
          },
        ),
      ),
    );
  }
}
