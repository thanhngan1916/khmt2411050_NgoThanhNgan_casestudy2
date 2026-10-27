
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();

  final TextEditingController _fullNameController =
  TextEditingController();
  final TextEditingController _emailController =
  TextEditingController();

  User? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn cần đăng nhập lại.');
      }

      final user = await _userService.getProfile(token);

      if (!mounted) return;

      setState(() {
        _user = user;
        _fullNameController.text = user.fullName;
        _emailController.text = user.email;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ họ tên và email.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }

      final updatedUser = await _userService.updateProfile(
        token: token,
        fullName: fullName,
        email: email,
      );

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
        _fullNameController.text = updatedUser.fullName;
        _emailController.text = updatedUser.email;
        _editing = false;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error.isNotEmpty
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = '';
                });
                _loadProfile();
              },
              child: const Text('Thử lại'),
            ),
          ],
        )
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 45,
                child: Icon(Icons.person, size: 48),
              ),
              const SizedBox(height: 24),
              if (!_editing) ...[
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Họ và tên'),
                  subtitle: Text(_user!.fullName),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(_user!.email),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _editing = true;
                      _error = '';
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa'),
                ),
              ] else ...[
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                if (_error.isNotEmpty) ...[
                  Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                          setState(() {
                            _editing = false;
                            _error = '';
                            _fullNameController.text = _user!.fullName;
                            _emailController.text = _user!.email;
                          });
                        },
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
