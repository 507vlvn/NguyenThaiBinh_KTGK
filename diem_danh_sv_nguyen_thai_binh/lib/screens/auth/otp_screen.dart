import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// Dùng cho cả xác nhận đăng ký (isRegister = true) và OTP đăng nhập (isRegister = false).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.username, required this.isRegister});

  final String username;
  final bool isRegister;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final api = context.read<ApiService>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      if (widget.isRegister) {
        final res = await api.verifyRegister(widget.username, _code.text.trim());
        messenger.showSnackBar(SnackBar(content: Text(res['message'].toString())));
        navigator.popUntil((r) => r.isFirst);
      } else {
        final data = await api.verifyLogin(widget.username, _code.text.trim());
        await auth.saveSession(data);
        navigator.popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập mã OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Mã OTP 6 số đã được gửi tới email của ${widget.username}.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _verify,
                child: Text(_busy ? 'Đang xác nhận...' : 'Xác nhận'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
