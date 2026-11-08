
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../assignment/assign_task_screen.dart';
import 'task_share_screen.dart';
import 'email_history_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TaskService _taskService = TaskService();

  bool _isDeleting = false;
  bool _isUpdating = false;

  bool _isLoadingMembers = true;

  List<TaskAssignee> _assignees = [];
  List<dynamic> _shares = [];

  Task get task => widget.task;
  @override
  void initState() {
    super.initState();
    _loadMembers();
  }
  // Tải danh sách người được giao và người được chia sẻ
  Future<void> _loadMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      final assignees = await _taskService.getTaskAssignees(
        token: token,
        taskId: task.id,
      );

      final shares = await _taskService.getTaskShares(
        token: token,
        taskId: task.id,
      );

      if (!mounted) return;

      setState(() {
        _assignees = assignees;
        _shares = shares;
        _isLoadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMembers = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải danh sách thành viên: $e'),
        ),
      );
    }
  }

  // THÔNG BÁO KHI KHÔNG CÓ QUYỀN CHỈNH SỬA
  Future<void> _showPermissionDeniedDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.lock_outline,
            color: Colors.orange,
            size: 40,
          ),
          title: const Text(
            'Không thể chỉnh sửa',
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // HÀM MỞ MÀN HÌNH GIAO VIỆC
  Future<void> _openAssignTaskScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AssignTaskScreen(
          task: task,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }
  // HÀM MỞ MÀN HÌNH CHIA SẺ CÔNG VIỆC
  Future<void> _openTaskShareScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskShareScreen(
          task: task,
        ),
      ),
    );
  }
  void _openEmailHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailHistoryScreen(
          taskId: widget.task.id.toString(),
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // HIỂN THỊ DANH SÁCH NGƯỜI ĐƯỢC GIAO VÀ NGƯỜI ĐƯỢC CHIA SẺ
  Widget _buildMembersSection() {
    if (_isLoadingMembers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),

        // Danh sách người được giao
        const Text(
          'Người được giao',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        if (_assignees.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Chưa có người được giao'),
          )
        else
          ..._assignees.map((assignee) {
            final isPrimary = task.primaryAssigneeId == assignee.id;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(assignee.fullName),
              subtitle: Text(assignee.email),
              trailing: isPrimary
                  ? const Chip(
                label: Text('Phụ trách chính'),
              )
                  : null,
            );
          }),

        const Divider(height: 28),

        // Danh sách người được chia sẻ
        const Text(
          'Người được chia sẻ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        if (_shares.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Chưa chia sẻ công việc'),
          )
        else
          ..._shares.map((share) {
            final user = share is Map ? share['userId'] : null;
            final name = user is Map
                ? user['fullName']?.toString() ?? 'Người dùng'
                : 'Người dùng';
            final email = user is Map
                ? user['email']?.toString() ?? ''
                : '';
            final permission = share is Map
                ? share['permission']?.toString() ?? ''
                : '';

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline),
              ),
              title: Text(name),
              subtitle: Text(
                email.isEmpty ? permission : '$email\n$permission',
              ),
            );
          }),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa thiết lập';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // CHỈNH SỬA CÔNG VIỆC
  Future<void> _updateTaskStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      await _taskService.updateTask(
        token: token,
        id: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: newStatus,
        startDate: task.startDate,
        dueDate: task.dueDate,
      );
      if (!mounted) return;

      // Đóng màn hình chi tiết và trả kết quả về danh sách
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      if (error is TaskPermissionException) {
        await _showPermissionDeniedDialog(error.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
// HIỂN THỊ HỘP THOẠI CHỌN TRẠNG THÁI
  Future<void> _showStatusDialog() async {
    String selectedStatus = task.status;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật trạng thái'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Chưa thực hiện'),
                    value: 'Chưa thực hiện',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Đang thực hiện'),
                    value: 'Đang thực hiện',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Đã hoàn thành'),
                    value: 'Đã hoàn thành',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedStatus);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != task.status && mounted) {
      await _updateTaskStatus(result);
    }
  }
  // CHỈNH SỬA THÔNG TIN CÔNG VIỆC

  Future<void> _editTask() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _EditTaskDialog(task: task);
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      await _taskService.updateTask(
        token: token,
        id: task.id,
        title: result['title'] as String,
        description: result['description'] as String,
        priority: result['priority'] as String,
        status: task.status,
        startDate: result['startDate'] as DateTime?,
        dueDate: result['dueDate'] as DateTime?,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      if (error is TaskPermissionException) {
        await _showPermissionDeniedDialog(error.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $error')),
        );
      }
    }
  }
  // XÁC NHẬN XÓA
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa công việc'),
          content: Text(
            'Bạn có chắc chắn muốn xóa công việc "${task.title}" không? '
                'Thao tác này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _deleteTask();
    }
  }

  // XÓA CÔNG VIỆC
  Future<void> _deleteTask() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      await _taskService.deleteTask(
        token: token,
        id: task.id,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 28),
                _buildInfo(
                  'Tên công việc',
                  task.title,
                  Icons.task_alt,
                ),
                _buildInfo(
                  'Mô tả',
                  task.description.isEmpty
                      ? 'Không có mô tả'
                      : task.description,
                  Icons.description,
                ),
                _buildInfo(
                  'Ngày hết hạn',
                  _formatDate(task.dueDate),
                  Icons.calendar_today,
                ),
                _buildInfo(
                  'Mức độ ưu tiên',
                  task.priority,
                  Icons.flag,
                ),
                _buildInfo(
                  'Trạng thái',
                  task.status,
                  Icons.check_circle_outline,
                ),
                _buildInfo(
                  'Loại công việc',
                  task.taskType,
                  Icons.category,
                ),

// HIỂN THỊ NGƯỜI ĐƯỢC GIAO VÀ NGƯỜI ĐƯỢC CHIA SẺ
                _buildMembersSection(),

                const SizedBox(height: 20),

// NÚT XEM LỊCH SỬ GỬI EMAIL
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _openEmailHistoryScreen,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Lịch sử gửi email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // NÚT GIAO CÔNG VIỆC
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _openAssignTaskScreen,
                    icon: const Icon(Icons.people_alt),
                    label: const Text('Giao công việc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // NÚT CHIA SẺ CÔNG VIỆC
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _openTaskShareScreen,
                    icon: const Icon(Icons.share),
                    label: const Text('Chia sẻ công việc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // NÚT CHỈNH SỬA CÔNG VIỆC
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _editTask,
                    icon: const Icon(Icons.edit),
                    label: const Text('Chỉnh sửa công việc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),


                // NÚT CẬP NHẬT TRẠNG THÁI
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _showStatusDialog,
                    icon: const Icon(Icons.sync),
                    label: const Text('Cập nhật trạng thái'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // NÚT XÓA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isDeleting || _isUpdating)
                        ? null
                        : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.delete),
                    label: Text(
                      _isDeleting ? 'Đang xóa...' : 'Xóa công việc',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _EditTaskDialog extends StatefulWidget {
  final Task task;

  const _EditTaskDialog({required this.task});

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  late String priority;
  DateTime? startDate;
  DateTime? dueDate;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.task.title);
    descriptionController =
        TextEditingController(text: widget.task.description);

    priority = ['Thấp', 'Trung bình', 'Cao']
        .contains(widget.task.priority)
        ? widget.task.priority
        : 'Trung bình';

    startDate = widget.task.startDate;
    dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      startDate = selected;
      if (dueDate != null && dueDate!.isBefore(selected)) {
        dueDate = null;
      }
    });
  }

  Future<void> pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate ?? startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      dueDate = selected;
    });
  }

  void save() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên công việc'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'priority': priority,
      'startDate': startDate,
      'dueDate': dueDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa công việc'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Tên công việc',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: 'Mức độ ưu tiên',
                border: OutlineInputBorder(),
              ),
              items: ['Thấp', 'Trung bình', 'Cao']
                  .map((value) => DropdownMenuItem(
                value: value,
                child: Text(value),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    priority = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickStartDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                startDate == null
                    ? 'Chọn ngày bắt đầu'
                    : 'Ngày bắt đầu: ${formatDate(startDate)}',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickDueDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                dueDate == null
                    ? 'Chọn ngày hết hạn'
                    : 'Hạn: ${formatDate(dueDate)}',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

