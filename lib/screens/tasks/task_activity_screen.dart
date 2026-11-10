
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task_activity.dart';
import '../../services/task_service.dart';

class TaskActivityScreen extends StatefulWidget {
  final String taskId;

  const TaskActivityScreen({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskActivityScreen> createState() => _TaskActivityScreenState();
}

class _TaskActivityScreenState extends State<TaskActivityScreen> {
  List<TaskActivity> _activities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      final activities = await TaskService().getTaskActivities(
        token: token,
        taskId: widget.taskId,
      );

      if (!mounted) return;

      setState(() {
        _activities = activities;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return 'Tạo công việc';
      case 'update':
        return 'Chỉnh sửa công việc';
      case 'status_changed':
        return 'Thay đổi trạng thái';
      case 'assign':
        return 'Giao công việc';
      case 'share':
        return 'Chia sẻ công việc';
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_task;
      case 'update':
        return Icons.edit;
      case 'status_changed':
        return Icons.sync;
      case 'assign':
        return Icons.person_add;
      case 'share':
        return Icons.share;
      default:
        return Icons.history;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Không rõ thời gian';

    final localDate = date.toLocal();

    String twoDigits(int value) =>
        value.toString().padLeft(2, '0');

    return '${twoDigits(localDate.day)}/'
        '${twoDigits(localDate.month)}/'
        '${localDate.year} '
        '${twoDigits(localDate.hour)}:'
        '${twoDigits(localDate.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Không thể tải lịch sử: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadActivities();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      )
          : _activities.isEmpty
          ? const Center(
        child: Text('Chưa có lịch sử hoạt động'),
      )
          : RefreshIndicator(
        onRefresh: _loadActivities,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _activities.length,
          itemBuilder: (context, index) {
            final activity = _activities[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                  Colors.deepPurple.shade100,
                  child: Icon(
                    _actionIcon(activity.action),
                    color: Colors.deepPurple,
                  ),
                ),
                title: Text(
                  _actionLabel(activity.action),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (activity.message.isNotEmpty)
                      Text(activity.message),
                    Text('Người thực hiện: ${activity.userName}'),
                    Text(_formatDate(activity.createdAt)),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    );
  }
}
