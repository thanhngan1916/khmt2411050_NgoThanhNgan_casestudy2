import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';

class AssignTaskScreen extends StatefulWidget {
  final Task task;

  const AssignTaskScreen({
    super.key,
    required this.task,
  });

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();

  List<TaskAssignee> _searchResults = [];

  // Lưu những người đã chọn, dùng ID làm khóa để tránh trùng.
  final Map<String, TaskAssignee> _selectedUsers = {};

  String? _primaryAssigneeId;

  bool _isSearching = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Giữ lại danh sách người đã được giao trước đó.
    for (final user in widget.task.assignedTo) {
      _selectedUsers[user.id] = user;
    }

    _primaryAssigneeId = widget.task.primaryAssigneeId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // TÌM KIẾM NGƯỜI DÙNG THEO TÊN HOẶC EMAIL
  Future<void> _searchUsers() async {
    final keyword = _searchController.text.trim();

    if (keyword.length < 2) {
      setState(() {
        _error = 'Vui lòng nhập ít nhất 2 ký tự để tìm kiếm.';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      final users = await _taskService.getUsers(
        token: token,
        keyword: keyword,
      );

      if (!mounted) return;

      setState(() {
        _searchResults = users;
        _error = users.isEmpty ? 'Không tìm thấy người dùng.' : null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // CHỌN HOẶC BỎ CHỌN NGƯỜI ĐƯỢC GIAO
  void _toggleUser(TaskAssignee user, bool selected) {
    setState(() {
      if (selected) {
        _selectedUsers[user.id] = user;

        // Nếu chưa có người phụ trách chính thì chọn người đầu tiên.
        _primaryAssigneeId ??= user.id;
      } else {
        _selectedUsers.remove(user.id);

        // Nếu bỏ chọn người phụ trách chính thì xóa lựa chọn đó.
        if (_primaryAssigneeId == user.id) {
          _primaryAssigneeId = _selectedUsers.isEmpty
              ? null
              : _selectedUsers.keys.first;
        }
      }
    });
  }

  // XÁC NHẬN GIAO CÔNG VIỆC
  Future<void> _saveAssignment() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một người được giao.'),
        ),
      );
      return;
    }

    if (_primaryAssigneeId == null ||
        !_selectedUsers.containsKey(_primaryAssigneeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn người phụ trách chính.'),
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

      await _taskService.assignTask(
        token: token,
        taskId: widget.task.id,
        assigneeIds: _selectedUsers.keys.toList(),
        primaryAssigneeId: _primaryAssigneeId!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giao công việc thành công.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $error'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao công việc'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // THÔNG TIN CÔNG VIỆC
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Công việc cần giao',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
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
              ],
            ),
          ),

          // Ô TÌM KIẾM
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchUsers(),
              decoration: InputDecoration(
                hintText: 'Nhập tên hoặc email người dùng',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _isSearching ? null : _searchUsers,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // KẾT QUẢ TÌM KIẾM
          Expanded(
            child: ListView(
              children: [
                if (_searchResults.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Kết quả tìm kiếm',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                ..._searchResults.map((user) {
                  final isSelected =
                  _selectedUsers.containsKey(user.id);

                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(user.fullName),
                    subtitle: Text(user.email),
                    secondary: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    onChanged: (value) {
                      _toggleUser(user, value ?? false);
                    },
                  );
                }),

                const Divider(height: 24),

                // DANH SÁCH NGƯỜI ĐÃ CHỌN
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Danh sách người được giao',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                if (_selectedUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa chọn người được giao.',
                      textAlign: TextAlign.center,
                    ),
                  ),

                ..._selectedUsers.values.map((user) {
                  return RadioListTile<String>(
                    value: user.id,
                    groupValue: _primaryAssigneeId,
                    title: Text(user.fullName),
                    subtitle: Text(
                      '${user.email}\nNgười phụ trách chính',
                      maxLines: 2,
                    ),
                    secondary: const Icon(
                      Icons.star,
                      color: Colors.orange,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _primaryAssigneeId = value;
                      });
                    },
                  );
                }),
              ],
            ),
          ),

          // NÚT XÁC NHẬN
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAssignment,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.assignment_turned_in),
                  label: Text(
                    _isSaving
                        ? 'Đang giao công việc...'
                        : 'Xác nhận giao công việc',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}