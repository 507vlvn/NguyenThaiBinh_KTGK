import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import 'leave_request_screen.dart';
import 'scan_qr_screen.dart';

class StudentClassScreen extends StatefulWidget {
  const StudentClassScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  late Future<List<Json>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().sessions(widget.classId);
  }

  void _reload() => setState(() => _future = context.read<ApiService>().sessions(widget.classId));

  Future<void> _checkIn(Json session) async {
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);

    // Bước 1: quét mã QR trên màn hình giảng viên.
    final token = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanQrScreen()));
    if (token == null || !mounted) return;

    // Bước 2: hỏi có chụp ảnh minh chứng không.
    final wantPhoto = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ảnh minh chứng'),
        content: const Text('Chụp ảnh để nộp kèm điểm danh?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Bỏ qua')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Chụp ảnh')),
        ],
      ),
    );
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      // Bước 3: lấy GPS, chụp ảnh nếu chọn, rồi gửi điểm danh.
      final position = await currentPosition();
      String? photoPath;
      if (wantPhoto == true) {
        final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
        photoPath = picked?.path;
      }
      final res = await api.checkIn(
        sessionId: session['id'] as int,
        qrToken: token,
        latitude: position.latitude,
        longitude: position.longitude,
        photoPath: photoPath,
      );
      messenger.showSnackBar(SnackBar(content: Text(res['message'].toString())));
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final sessions = snap.data!;
          if (sessions.isEmpty) return const Center(child: Text('Chưa có buổi học nào.'));
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              final open = s['isOpen'] == true;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['title'].toString(), style: Theme.of(context).textTheme.titleMedium),
                      Text('${formatDateTime(s['startsAt'].toString())} • ${open ? 'Đang mở' : 'Đã đóng'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: (open && !_busy) ? () => _checkIn(s) : null,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Điểm danh'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LeaveRequestScreen(sessionId: s['id'] as int, sessionTitle: s['title'].toString())),
                            ),
                            child: const Text('Xin nghỉ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
