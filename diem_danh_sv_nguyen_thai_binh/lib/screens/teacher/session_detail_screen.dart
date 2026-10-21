import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/protected_image.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/class_info_card.dart';
import '../../widgets/common.dart';
import 'open_session_flow.dart';
import 'session_qr_screen.dart';

// Chi tiết một buổi học: giờ học, mở/đóng/mở lại điểm danh, trạng thái của cả lớp, điểm danh hộ.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Json session;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<List<Json>> _future;
  late Json _session = Map<String, dynamic>.from(widget.session);

  int get _id => _session['id'] as int;
  String get _state => _session['state'].toString();

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().roster(_id);
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().roster(_id));
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _openSession() async {
    final opened = await openSessionFlow(context, _session);
    if (opened == null || !mounted) return;
    setState(() => _session = opened);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionQrScreen(session: opened)));
    _reload();
  }

  Future<void> _close() async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể điểm danh buổi này nữa. Bạn vẫn mở lại được sau.',
      confirmLabel: 'Đóng',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(_id);
      if (!mounted) return;
      setState(() => _session = {..._session, 'state': 'Ended', 'isOpen': false});
      showMessage(context, 'Đã đóng điểm danh.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reopen() async {
    final api = context.read<ApiService>();
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Mở lại điểm danh trong bao lâu?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            for (final m in const [5, 10, 15, 30])
              ListTile(leading: const Icon(Icons.timer_outlined), title: Text('$m phút'), onTap: () => Navigator.pop(sheetContext, m)),
          ],
        ),
      ),
    );
    if (minutes == null) return;
    try {
      final res = await api.reopenSession(_id, minutes);
      if (!mounted) return;
      setState(() => _session = {..._session, 'state': 'Open', 'isOpen': true, 'checkInUntil': res['checkInUntil']});
      showMessage(context, res['message'].toString());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    final api = context.read<ApiService>();
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Xoá buổi học?',
      message: 'Xoá "${_session['title']}" khỏi lịch học của lớp.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteSession(_id);
      navigator.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Điểm danh hộ, có nút hoàn tác trên thông báo.
  Future<void> _markPresent(Json st) async {
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.manualCheckIn(_id, st['studentId'] as int);
      _reload();
      messenger.showSnackBar(SnackBar(
        content: Text('Đã điểm danh hộ ${st['fullName']}.'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () async {
            await api.removeAttendance(_id, st['studentId'] as int);
            _reload();
          },
        ),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeAttendance(Json st) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Huỷ điểm danh?',
      message: '${st['fullName']} sẽ được tính là vắng buổi này.',
      confirmLabel: 'Huỷ điểm danh',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.removeAttendance(_id, st['studentId'] as int);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  StatusChip _chip(String status) {
    switch (status) {
      case 'Present':
        return const StatusChip(label: 'Có mặt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
      case 'Excused':
        return const StatusChip(label: 'Có phép', icon: Icons.assignment_turned_in_rounded, tone: StatusTone.info);
      case 'PendingLeave':
        return const StatusChip(label: 'Chờ duyệt đơn', icon: Icons.hourglass_top_rounded, tone: StatusTone.warning);
      default:
        return _state == 'Ended'
            ? const StatusChip(label: 'Vắng', icon: Icons.cancel_rounded, tone: StatusTone.danger)
            : const StatusChip(label: 'Chưa điểm danh', icon: Icons.schedule_rounded);
    }
  }

  Widget _actions() {
    switch (_state) {
      case 'Planned':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(onPressed: _openSession, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Mở điểm danh')),
        );
      case 'Open':
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionQrScreen(session: _session)));
                  _reload();
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Mã QR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(onPressed: _close, icon: const Icon(Icons.lock_outline_rounded), label: const Text('Đóng')),
            ),
          ],
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(onPressed: _reopen, icon: const Icon(Icons.lock_open_rounded), label: const Text('Mở lại điểm danh')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final remaining = _state == 'Open' ? remainingLabel(_session['checkInUntil']) : null;
    final opened = _state != 'Planned';
    return Scaffold(
      appBar: AppBar(
        title: Text(_session['title'].toString()),
        actions: [
          if (_state == 'Planned') IconButton(tooltip: 'Xoá buổi học', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: 'Lớp chưa có sinh viên',
        headerBuilder: (items) {
          int count(String status) => items.where((r) => r['status'] == status).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Giờ học', style: text.titleSmall)),
                          switch (_state) {
                            'Open' => const StatusChip(label: 'Đang điểm danh', icon: Icons.lock_open_rounded, tone: StatusTone.success),
                            'Ended' => const StatusChip(label: 'Đã điểm danh', icon: Icons.lock_outline_rounded),
                            _ => const StatusChip(label: 'Chưa mở điểm danh', icon: Icons.event_outlined, tone: StatusTone.info),
                          },
                        ],
                      ),
                      InfoLine(icon: Icons.schedule_rounded, text: formatSchedule(_session['startsAt'], _session['endsAt'])),
                      if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: remaining),
                      if (opened)
                        InfoLine(icon: Icons.near_me_outlined, text: 'Phạm vi ${(_session['radiusMeters'] as num? ?? 0).round()} m'),
                      if (opened) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            StatTile(value: '${count('Present')}', label: 'Có mặt', icon: Icons.check_circle_rounded, color: const Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            StatTile(value: '${count('Excused')}', label: 'Có phép', icon: Icons.assignment_turned_in_rounded, color: scheme.primary),
                            const SizedBox(width: 8),
                            StatTile(
                              value: '${count('Absent') + count('PendingLeave')}',
                              label: _state == 'Ended' ? 'Vắng' : 'Chưa điểm danh',
                              icon: Icons.cancel_rounded,
                              color: scheme.error,
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Đến giờ học, bấm "Mở điểm danh" khi đang ở trong lớp để hiện mã QR cho sinh viên quét.',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _actions(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Danh sách lớp (${items.length})', style: text.titleMedium),
            ],
          );
        },
        itemBuilder: (context, st) {
          final present = st['status'] == 'Present';
          final details = present
              ? [
                  'Lúc ${formatTime(st['checkedInAt'].toString())}',
                  st['isManual'] == true ? 'Điểm danh hộ' : 'Cách lớp ${(st['distanceMeters'] as num).round()} m',
                ].join(' • ')
              : st['username'].toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  InitialsAvatar(name: st['fullName'].toString(), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st['fullName'].toString(), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(details, style: text.bodySmall),
                        const SizedBox(height: 6),
                        _chip(st['status'].toString()),
                      ],
                    ),
                  ),
                  if (present && st['hasPhoto'] == true)
                    IconButton(
                      tooltip: 'Xem ảnh minh chứng',
                      icon: const Icon(Icons.photo_outlined),
                      onPressed: () => showProtectedImage(context, '/api/attendances/${st['attendanceId']}/photo'),
                    ),
                  if (present)
                    IconButton(
                      tooltip: 'Huỷ điểm danh của ${st['fullName']}',
                      icon: Icon(Icons.person_off_outlined, color: scheme.error),
                      onPressed: () => _removeAttendance(st),
                    )
                  else if (opened)
                    TextButton(onPressed: () => _markPresent(st), child: const Text('Điểm danh hộ')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
