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
  final List<String> _tabs = [
    'Được tạo',
    'Được giao',
    'Được nhận',
    'Được chia sẻ',
  ];
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
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();

  List<Task> _tasks = [];
  bool _isLoading = true;
  List<TaskAssignee> _users = [];
  String? _error;
  int _selectedTab = 0;

  // Dữ liệu thống kê công việc từ Backend
  Map<String, int> _statistics = {
    'total': 0,
    'notStarted': 0,
    'inProgress': 0,
    'completed': 0,
  };

  bool _isStatisticsLoading = true;

  // Dữ liệu thống kê công việc được giao và đang phụ trách
  Map<String, int> _assignmentStatistics = {
    'assigned': 0,
    'responsible': 0,
  };

// Các giá trị lọc
  String _selectedStatus = 'Tất cả';
  String _selectedPriority = 'Tất cả';
  String _selectedAssignee = 'Tất cả';

// Tiêu chí sắp xếp
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

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
  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadUsers();
  }
  Future<void> _showCreateTaskDialog() async {
    final pageContext = context;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    String priority = 'Trung bình';
    DateTime? startDate;
    DateTime? dueDate;

// Danh sách ID người phụ trách được chọn
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
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Mức độ ưu tiên',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Thấp', 'Trung bình', 'Cao']
                          .map(
                            (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // CHỌN NGƯỜI PHỤ TRÁCH

                    DropdownButtonFormField<String>(
                      value: selectedAssigneeIds.isNotEmpty &&
                          _assigneeOptions.any(
                                (user) => user.id == selectedAssigneeIds.first,
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

                    // NÚT CHỌN NGÀY BẮT ĐẦU
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

                    // NÚT CHỌN HẠN HOÀN THÀNH
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

    // Đợi hộp thoại đóng hoàn toàn rồi mới giải phóng controller
    await Future.delayed(const Duration(milliseconds: 300));

    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) return;
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

      if (!mounted) return;

      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Thêm công việc thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
        throw Exception(
          'Bạn chưa đăng nhập hoặc chưa lưu token.',
        );
      }

      // Xác định phạm vi công việc theo tab đang chọn
      String scope;

      switch (_selectedTab) {
        case 0:
          scope = 'created';
          break;
        case 1:
          scope = 'assigned';
          break;
        case 2:
          scope = 'received';
          break;
        case 3:
          scope = 'shared';
          break;
        default:
          scope = 'all';
      }

      final tasks = await _taskService.getTasks(
        token: token,
        scope: scope,
      );

      if (!mounted) return;

// Tải lại thống kê công việc
      _loadTaskStatistics();

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  // Tải thống kê công việc từ API
  // Tải thống kê công việc từ API
  Future<void> _loadTaskStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      // Lấy thống kê công việc theo trạng thái
      final statistics = await _taskService.getTaskStatistics(
        token: token,
      );

      // Lấy thống kê công việc được giao và đang phụ trách
      final assignmentStatistics =
      await _taskService.getAssignmentStatistics(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _statistics = statistics;
        _assignmentStatistics = assignmentStatistics;
        _isStatisticsLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải thống kê: $e');

      if (!mounted) return;

      setState(() {
        _isStatisticsLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return;
      }

      final users = await _taskService.getUsers(token: token);

      if (!mounted) return;

      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Lỗi tải danh sách người dùng: $e');
    }
  }
  // Lấy danh sách người phụ trách không trùng lặp
  List<TaskAssignee> get _assigneeOptions {
    return _users;
  }

  List<Task> get _filteredTasks {

    final keyword = _normalizeSearchText(_searchController.text);

    return _tasks.where((task) {
      // Tìm kiếm theo tên không dấu
      final taskName = _normalizeSearchText(task.title);
      final matchesSearch = taskName.contains(keyword);

      // Lọc theo trạng thái
      final matchesStatus = _selectedStatus == 'Tất cả' ||
          task.status == _selectedStatus;

      // Lọc theo mức độ ưu tiên
      final matchesPriority = _selectedPriority == 'Tất cả' ||
          task.priority == _selectedPriority;

      // Lọc theo người phụ trách
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // Hiển thị tổng quan tiến độ công việc

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
                    _isStatisticsLoading ? 'Đang tải...' : '$total công việc',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _isStatisticsLoading ? null : progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isStatisticsLoading
                        ? '--'
                        : '${(progress * 100).round()}%',
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
                    _isStatisticsLoading ? 0 : notStarted,
                    Colors.grey,
                  ),
                  _buildProgressItem(
                    'Đang thực hiện',
                    _isStatisticsLoading ? 0 : inProgress,
                    Colors.orange,
                  ),
                  _buildProgressItem(
                    'Đã hoàn thành',
                    _isStatisticsLoading ? 0 : completed,
                    Colors.green,
                  ),
                ],
              ),
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
  // Hiển thị thống kê công việc được giao và đang phụ trách
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
              Row(
                children: [
                  _buildAssignmentItem(
                    'Công việc được giao',
                    _isStatisticsLoading ? 0 : assigned,
                    Colors.deepPurple,
                  ),
                  _buildAssignmentItem(
                    'Đang phụ trách',
                    _isStatisticsLoading ? 0 : responsible,
                    Colors.blue,
                  ),
                ],
              ),
              if (_isStatisticsLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(String label, int count, Color color) {
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

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Tìm kiếm theo tên công việc
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

          // Lọc theo trạng thái và mức độ ưu tiên
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
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
                    value: _selectedPriority,
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

          // Lọc theo người phụ trách
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedAssignee,
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

// SẮP XẾP CÔNG VIỆC
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Tiêu chí sắp xếp
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
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

                // Thứ tự sắp xếp
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _sortOrder,
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

          // TỔNG QUAN TIẾN ĐỘ
          _buildProgressOverview(),

          const SizedBox(height: 8),

// THỐNG KÊ CÔNG VIỆC ĐƯỢC GIAO VÀ ĐANG PHỤ TRÁCH
          _buildAssignmentOverview(),

          const SizedBox(height: 12),

          // Giữ nguyên 4 tab phân loại công việc
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
                        setState(() => _selectedTab = index);
                        _loadTasks();
                      }
                    },
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),
          Expanded(
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
                    ElevatedButton(
                      onPressed: _loadTasks,
                      child: const Text('Thử lại'),
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

                          if (!mounted) return;

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Cập nhật công việc thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm công việc'),
      ),
    );
  }
}