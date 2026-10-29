
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';

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

  Task get task => widget.task;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $error')),
      );
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
    final titleController = TextEditingController(text: task.title);
    final descriptionController =
    TextEditingController(text: task.description);

    String priority = ['Thấp', 'Trung bình', 'Cao'].contains(task.priority)
        ? task.priority
        : 'Trung bình';
    DateTime? startDate = task.startDate;
    DateTime? dueDate = task.dueDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      value: priority,
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
                          setDialogState(() {
                            priority = value;
                          });
                        }
                      },
                    ),
                    // NÚT CHỌN NGÀY BẮT ĐẦU
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          setDialogState(() {
                            startDate = selected;

                            if (dueDate != null &&
                                dueDate!.isBefore(startDate!)) {
                              dueDate = null;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        startDate == null
                            ? 'Chọn ngày bắt đầu'
                            : 'Ngày bắt đầu: ${startDate!.day}/${startDate!.month}/${startDate!.year}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          setDialogState(() {
                            dueDate = selected;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        dueDate == null
                            ? 'Chọn ngày hết hạn'
                            : 'Hạn: ${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên công việc'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'priority': priority,
                      'startDate': startDate,
                      'dueDate': dueDate,
                    });
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $error')),
      );
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
                const SizedBox(height: 20),

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
