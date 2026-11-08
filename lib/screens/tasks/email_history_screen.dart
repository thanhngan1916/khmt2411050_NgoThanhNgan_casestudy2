
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/task_service.dart';

class EmailHistoryScreen extends StatefulWidget {
  final String taskId;

  const EmailHistoryScreen({
    super.key,
    required this.taskId,
  });

  @override
  State<EmailHistoryScreen> createState() => _EmailHistoryScreenState();
}

class _EmailHistoryScreenState extends State<EmailHistoryScreen> {
  final TaskService _taskService = TaskService();

  List<dynamic> _emailLogs = [];
  bool _isLoading = true;
  String? _error;
  String? _retryingLogId;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadEmailHistory();
  }

  Future<void> _loadEmailHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      _token = token;

      final logs = await _taskService.getTaskEmailLogs(
        token: token,
        taskId: widget.taskId,
      );

      if (!mounted) return;

      setState(() {
        _emailLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _retryEmail(Map<String, dynamic> log) async {
    final logId = log['_id']?.toString();

    if (logId == null || logId.isEmpty || _token == null) {
      return;
    }

    setState(() {
      _retryingLogId = logId;
    });

    try {
      await _taskService.retryTaskEmail(
        token: _token!,
        emailLogId: logId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi lại email thành công.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadEmailHistory();
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
          _retryingLogId = null;
        });
      }
    }
  }

  String _eventLabel(dynamic eventType) {
    switch (eventType?.toString()) {
      case 'task_assigned':
        return 'Giao công việc';
      case 'task_shared':
        return 'Chia sẻ công việc';
      case 'task_updated':
        return 'Cập nhật công việc';
      case 'task_completed':
        return 'Hoàn thành công việc';
      case 'task_reminder':
        return 'Nhắc nhở công việc';
      default:
        return eventType?.toString() ?? 'Không xác định';
    }
  }

  String _statusLabel(dynamic status) {
    switch (status?.toString()) {
      case 'sent':
        return 'Đã gửi';
      case 'failed':
        return 'Thất bại';
      case 'pending':
        return 'Đang xử lý';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString()) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Chưa có';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Không xác định';

    final localDate = date.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(localDate.day)}/${twoDigits(localDate.month)}/${localDate.year} '
        '${twoDigits(localDate.hour)}:${twoDigits(localDate.minute)}';
  }

  Widget _buildEmailCard(Map<String, dynamic> log) {
    final status = log['status']?.toString();
    final logId = log['_id']?.toString();
    final isRetrying = _retryingLogId == logId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log['subject']?.toString() ?? 'Không có tiêu đề',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              'Loại thông báo',
              _eventLabel(log['eventType']),
            ),
            _buildInfoRow(
              'Người nhận',
              log['recipientEmail']?.toString() ?? 'Không có',
            ),
            _buildInfoRow(
              'Số lần gửi',
              '${log['attempts'] ?? 0}',
            ),
            _buildInfoRow(
              'Thời gian tạo',
              _formatDate(log['createdAt']),
            ),
            _buildInfoRow(
              'Thời gian gửi',
              _formatDate(log['sentAt']),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Text(
                  'Trạng thái: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (status == 'failed' &&
                log['errorMessage'] != null &&
                log['errorMessage'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lỗi: ${log['errorMessage']}',
                style: const TextStyle(color: Colors.red),
              ),
            ],

            if (status == 'failed') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: isRetrying
                      ? null
                      : () => _retryEmail(log),
                  icon: isRetrying
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.refresh),
                  label: Text(
                    isRetrying ? 'Đang gửi...' : 'Gửi lại',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử gửi email'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadEmailHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadEmailHistory,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : _emailLogs.isEmpty
          ? RefreshIndicator(
        onRefresh: _loadEmailHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('Chưa có lịch sử gửi email.'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadEmailHistory,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _emailLogs.length,
          itemBuilder: (context, index) {
            final item = _emailLogs[index];

            if (item is! Map) {
              return const SizedBox.shrink();
            }

            return _buildEmailCard(
              Map<String, dynamic>.from(item),
            );
          },
        ),
      ),
    );
  }
}
