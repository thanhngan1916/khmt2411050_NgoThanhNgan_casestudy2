
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';

class ChangePrimaryAssigneeScreen extends StatefulWidget {
  final Task task;

  const ChangePrimaryAssigneeScreen({
    super.key,
    required this.task,
  });

  @override
  State<ChangePrimaryAssigneeScreen> createState() =>
      _ChangePrimaryAssigneeScreenState();
}

class _ChangePrimaryAssigneeScreenState
    extends State<ChangePrimaryAssigneeScreen> {
  final TaskService _taskService = TaskService();

  String? _selectedAssigneeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Lấy người phụ trách chính hiện tại.
    final currentId = widget.task.primaryAssigneeId;

    // Kiểm tra người phụ trách chính có trong danh sách được giao không.
    final exists = widget.task.assignedTo.any(
          (user) => user.id == currentId,
    );

    if (exists) {
      _selectedAssigneeId = currentId;
    } else if (widget.task.assignedTo.isNotEmpty) {
      _selectedAssigneeId = widget.task.assignedTo.first.id;
    }
  }

  Future<void> _changePrimaryAssignee() async {
    if (_selectedAssigneeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn người phụ trách chính.'),
        ),
      );
      return;
    }

    if (_selectedAssigneeId == widget.task.primaryAssigneeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Người này đang là người phụ trách chính.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      await _taskService.updatePrimaryAssignee(
        token: token,
        taskId: widget.task.id,
        userId: _selectedAssigneeId!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thay đổi người phụ trách chính thành công.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignees = widget.task.assignedTo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thay đổi người phụ trách chính'),
      ),
      body: assignees.isEmpty
          ? const Center(
        child: Text(
          'Công việc chưa có người được giao.',
        ),
      )
          : Column(
        children: [
          // Thông tin công việc
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CÔNG VIỆC',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chọn người phụ trách chính mới trong '
                      'danh sách người đã được giao.',
                ),
              ],
            ),
          ),

          const Divider(),

          // Danh sách người được giao
          Expanded(
            child: RadioGroup<String>(
              groupValue: _selectedAssigneeId,
              onChanged: (value) {
                if (_isSaving) return;

                setState(() {
                  _selectedAssigneeId = value;
                });
              },
              child: ListView.builder(
                itemCount: assignees.length,
                itemBuilder: (context, index) {
                  final user = assignees[index];

                  final isCurrentPrimary =
                      user.id == widget.task.primaryAssigneeId;

                  return RadioListTile<String>(
                    value: user.id,
                    title: Text(user.fullName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.email.isNotEmpty)
                          Text(user.email),
                        if (isCurrentPrimary)
                          const Text(
                            'Người phụ trách chính hiện tại',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    secondary: Icon(
                      Icons.star,
                      color: _selectedAssigneeId == user.id
                          ? Colors.orange
                          : Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),

          // Nút xác nhận
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : _changePrimaryAssignee,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Xác nhận thay đổi',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
