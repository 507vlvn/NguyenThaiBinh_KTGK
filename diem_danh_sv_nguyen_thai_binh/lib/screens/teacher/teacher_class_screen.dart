import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/class_form.dart';
import '../../widgets/class_info_card.dart';
import '../../widgets/common.dart';
import '../../widgets/session_widgets.dart';
import '../common/class_members_screen.dart';
import 'absence_report_screen.dart';
import 'leave_review_screen.dart';
import 'open_session_flow.dart';
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
    return groupSessions(results[1] as List<Json>);
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
    // Admin được đổi giảng viên phụ trách; giảng viên thì không.
    final isAdmin = context.read<AuthProvider>().role == 'Admin';
    final List<Json> subjects;
    List<Json>? teachers;
    try {
      subjects = await api.subjects();
      if (isAdmin) teachers = (await api.users()).where((u) => u['role'] == 'GiangVien').toList();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final data = await showClassForm(context, cls: detail, subjects: subjects, teachers: teachers);
    if (data == null || !mounted) return;
    try {
      await api.updateClass(widget.classId, data);
      if (mounted) showMessage(context, 'Đã cập nhật thông tin lớp.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Mở điểm danh cho buổi đã lên lịch rồi hiện mã QR ngay.
  Future<void> _openSession(Json s) async {
    final opened = await openSessionFlow(context, s);
    if (opened == null || !mounted) return;
    await _open(SessionQrScreen(session: opened));
  }

  Future<void> _closeSession(Json s) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể điểm danh "${s['title']}" nữa. Bạn vẫn mở lại được sau.',
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

  // Thêm một buổi hoặc lịch lặp hằng tuần.
  Future<void> _addSessions() async {
    final api = context.read<ApiService>();
    final planned = _detail?['plannedSessions'] as int? ?? 15;
    final count = _detail?['sessionCount'] as int? ?? 0;
    final result = await showModalBottomSheet<_AddSessionsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSessionsSheet(nextNumber: count + 1, remaining: (planned - count).clamp(1, 60)),
    );
    if (result == null || !mounted) return;
    try {
      if (result.weekly) {
        final res = await api.generateSessions(
          widget.classId,
          firstStartsAt: result.start,
          durationMinutes: result.end.difference(result.start).inMinutes,
          count: result.count,
        );
        if (mounted) showMessage(context, res['message'].toString());
      } else {
        await api.createSession(widget.classId, title: result.title, startsAt: result.start, endsAt: result.end);
        if (mounted) showMessage(context, 'Đã thêm ${result.title}.');
      }
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _sessionCard(Json s) {
    final text = Theme.of(context).textTheme;
    final state = s['state'];
    final remaining = state == 'Open' ? remainingLabel(s['checkInUntil']) : null;
    final relative = relativeDayLabel(s['startsAt']);
    final studentCount = _detail?['studentCount'] as int? ?? 0;
    return TapCard(
      onTap: () => _open(SessionDetailScreen(session: s)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  relative == null ? s['title'].toString() : '${s['title']} • $relative',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              switch (state) {
                'Open' => const StatusChip(label: 'Đang điểm danh', icon: Icons.lock_open_rounded, tone: StatusTone.success),
                'Ended' => const StatusChip(label: 'Đã điểm danh', icon: Icons.lock_outline_rounded),
                _ => const StatusChip(label: 'Chưa mở', icon: Icons.event_outlined, tone: StatusTone.info),
              },
            ],
          ),
          InfoLine(icon: Icons.schedule_rounded, text: formatSchedule(s['startsAt'], s['endsAt'])),
          if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: remaining),
          if (state != 'Planned') InfoLine(icon: Icons.how_to_reg_outlined, text: '${s['presentCount'] ?? 0}/$studentCount sinh viên có mặt'),
          const SizedBox(height: 16),
          if (state == 'Planned')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openSession(s),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Mở điểm danh'),
              ),
            )
          else if (state == 'Open')
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
            )
          else
            Text('Chạm để xem danh sách điểm danh', style: text.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _detail?['nextSession'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSessions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm buổi học'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.event_note_outlined,
        emptyTitle: 'Lớp chưa có lịch học',
        emptyMessage: 'Bấm "Thêm buổi học" để lên lịch một buổi hoặc cả học kỳ.',
        headerBuilder: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_detail != null) ClassInfoCard(detail: _detail!, onEdit: _editClass),
            if (next != null) ...[const SizedBox(height: 12), NextSessionCard(session: next as Json)],
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.groups_rounded,
                  label: 'Sinh viên',
                  onTap: () => _open(ClassMembersScreen(classId: widget.classId, className: widget.className)),
                ),
                const SizedBox(width: 12),
                _QuickAction(icon: Icons.inbox_rounded, label: 'Đơn nghỉ', onTap: () => _open(LeaveReviewScreen(classId: widget.classId))),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.insights_rounded,
                  label: 'Báo cáo vắng',
                  onTap: () => _open(AbsenceReportScreen(classId: widget.classId)),
                ),
              ],
            ),
          ],
        ),
        itemBuilder: (context, s) => s.containsKey(sectionKey) ? SectionHeader(s[sectionKey].toString()) : _sessionCard(s),
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

class _AddSessionsResult {
  const _AddSessionsResult({required this.weekly, required this.title, required this.start, required this.end, required this.count});

  final bool weekly;
  final String title;
  final DateTime start;
  final DateTime end;
  final int count;
}

class _AddSessionsSheet extends StatefulWidget {
  const _AddSessionsSheet({required this.nextNumber, required this.remaining});

  final int nextNumber;
  final int remaining;

  @override
  State<_AddSessionsSheet> createState() => _AddSessionsSheetState();
}

class _AddSessionsSheetState extends State<_AddSessionsSheet> {
  late final _title = TextEditingController(text: 'Buổi ${widget.nextNumber}');
  late final _count = TextEditingController(text: '${widget.remaining}');
  bool _weekly = false;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _count.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    final start = DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);
    final end = DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);
    final count = int.tryParse(_count.text.trim()) ?? 0;
    String? error;
    if (!end.isAfter(start)) {
      error = 'Giờ kết thúc phải sau giờ bắt đầu.';
    } else if (_weekly && (count < 1 || count > 60)) {
      error = 'Số buổi phải từ 1 đến 60.';
    } else if (!_weekly && _title.text.trim().isEmpty) {
      error = 'Vui lòng nhập tên buổi học.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _AddSessionsResult(weekly: _weekly, title: _title.text.trim(), start: start, end: end, count: count));
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
            Text('Thêm buổi học', style: text.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Một buổi'), icon: Icon(Icons.event_outlined)),
                ButtonSegment(value: true, label: Text('Hằng tuần'), icon: Icon(Icons.event_repeat_outlined)),
              ],
              selected: {_weekly},
              onSelectionChanged: (v) => setState(() => _weekly = v.first),
            ),
            const SizedBox(height: 16),
            if (!_weekly)
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tên buổi học')),
            if (_weekly)
              TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số buổi',
                  helperText: 'Mỗi tuần một buổi, cùng thứ và giờ với buổi đầu tiên',
                ),
              ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(_weekly ? 'Buổi đầu tiên' : 'Ngày học'),
              subtitle: Text('${_two(_date.day)}/${_two(_date.month)}/${_date.year}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Bắt đầu'),
                    subtitle: Text('${_two(_start.hour)}:${_two(_start.minute)}'),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Kết thúc'),
                    subtitle: Text('${_two(_end.hour)}:${_two(_end.minute)}'),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: Text(_weekly ? 'Tạo lịch hằng tuần' : 'Thêm buổi học')),
          ],
        ),
      ),
    );
  }
}
