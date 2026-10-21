import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

// Hiển thị mã QR để sinh viên quét, đếm số sinh viên đã điểm danh (cập nhật mỗi 5 giây).
// Đóng điểm danh từ đây sẽ trả về true cho màn hình trước.
class SessionQrScreen extends StatefulWidget {
  const SessionQrScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<SessionQrScreen> createState() => _SessionQrScreenState();
}

class _SessionQrScreenState extends State<SessionQrScreen> {
  Timer? _timer;
  int? _count;

  int get _sessionId => widget.session['id'] as int;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    // Mỗi 5 giây: cập nhật số sinh viên đã điểm danh và thời gian còn lại.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshCount();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final list = await context.read<ApiService>().attendances(_sessionId);
      if (mounted) setState(() => _count = list.length);
    } catch (_) {
      // Lỗi mạng tạm thời: giữ số cũ, lần sau thử lại.
    }
  }

  Future<void> _close() async {
    final api = context.read<ApiService>();
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể quét mã này nữa.',
      confirmLabel: 'Đóng',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(_sessionId);
      navigator.pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final qr = widget.session['qrToken'].toString();
    return Scaffold(
      appBar: AppBar(title: Text(widget.session['title'].toString())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                // Nền trắng để mã QR dễ quét kể cả khi app ở chế độ tối.
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Semantics(
                  label: 'Mã QR điểm danh',
                  child: QrImageView(data: qr, size: 260, backgroundColor: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sinh viên mở app, vào lớp và bấm "Điểm danh" để quét mã này.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (widget.session['endsAt'] != null) ...[
              const SizedBox(height: 8),
              Text(
                remainingLabel(widget.session['endsAt']) ?? 'Đã hết thời gian điểm danh',
                style: text.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.how_to_reg_rounded, size: 36, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _count == null ? '...' : '$_count sinh viên',
                              style: text.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                            ),
                            Text('đã điểm danh • tự cập nhật', style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error)),
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('Đóng điểm danh'),
            onPressed: _close,
          ),
        ),
      ),
    );
  }
}
