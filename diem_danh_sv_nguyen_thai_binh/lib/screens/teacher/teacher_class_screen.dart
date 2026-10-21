import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import 'absence_report_screen.dart';
import 'attendances_screen.dart';
import 'class_students_screen.dart';
import 'leave_review_screen.dart';
import 'session_qr_screen.dart';

class TeacherClassScreen extends StatefulWidget {
  const TeacherClassScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().sessions(widget.classId);
  }

  void _reload() => setState(() => _future = context.read<ApiService>().sessions(widget.classId));

  // Buổi học mới lấy toạ độ hiện tại của giảng viên làm vị trí lớp.
  Future<void> _createSession() async {
    final titleCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buổi học mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Tên buổi học')),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bán kính điểm danh (mét)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Tạo')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final radius = double.tryParse(radiusCtrl.text) ?? 100;
    titleCtrl.dispose();
    radiusCtrl.dispose();
    if (ok != true || !mounted) return;
    if (title.isEmpty) {
      showMessage(context, 'Nhập tên buổi học.');
      return;
    }

    final api = context.read<ApiService>();
    try {
      final position = await currentPosition();
      await api.createSession(
            widget.classId,
            title: title,
            latitude: position.latitude,
            longitude: position.longitude,
            radiusMeters: radius,
          );
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _closeSession(Json s) async {
    try {
      await context.read<ApiService>().closeSession(s['id'] as int);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          IconButton(
            tooltip: 'Sinh viên',
            icon: const Icon(Icons.groups),
            onPressed: () => _open(ClassStudentsScreen(classId: widget.classId, className: widget.className)),
          ),
          IconButton(
            tooltip: 'Đơn xin nghỉ',
            icon: const Icon(Icons.inbox),
            onPressed: () => _open(LeaveReviewScreen(classId: widget.classId)),
          ),
          IconButton(
            tooltip: 'Báo cáo vắng',
            icon: const Icon(Icons.warning_amber),
            onPressed: () => _open(AbsenceReportScreen(classId: widget.classId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('Buổi học mới'),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final sessions = snap.data!;
          if (sessions.isEmpty) return const Center(child: Text('Chưa có buổi học nào. Bấm "Buổi học mới" để tạo.'));
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              final open = s['isOpen'] == true;
              return ListTile(
                title: Text(s['title'].toString()),
                subtitle: Text('${formatDateTime(s['startsAt'].toString())} • ${open ? 'Đang mở' : 'Đã đóng'}'),
                onTap: () => _open(AttendancesScreen(sessionId: s['id'] as int, title: s['title'].toString())),
                trailing: open
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Hiện mã QR',
                            icon: const Icon(Icons.qr_code),
                            onPressed: () async {
                              final closed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => SessionQrScreen(session: s)),
                              );
                              if (closed == true) _reload();
                            },
                          ),
                          IconButton(
                            tooltip: 'Đóng điểm danh',
                            icon: const Icon(Icons.lock),
                            onPressed: () => _closeSession(s),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
