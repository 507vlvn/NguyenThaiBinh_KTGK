import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  String _role = 'SinhVien';
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final username = _username.text.trim();
    try {
      await context.read<ApiService>().register(
            username: username,
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(username: username, isRegister: true)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(controller: _fullName, decoration: const InputDecoration(labelText: 'Họ và tên'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Tên đăng nhập'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu (tối thiểu 6 ký tự)'),
                validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'SinhVien', child: Text('Sinh viên')),
                  DropdownMenuItem(value: 'GiangVien', child: Text('Giảng viên')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'SinhVien'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Đang gửi...' : 'Đăng ký và nhận OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
