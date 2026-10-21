import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

// Mở điểm danh cho một buổi đã lên lịch: chọn thời gian và phạm vi, lấy GPS lớp, gọi API.
// Trả về buổi học sau khi mở (có qrToken, checkInUntil), hoặc null nếu huỷ/lỗi.
Future<Json?> openSessionFlow(BuildContext context, Json session) async {
  final api = context.read<ApiService>();
  final options = await showModalBottomSheet<(double, int)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OpenSheet(session: session),
  );
  if (options == null || !context.mounted) return null;
  try {
    final opened = await runWithProgress(context, 'Đang lấy vị trí lớp và mở điểm danh...', () async {
      final position = await currentPosition();
      return api.openSession(
        session['id'] as int,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: options.$1,
        durationMinutes: options.$2 == 0 ? null : options.$2,
      );
    });
    return {...session, ...opened};
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

class _OpenSheet extends StatefulWidget {
  const _OpenSheet({required this.session});

  final Json session;

  @override
  State<_OpenSheet> createState() => _OpenSheetState();
}

class _OpenSheetState extends State<_OpenSheet> {
  double _radius = 100;
  int _minutes = 15;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = widget.session;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mở điểm danh', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('${s['title']} • ${formatSchedule(s['startsAt'], s['endsAt'])}', style: text.bodyMedium),
            const SizedBox(height: 20),
            Text('Sinh viên được điểm danh trong', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [(10, '10 phút'), (15, '15 phút'), (30, '30 phút'), (45, '45 phút'), (0, 'Đến khi đóng')])
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
              onSelectionChanged: (v) => setState(() => _radius = v.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.my_location_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vị trí lớp được lấy từ GPS hiện tại của bạn. Hãy mở điểm danh khi đang ở trong lớp.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, (_radius, _minutes)),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Mở điểm danh và hiện mã QR'),
            ),
          ],
        ),
      ),
    );
  }
}
