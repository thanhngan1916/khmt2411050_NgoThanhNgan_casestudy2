
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_detail_screen.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = [
    'Được tạo',
    'Được giao',
    'Được nhận',
    'Được chia sẻ',
  ];

  final List<String> _statusOptions = [
    'Tất cả',
    'Chưa thực hiện',
    'Đang thực hiện',
    'Đã hoàn thành',
  ];

  final List<String> _priorityOptions = [
    'Tất cả',
    'Thấp',
    'Trung bình',
    'Cao',
  ];

  List<Task> _tasks = [];
  List<TaskAssignee> _users = [];

  bool _isLoading = true;
  bool _isCreatingTask = false;

  String? _error;

  int _selectedTab = 0;

  // Công việc theo hạn hoàn thành
  List<Task> _upcomingTasks = [];
  List<Task> _overdueTasks = [];

  bool _isDeadlineLoading = true;
  String? _deadlineError;

  // Thống kê công việc
  Map<String, int> _statistics = {
    'total': 0,
    'notStarted': 0,
    'inProgress': 0,
    'completed': 0,
  };

  bool _isStatisticsLoading = true;
  String? _statisticsError;

  // Thống kê phân công
  Map<String, int> _assignmentStatistics = {
    'assigned': 0,
    'responsible': 0,
  };

  // Bộ lọc
  String _selectedStatus = 'Tất cả';
  String _selectedPriority = 'Tất cả';
  String _selectedAssignee = 'Tất cả';

  // Sắp xếp
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();

    _loadTasks();
    _loadUsers();
    _loadDeadlineTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Chuẩn hóa tiếng Việt để tìm kiếm không dấu
  String _normalizeSearchText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp('[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp('[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd');
  }

  // Xác định phạm vi công việc theo tab
  String _getSelectedScope() {
    switch (_selectedTab) {
      case 0:
        return 'created';
      case 1:
        return 'assigned';
      case 2:
        return 'received';
      case 3:
        return 'shared';
      default:
        return 'all';
    }
  }

  // Tải danh sách công việc
  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập hoặc chưa lưu token.');
      }

      final tasks = await _taskService.getTasks(
        token: token,
        scope: _getSelectedScope(),
        sortBy: _sortBy,
        order: _sortOrder,
      );

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });

      // Tải thống kê sau khi tải danh sách thành công
      _loadTaskStatistics();
    } catch (e) {
      debugPrint('Lỗi tải danh sách công việc: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Không thể tải danh sách công việc. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  // Tải thống kê công việc
  Future<void> _loadTaskStatistics() async {
    if (!mounted) return;

    setState(() {
      _isStatisticsLoading = true;
      _statisticsError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      final statistics = await _taskService.getTaskStatistics(
        token: token,
      );

      final assignmentStatistics =
      await _taskService.getAssignmentStatistics(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _statistics = statistics;
        _assignmentStatistics = assignmentStatistics;
        _isStatisticsLoading = false;
        _statisticsError = null;
      });
    } catch (e) {
      debugPrint('Lỗi tải thống kê: $e');

      if (!mounted) return;

      setState(() {
        _isStatisticsLoading = false;
        _statisticsError = 'Không thể tải dữ liệu thống kê.';
      });
    }
  }

  // Tải công việc sắp đến hạn và quá hạn
  Future<void> _loadDeadlineTasks() async {
    if (!mounted) return;

    setState(() {
      _isDeadlineLoading = true;
      _deadlineError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      final result = await _taskService.getDeadlineTasks(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _upcomingTasks = result['upcoming'] ?? [];
        _overdueTasks = result['overdue'] ?? [];
        _isDeadlineLoading = false;
        _deadlineError = null;
      });
    } catch (e) {
      debugPrint('Lỗi tải công việc theo hạn: $e');

      if (!mounted) return;

      setState(() {
        _isDeadlineLoading = false;
        _deadlineError =
        'Không thể tải công việc theo hạn hoàn thành.';
      });
    }
  }

  // Tải danh sách người dùng
  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) return;

      final users = await _taskService.getUsers(token: token);

      if (!mounted) return;

      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Lỗi tải danh sách người dùng: $e');
    }
  }

  // Danh sách người phụ trách
  List<TaskAssignee> get _assigneeOptions => _users;

  // Lọc công việc
  List<Task> get _filteredTasks {
    final keyword = _normalizeSearchText(_searchController.text);

    return _tasks.where((task) {
      final taskName = _normalizeSearchText(task.title);
      final matchesSearch = taskName.contains(keyword);

      final matchesStatus = _selectedStatus == 'Tất cả' ||
          task.status == _selectedStatus;

      final matchesPriority = _selectedPriority == 'Tất cả' ||
          task.priority == _selectedPriority;

      final matchesAssignee = _selectedAssignee == 'Tất cả' ||
          task.assignedTo.any(
                (assignee) => assignee.id == _selectedAssignee,
          );

      return matchesSearch &&
          matchesStatus &&
          matchesPriority &&
          matchesAssignee;
    }).toList();
  }

  // Thêm công việc
  Future<void> _showCreateTaskDialog() async {
    if (_isCreatingTask) return;

    final pageContext = context;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    String priority = 'Trung bình';
    DateTime? startDate;
    DateTime? dueDate;

    List<String> selectedAssigneeIds = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm công việc'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên công việc *',
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
                          .map(
                            (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            priority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Chọn người phụ trách
                    DropdownButtonFormField<String>(
                      initialValue: selectedAssigneeIds.isNotEmpty &&
                          _assigneeOptions.any(
                                (user) =>
                            user.id == selectedAssigneeIds.first,
                          )
                          ? selectedAssigneeIds.first
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Người phụ trách',
                        border: OutlineInputBorder(),
                        hintText: 'Chọn người phụ trách',
                      ),
                      items: _assigneeOptions.map((assignee) {
                        return DropdownMenuItem<String>(
                          value: assignee.id,
                          child: Text(assignee.fullName),
                        );
                      }).toList(),
                      onChanged: _assigneeOptions.isEmpty
                          ? null
                          : (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedAssigneeIds = [value];
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Chọn ngày bắt đầu
                    OutlinedButton.icon(
                      onPressed: () async {
                        final today = DateUtils.dateOnly(DateTime.now());

                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: startDate ?? today,
                          firstDate: today,
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          setDialogState(() {
                            startDate = selected;

                            if (dueDate != null &&
                                DateUtils.dateOnly(dueDate!).isBefore(
                                  DateUtils.dateOnly(startDate!),
                                )) {
                              dueDate = null;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        startDate == null
                            ? 'Chọn ngày bắt đầu'
                            : 'Bắt đầu: ${startDate!.day}/${startDate!.month}/${startDate!.year}',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chọn hạn hoàn thành
                    OutlinedButton.icon(
                      onPressed: () async {
                        final today = DateUtils.dateOnly(DateTime.now());

                        final minimumDate = startDate == null
                            ? today
                            : DateUtils.dateOnly(startDate!);

                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate ?? minimumDate,
                          firstDate: minimumDate,
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          setDialogState(() {
                            dueDate = selected;
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        dueDate == null
                            ? 'Chọn hạn hoàn thành'
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
                      ScaffoldMessenger.of(pageContext).showSnackBar(
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
                      'assignedTo': selectedAssigneeIds,
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

    // Giải phóng controller sau khi hộp thoại đóng
    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _isCreatingTask = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      await _taskService.createTask(
        token: token,
        title: result['title'] as String,
        description: result['description'] as String,
        priority: result['priority'] as String,
        startDate: result['startDate'] as DateTime?,
        dueDate: result['dueDate'] as DateTime?,
        assignedTo: List<String>.from(result['assignedTo'] ?? []),
      );

      if (!mounted) return;

      await _loadTasks();
      await _loadDeadlineTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm công việc thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Lỗi thêm công việc: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể thêm công việc: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }

  // Hiển thị tổng quan tiến độ
  Widget _buildProgressOverview() {
    final total = _statistics['total'] ?? 0;
    final notStarted = _statistics['notStarted'] ?? 0;
    final inProgress = _statistics['inProgress'] ?? 0;
    final completed = _statistics['completed'] ?? 0;

    final progress = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng quan tiến độ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isStatisticsLoading
                        ? 'Đang tải...'
                        : '$total công việc',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isStatisticsLoading)
                const LinearProgressIndicator()
              else if (_statisticsError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statisticsError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    TextButton.icon(
                      onPressed: _loadTaskStatistics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử tải lại thống kê'),
                    ),
                  ],
                )
              else ...[
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildProgressItem(
                        'Chưa thực hiện',
                        notStarted,
                        Colors.grey,
                      ),
                      _buildProgressItem(
                        'Đang thực hiện',
                        inProgress,
                        Colors.orange,
                      ),
                      _buildProgressItem(
                        'Đã hoàn thành',
                        completed,
                        Colors.green,
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressItem(
      String label,
      int count,
      Color color,
      ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Thống kê phân công
  Widget _buildAssignmentOverview() {
    final assigned = _assignmentStatistics['assigned'] ?? 0;
    final responsible = _assignmentStatistics['responsible'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thống kê phân công công việc',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_isStatisticsLoading)
                const LinearProgressIndicator()
              else if (_statisticsError != null)
                Text(
                  _statisticsError!,
                  style: const TextStyle(color: Colors.red),
                )
              else
                Row(
                  children: [
                    _buildAssignmentItem(
                      'Công việc được giao',
                      assigned,
                      Colors.deepPurple,
                    ),
                    _buildAssignmentItem(
                      'Đang phụ trách',
                      responsible,
                      Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(
      String label,
      int count,
      Color color,
      ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Công việc theo hạn hoàn thành
  Widget _buildDeadlineOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(
            Icons.event_note,
            color: Colors.deepPurple,
          ),
          title: const Text(
            'Công việc theo hạn hoàn thành',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            _isDeadlineLoading
                ? 'Đang tải dữ liệu...'
                : _deadlineError != null
                ? 'Không thể tải dữ liệu'
                : 'Sắp đến hạn: ${_upcomingTasks.length} • Quá hạn: ${_overdueTasks.length}',
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            if (_isDeadlineLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              )
            else if (_deadlineError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _deadlineError!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    TextButton.icon(
                      onPressed: _loadDeadlineTasks,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildDeadlineSection(
                    title: 'Sắp đến hạn',
                    tasks: _upcomingTasks,
                    color: Colors.orange,
                    icon: Icons.schedule,
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildDeadlineSection(
                    title: 'Đã quá hạn',
                    tasks: _overdueTasks,
                    color: Colors.red,
                    icon: Icons.warning_amber,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  // Hiển thị từng nhóm công việc
  Widget _buildDeadlineSection({
    required String title,
    required List<Task> tasks,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Text(
              '${tasks.length} công việc',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Không có công việc',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...tasks.map(
                (task) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.assignment_outlined,
                color: color,
              ),
              title: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                task.dueDate == null
                    ? 'Chưa có hạn hoàn thành'
                    : 'Hạn: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(task: task),
                  ),
                );

                if (!mounted) return;

                if (result == true) {
                  await _loadTasks();
                  await _loadDeadlineTasks();
                }
              },
            ),
          ),
      ],
    );
  }

  // Mở chi tiết công việc
  Future<void> _openTaskDetail(Task task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadTasks();
      await _loadDeadlineTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật công việc thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () {
              _loadTasks();
              _loadDeadlineTasks();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Tìm kiếm
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm công việc...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Lọc trạng thái và ưu tiên
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Trạng thái',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            items: _statusOptions.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'Ưu tiên',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            items: _priorityOptions.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedPriority = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Lọc người phụ trách
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAssignee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Người phụ trách',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'Tất cả',
                          child: Text('Tất cả người phụ trách'),
                        ),
                        ..._assigneeOptions.map(
                              (assignee) => DropdownMenuItem<String>(
                            value: assignee.id,
                            child: Text(assignee.fullName),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAssignee = value ?? 'Tất cả';
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Sắp xếp
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _sortBy,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sắp xếp theo',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'dueDate',
                                child: Text('Hạn hoàn thành'),
                              ),
                              DropdownMenuItem(
                                value: 'priority',
                                child: Text('Mức độ ưu tiên'),
                              ),
                              DropdownMenuItem(
                                value: 'createdAt',
                                child: Text('Thời gian tạo'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortBy = value;
                                });
                                _loadTasks();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _sortOrder,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Thứ tự',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'asc',
                                child: Text('Tăng dần'),
                              ),
                              DropdownMenuItem(
                                value: 'desc',
                                child: Text('Giảm dần'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortOrder = value;
                                });
                                _loadTasks();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildProgressOverview(),

                  const SizedBox(height: 8),

                  _buildAssignmentOverview(),

                  const SizedBox(height: 8),

                  _buildDeadlineOverview(),

                  const SizedBox(height: 12),

                  // Các tab công việc
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(_tabs[index]),
                            selected: _selectedTab == index,
                            onSelected: (_) {
                              if (_selectedTab != index) {
                                setState(() {
                                  _selectedTab = index;
                                });
                                _loadTasks();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Danh sách công việc
          Expanded(
            flex: 3,
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadTasks,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
                : tasks.isEmpty
                ? const Center(
              child: Text(
                'Chưa có công việc trong mục này',
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                physics:
                const AlwaysScrollableScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: Icon(
                        task.status == 'Đã hoàn thành'
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: task.status == 'Đã hoàn thành'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.priority} • ${task.status}'
                            '${task.startDate == null ? '' : '\nBắt đầu: ${task.startDate!.day}/${task.startDate!.month}/${task.startDate!.year}'}'
                            '${task.dueDate == null ? '' : '\nHạn hoàn thành: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'}',
                      ),
                      isThreeLine: task.startDate != null ||
                          task.dueDate != null,
                      onTap: () => _openTaskDetail(task),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingTask ? null : _showCreateTaskDialog,
        icon: _isCreatingTask
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.add),
        label: Text(
          _isCreatingTask ? 'Đang thêm...' : 'Thêm công việc',
        ),
      ),
    );
  }
}
