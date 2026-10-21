import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/class_info_card.dart';
import '../../widgets/common.dart';
import 'leave_request_screen.dart';
import 'scan_qr_screen.dart';

// Màn hình lớp của sinh viên: thông tin lớp, thống kê đi học và danh sách buổi học.
class StudentClassScreen extends StatefulWidget {
  const StudentClassScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  late Future<List<Json>> _future;
  Json? _detail;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Tải chi tiết lớp cùng lúc với danh sách buổi; buổi đang mở lên đầu.
  Future<List<Json>> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([api.classDetail(widget.classId), api.sessions(widget.classId)]);
    final detail = results[0] as Json;
    final list = results[1] as List<Json>;
    list.sort((a, b) {
      final open = (b['isOpen'] == true ? 1 : 0) - (a['isOpen'] == true ? 1 : 0);
      return open != 0 ? open : b['startsAt'].toString().compareTo(a['startsAt'].toString());
    });
    if (mounted) setState(() => _detail = detail);
    return list;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  // Ảnh minh chứng là tuỳ chọn. Đóng bảng chọn = huỷ điểm danh.
  Future<String?> _askPhoto() {
    final text = Theme.of(context).textTheme;
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gửi kèm ảnh minh chứng?', style: text.titleLarge),
              const SizedBox(height: 8),
              Text('Ảnh giúp giảng viên xác nhận bạn có mặt trong lớp. Bạn có thể bỏ qua bước này.', style: text.bodyMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'photo'),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Chụp ảnh và gửi'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.pop(sheetContext, 'skip'), child: const Text('Gửi không kèm ảnh')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkIn(Json session) async {
    final api = context.read<ApiService>();

    // Bước 1: quét mã QR trên màn hình giảng viên.
    final token = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanQrScreen()));
    if (token == null || !mounted) return;

    // Bước 2: ảnh minh chứng (tuỳ chọn).
    final choice = await _askPhoto();
    if (choice == null || !mounted) return;
    String? photoPath;
    if (choice == 'photo') {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
      if (picked == null || !mounted) return;
      photoPath = picked.path;
    }
    if (!mounted) return;

    // Bước 3: lấy GPS và gửi điểm danh.
    try {
      final res = await runWithProgress(context, 'Đang xác định vị trí và gửi điểm danh...', () async {
        final position = await currentPosition();
        return api.checkIn(
          sessionId: session['id'] as int,
          qrToken: token,
          latitude: position.latitude,
          longitude: position.longitude,
          photoPath: photoPath,
        );
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showResultDialog(
        context,
        success: true,
        title: 'Điểm danh thành công',
        message: 'Bạn đã điểm danh buổi "${session['title']}". Khoảng cách tới lớp: ${res['distanceMeters']} m.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(context, success: false, title: 'Chưa điểm danh được', message: e.toString());
    }
  }

  Widget _statsCard(Json stats) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final remaining = stats['remainingAbsences'] as int;
    final absent = stats['absentSessions'] as int;
    final allowed = absent + remaining;
    final danger = remaining <= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tình hình đi học (${stats['totalSessions']} buổi đã kết thúc)', style: text.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(value: '${stats['presentSessions']}', label: 'Có mặt', icon: Icons.check_circle_rounded, color: const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                StatTile(value: '${stats['excusedSessions']}', label: 'Có phép', icon: Icons.assignment_turned_in_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                StatTile(value: '$absent', label: 'Vắng', icon: Icons.cancel_rounded, color: scheme.error),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(danger ? Icons.warning_amber_rounded : Icons.event_available_rounded, color: danger ? scheme.error : scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remaining > 0
                        ? 'Bạn còn được nghỉ tối đa $remaining/$allowed buổi'
                        : 'Bạn đã nghỉ vượt ${-remaining} buổi so với mức cho phép ($allowed buổi)',
                    style: text.bodyMedium?.copyWith(color: danger ? scheme.error : null, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: allowed <= 0 ? 1 : (absent / allowed).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: danger ? scheme.error : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                semanticsLabel: 'Số buổi đã nghỉ so với mức cho phép',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Trạng thái của sinh viên trong một buổi.
  StatusChip _statusChip(Json s, bool open) {
    if (s['checkedIn'] == true) {
      return const StatusChip(label: 'Có mặt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
    }
    final leave = s['leaveStatus'];
    if (leave == 'Approved') return const StatusChip(label: 'Có phép', icon: Icons.assignment_turned_in_rounded, tone: StatusTone.info);
    if (leave == 'Pending') return const StatusChip(label: 'Chờ duyệt đơn', icon: Icons.hourglass_top_rounded, tone: StatusTone.warning);
    if (open) return const StatusChip(label: 'Đang mở', icon: Icons.lock_open_rounded, tone: StatusTone.info);
    return const StatusChip(label: 'Vắng', icon: Icons.cancel_rounded, tone: StatusTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        emptyIcon: Icons.event_busy_outlined,
        emptyTitle: 'Chưa có buổi học nào',
        emptyMessage: 'Khi giảng viên mở buổi học, nút "Điểm danh" sẽ hiện ở đây. Kéo xuống để làm mới.',
        headerBuilder: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_detail != null) ClassInfoCard(detail: _detail!),
            if (_detail?['myStats'] != null) ...[const SizedBox(height: 12), _statsCard(_detail!['myStats'] as Json)],
            const SizedBox(height: 24),
            Text('Buổi học (${items.length})', style: text.titleMedium),
          ],
        ),
        itemBuilder: (context, s) {
          final open = s['isOpen'] == true;
          final checkedIn = s['checkedIn'] == true;
          final remaining = open ? remainingLabel(s['endsAt']) : null;
          final endsAt = s['endsAt'];
          return Card(
            shape: open && !checkedIn
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.primary, width: 2))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s['title'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                      _statusChip(s, open),
                    ],
                  ),
                  InfoLine(
                    icon: Icons.event_outlined,
                    text: endsAt == null
                        ? formatDateTime(s['startsAt'].toString())
                        : '${formatDateTime(s['startsAt'].toString())} - ${formatTime(endsAt.toString())}',
                  ),
                  if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: '$remaining để điểm danh'),
                  InfoLine(icon: Icons.near_me_outlined, text: 'Phạm vi điểm danh: ${(s['radiusMeters'] as num).round()} m'),
                  if (s['leaveStatus'] == 'Rejected')
                    const InfoLine(icon: Icons.info_outline_rounded, text: 'Đơn xin nghỉ bị từ chối'),
                  if ((open && !checkedIn) || (!checkedIn && s['leaveStatus'] == null)) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (open && !checkedIn) ...[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _checkIn(s),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Điểm danh'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (s['leaveStatus'] == null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeaveRequestScreen(sessionId: s['id'] as int, sessionTitle: s['title'].toString()),
                                  ),
                                );
                                _reload();
                              },
                              child: const Text('Xin nghỉ'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
