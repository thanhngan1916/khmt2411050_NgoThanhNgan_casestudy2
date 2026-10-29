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

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTab = 0;

  final List<String> _tabs = [
    'Được tạo',
    'Được giao',
    'Được nhận',
    'Được chia sẻ',
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _showCreateTaskDialog() async {
    final pageContext = context;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    String priority = 'Trung bình';
    DateTime? startDate;
    DateTime? dueDate;

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

      final tasks = await _taskService.getTasks(token: token);

      if (!mounted) return;

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

  List<Task> get _filteredTasks {
    final keyword = _searchController.text.trim().toLowerCase();

    return _tasks.where((task) {
      final matchesSearch =
          task.title.toLowerCase().contains(keyword) ||
              task.description.toLowerCase().contains(keyword);

      // Tạm thời lọc theo taskType trong model.
      // Phân loại chính xác sẽ cần backend trả về nhóm quyền.
      final matchesTab = task.taskType == _tabs[_selectedTab];

      return matchesSearch && matchesTab;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: ChoiceChip(
                    label: Text(_tabs[index]),
                    selected: _selectedTab == index,
                    onSelected: (_) {
                      setState(() => _selectedTab = index);
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
                        final result =
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TaskDetailScreen(task: task),
                          ),
                        );

                        if (result == true && mounted) {
                          await _loadTasks();

                          if (!mounted) return;

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cập nhật công việc thành công!',
                              ),
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