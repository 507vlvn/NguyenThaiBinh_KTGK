import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (_busy) return;
    if (_code.text.trim().length != 6) {
      showMessage(context, 'Mã OTP gồm 6 chữ số.');
      return;
    }
    final api = context.read<ApiService>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
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
      if (mounted) {
        showError(context, e);
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isRegister ? 'Xác nhận email' : 'Xác thực đăng nhập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.mark_email_read_outlined, size: 36, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 20),
              Text('Nhập mã OTP', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Mã 6 chữ số đã được gửi tới email của tài khoản "${widget.username}". Mã có hiệu lực trong 5 phút.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'Mã OTP', hintText: '••••••', counterText: ''),
                // Nhập đủ 6 số thì tự xác nhận, không cần bấm nút.
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Xác nhận'),
              ),
              const SizedBox(height: 16),
              Text(
                'Không thấy email? Kiểm tra thư mục Spam, hoặc quay lại để gửi mã mới.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Quay lại')),
            ],
          ),
        ),
      ),
    );
  }
}
