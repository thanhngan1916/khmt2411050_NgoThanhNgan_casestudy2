import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }

      final response = await http.put(
        Uri.parse('http://10.0.2.2:3000/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
          'confirmNewPassword': _confirmPasswordController.text,
        }),
      );

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Đổi mật khẩu thành công!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        throw Exception(
          data['message']?.toString() ?? 'Không thể đổi mật khẩu.',
        );
      }
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
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_reset,
                size: 72,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cập nhật mật khẩu tài khoản',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng nhập mật khẩu hiện tại và mật khẩu mới của bạn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              _buildPasswordField(
                label: 'Mật khẩu hiện tại',
                controller: _currentPasswordController,
                obscureText: _hideCurrentPassword,
                onToggleVisibility: () {
                  setState(() {
                    _hideCurrentPassword = !_hideCurrentPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu hiện tại.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildPasswordField(
                label: 'Mật khẩu mới',
                controller: _newPasswordController,
                obscureText: _hideNewPassword,
                onToggleVisibility: () {
                  setState(() {
                    _hideNewPassword = !_hideNewPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới.';
                  }
                  if (value.length < 8) {
                    return 'Mật khẩu mới phải có ít nhất 8 ký tự.';
                  }
                  if (value == _currentPasswordController.text) {
                    return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildPasswordField(
                label: 'Xác nhận mật khẩu mới',
                controller: _confirmPasswordController,
                obscureText: _hideConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _hideConfirmPassword = !_hideConfirmPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu mới.';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Mật khẩu xác nhận không khớp.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isLoading ? null : _changePassword,
                icon: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading ? 'Đang xử lý...' : 'Xác nhận đổi mật khẩu',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}