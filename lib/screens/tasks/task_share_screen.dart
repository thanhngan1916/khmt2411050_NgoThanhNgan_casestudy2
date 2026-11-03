
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';

class TaskShareScreen extends StatefulWidget {
  final Task task;

  const TaskShareScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskShareScreen> createState() => _TaskShareScreenState();
}

class _TaskShareScreenState extends State<TaskShareScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();

  String? _token;
  String _permission = 'viewer';

  List<dynamic> _shares = [];
  List<dynamic> _users = [];
  final Set<String> _selectedUserIds = {};

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Vui lòng đăng nhập lại.');
      return;
    }

    _token = token;
    await _loadShares();
  }

  Future<void> _loadShares() async {
    if (_token == null) return;

    try {
      final result = await _taskService.getTaskShares(
        token: _token!,
        taskId: widget.task.id,
      );

      if (!mounted) return;
      setState(() {
        _shares = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _searchUsers(String keyword) async {
    if (_token == null || keyword.trim().isEmpty) {
      setState(() {
        _users = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final result = await _taskService.getUsers(
        token: _token!,
        keyword: keyword.trim(),
      );

      if (!mounted) return;

      setState(() {
        _users = result;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _shareSelectedUsers() async {
    if (_selectedUserIds.isEmpty) {
      _showMessage('Vui lòng chọn ít nhất một người.');
      return;
    }

    setState(() => _isSharing = true);

    try {
      await _taskService.shareTask(
        token: _token!,
        taskId: widget.task.id,
        userIds: _selectedUserIds.toList(),
        permission: _permission,
      );

      if (!mounted) return;

      _selectedUserIds.clear();
      _searchController.clear();
      _users.clear();

      await _loadShares();

      if (!mounted) return;
      _showMessage('Chia sẻ công việc thành công.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _changePermission(
      String shareId,
      String permission,
      ) async {
    try {
      await _taskService.updateTaskShare(
        token: _token!,
        taskId: widget.task.id,
        shareId: shareId,
        permission: permission,
      );

      await _loadShares();

      if (!mounted) return;
      _showMessage('Đã cập nhật quyền chia sẻ.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    }
  }

  Future<void> _removeShare(String shareId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thu hồi quyền chia sẻ'),
        content: const Text(
          'Bạn có chắc chắn muốn thu hồi quyền chia sẻ của người này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _taskService.deleteTaskShare(
        token: _token!,
        taskId: widget.task.id,
        shareId: shareId,
      );

      await _loadShares();

      if (!mounted) return;
      _showMessage('Đã thu hồi quyền chia sẻ.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    }
  }

  String _getUserName(dynamic user) {
    if (user is TaskAssignee) {
      return user.fullName;
    }

    if (user is Map) {
      return user['fullName']?.toString() ?? 'Người dùng';
    }

    return 'Người dùng';
  }
  String _getUserEmail(dynamic user) {
    if (user is TaskAssignee) {
      return user.email;
    }

    if (user is Map) {
      return user['email']?.toString() ?? '';
    }

    return '';
  }

  String _getUserId(dynamic user) {
    if (user is TaskAssignee) {
      return user.id;
    }

    if (user is Map) {
      return user['_id']?.toString() ??
          user['id']?.toString() ??
          '';
    }

    return '';
  }

  String _getShareId(dynamic share) {
    if (share is Map) {
      return share['_id']?.toString() ??
          share['id']?.toString() ??
          '';
    }
    return '';
  }

  dynamic _getSharedUser(dynamic share) {
    if (share is Map) {
      return share['userId'];
    }
    return null;
  }

  String _getPermission(dynamic share) {
    if (share is Map) {
      return share['permission']?.toString() ?? 'viewer';
    }
    return 'viewer';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildShareList() {
    if (_shares.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('Chưa chia sẻ công việc này với ai.'),
        ),
      );
    }

    return Column(
      children: _shares.map((share) {
        final user = _getSharedUser(share);
        final shareId = _getShareId(share);
        final permission = _getPermission(share);

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(_getUserName(user)),
            subtitle: Text(
              '${_getUserEmail(user)}\n'
                  'Quyền: ${permission == 'editor' ? 'Có thể chỉnh sửa' : 'Chỉ xem'}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'viewer' || value == 'editor') {
                  _changePermission(shareId, value);
                } else if (value == 'delete') {
                  _removeShare(shareId);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'viewer',
                  child: Text('Chỉ xem'),
                ),
                PopupMenuItem(
                  value: 'editor',
                  child: Text('Có thể chỉnh sửa'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Thu hồi quyền'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _users.map((user) {
        final userId = _getUserId(user);

        if (userId.isEmpty) {
          return const SizedBox.shrink();
        }

        final selected = _selectedUserIds.contains(userId);

        return CheckboxListTile(
          value: selected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedUserIds.add(userId);
              } else {
                _selectedUserIds.remove(userId);
              }
            });
          },
          title: Text(_getUserName(user)),
          subtitle: Text(_getUserEmail(user)),
          secondary: const CircleAvatar(
            child: Icon(Icons.person_outline),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ công việc'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadShares,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.task.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            const Text(
              'Người đang được chia sẻ',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            _buildShareList(),

            const Divider(height: 32),

            const Text(
              'Chia sẻ với người khác',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm theo tên hoặc email',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _users = []);
                  },
                ),
              ),
              onChanged: _searchUsers,
            ),

            const SizedBox(height: 12),

            _buildUserSearchResults(),

            const SizedBox(height: 12),

            const Text(
              'Quyền truy cập',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            RadioGroup<String>(
              groupValue: _permission,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _permission = value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'viewer',
                    title: Text('Chỉ xem'),
                    subtitle: Text(
                      'Người được chia sẻ chỉ có thể xem công việc.',
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'editor',
                    title: Text('Có thể chỉnh sửa'),
                    subtitle: Text(
                      'Người được chia sẻ có thể chỉnh sửa công việc.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareSelectedUsers,
                icon: _isSharing
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.share),
                label: Text(
                  _isSharing
                      ? 'Đang chia sẻ...'
                      : 'Chia sẻ công việc',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
