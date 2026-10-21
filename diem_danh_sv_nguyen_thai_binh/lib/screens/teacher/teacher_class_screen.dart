import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/class_form.dart';
import '../../widgets/class_info_card.dart';
import '../../widgets/common.dart';
import '../common/class_members_screen.dart';
import 'absence_report_screen.dart';
import 'leave_review_screen.dart';
import 'session_detail_screen.dart';
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
  Json? _detail;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([api.classDetail(widget.classId), api.sessions(widget.classId)]);
    if (mounted) setState(() => _detail = results[0] as Json);
    return results[1] as List<Json>;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  // Mở một màn hình con, quay lại thì làm mới (số liệu có thể đã thay đổi).
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Future<void> _editClass() async {
    final api = context.read<ApiService>();
    final detail = _detail;
    if (detail == null) return;
    final List<Json> subjects;
    try {
      subjects = await api.subjects();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final data = await showClassForm(context, cls: detail, subjects: subjects);
    if (data == null || !mounted) return;
    try {
      await api.updateClass(widget.classId, data);
      if (mounted) showMessage(context, 'Đã cập nhật thông tin lớp.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Tạo buổi học bằng bảng trượt; vị trí lớp lấy từ GPS hiện tại. Tạo xong mở mã QR ngay.
  Future<void> _createSession() async {
    final api = context.read<ApiService>();
    final nextNumber = (_detail?['sessionCount'] as int? ?? 0) + 1;
    final result = await showModalBottomSheet<_NewSession>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewSessionSheet(defaultTitle: 'Buổi $nextNumber'),
    );
    if (result == null || !mounted) return;
    try {
      final session = await runWithProgress(context, 'Đang lấy vị trí lớp và tạo buổi học...', () async {
        final position = await currentPosition();
        return api.createSession(
          widget.classId,
          title: result.title,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: result.radius,
          durationMinutes: result.minutes == 0 ? null : result.minutes,
        );
      });
      if (!mounted) return;
      await _open(SessionQrScreen(session: session));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _closeSession(Json s) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể điểm danh buổi "${s['title']}" nữa. Bạn vẫn mở lại được sau.',
      confirmLabel: 'Đóng',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(s['id'] as int);
      if (mounted) showMessage(context, 'Đã đóng điểm danh.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final studentCount = _detail?['studentCount'] as int? ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buổi học mới'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.event_note_outlined,
        emptyTitle: 'Chưa có buổi học nào',
        emptyMessage: 'Khi đang ở lớp, bấm "Buổi học mới" để mở điểm danh. Vị trí lớp được lấy từ GPS của bạn.',
        headerBuilder: (items) {
          final openCount = items.where((s) => s['isOpen'] == true).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_detail != null) ClassInfoCard(detail: _detail!, onEdit: _editClass),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.groups_rounded,
                    label: 'Sinh viên',
                    onTap: () => _open(ClassMembersScreen(classId: widget.classId, className: widget.className)),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.inbox_rounded,
                    label: 'Đơn nghỉ',
                    onTap: () => _open(LeaveReviewScreen(classId: widget.classId)),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.insights_rounded,
                    label: 'Báo cáo vắng',
                    onTap: () => _open(AbsenceReportScreen(classId: widget.classId)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Buổi học (${items.length}) • $openCount đang mở', style: text.titleMedium),
            ],
          );
        },
        itemBuilder: (context, s) {
          final open = s['isOpen'] == true;
          final remaining = open ? remainingLabel(s['endsAt']) : null;
          final endsAt = s['endsAt'];
          return TapCard(
            onTap: () => _open(SessionDetailScreen(session: s)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s['title'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                    open
                        ? const StatusChip(label: 'Đang mở', icon: Icons.lock_open_rounded, tone: StatusTone.success)
                        : const StatusChip(label: 'Đã kết thúc', icon: Icons.lock_outline_rounded),
                  ],
                ),
                InfoLine(
                  icon: Icons.event_outlined,
                  text: endsAt == null
                      ? formatDateTime(s['startsAt'].toString())
                      : '${formatDateTime(s['startsAt'].toString())} - ${formatTime(endsAt.toString())}',
                ),
                if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: remaining),
                InfoLine(icon: Icons.how_to_reg_outlined, text: '${s['presentCount'] ?? 0}/$studentCount sinh viên có mặt • Chạm để xem chi tiết'),
                if (open) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _open(SessionQrScreen(session: s)),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Mã QR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _closeSession(s),
                          icon: const Icon(Icons.lock_outline_rounded),
                          label: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: TapCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _NewSession {
  const _NewSession(this.title, this.radius, this.minutes);

  final String title;
  final double radius;
  // 0 = mở đến khi giảng viên đóng.
  final int minutes;
}

class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet({required this.defaultTitle});

  final String defaultTitle;

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  late final _title = TextEditingController(text: widget.defaultTitle);
  double _radius = 100;
  int _minutes = 15;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên buổi học');
      return;
    }
    Navigator.pop(context, _NewSession(_title.text.trim(), _radius, _minutes));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buổi học mới', style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Tên buổi học', hintText: 'Ví dụ: Buổi 3 - Chương 2', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Text('Thời gian mở điểm danh', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [(15, '15 phút'), (30, '30 phút'), (45, '45 phút'), (90, '90 phút'), (0, 'Đến khi đóng')])
                  ChoiceChip(label: Text(label), selected: _minutes == value, onSelected: (_) => setState(() => _minutes = value)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Phạm vi điểm danh', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 50, label: Text('50 m')),
                ButtonSegment(value: 100, label: Text('100 m')),
                ButtonSegment(value: 200, label: Text('200 m')),
              ],
              selected: {_radius},
              onSelectionChanged: (s) => setState(() => _radius = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.my_location_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vị trí lớp được lấy từ GPS hiện tại của bạn. Hãy tạo buổi học khi đang ở trong lớp.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Tạo và hiện mã QR')),
          ],
        ),
      ),
    );
  }
}
