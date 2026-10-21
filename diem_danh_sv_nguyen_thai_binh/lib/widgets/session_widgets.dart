import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../services/api_service.dart';

// Khoá đánh dấu một dòng tiêu đề nhóm trong danh sách buổi học.
const sectionKey = '_section';

// Chia buổi học thành 3 nhóm: đang điểm danh, sắp tới (gần nhất trước), đã qua (mới nhất trước).
// Trả về một danh sách phẳng có chèn dòng tiêu đề nhóm ({sectionKey: tên nhóm}).
List<Json> groupSessions(List<Json> sessions) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final open = <Json>[];
  final upcoming = <Json>[];
  final past = <Json>[];
  for (final s in sessions) {
    final start = parseApiDate(s['startsAt'].toString());
    if (s['state'] == 'Open') {
      open.add(s);
    } else if (s['state'] == 'Planned' && !start.isBefore(todayStart)) {
      upcoming.add(s);
    } else {
      past.add(s);
    }
  }
  int byStart(Json a, Json b) => a['startsAt'].toString().compareTo(b['startsAt'].toString());
  open.sort(byStart);
  upcoming.sort(byStart);
  past.sort((a, b) => byStart(b, a));
  return [
    if (open.isNotEmpty) ...[<String, dynamic>{sectionKey: 'Đang điểm danh'}, ...open],
    if (upcoming.isNotEmpty) ...[<String, dynamic>{sectionKey: 'Sắp tới (${upcoming.length})'}, ...upcoming],
    if (past.isNotEmpty) ...[<String, dynamic>{sectionKey: 'Đã qua (${past.length})'}, ...past],
  ];
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// Thẻ nổi bật "Buổi học tiếp theo".
class NextSessionCard extends StatelessWidget {
  const NextSessionCard({super.key, required this.session});

  final Json session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final relative = relativeDayLabel(session['startsAt']);
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.upcoming_rounded, color: scheme.onTertiaryContainer, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buổi học tiếp theo${relative == null ? '' : ' • $relative'}',
                    style: text.labelLarge?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                  Text(session['title'].toString(),
                      style: text.titleMedium?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w700)),
                  Text(formatSchedule(session['startsAt'], session['endsAt']),
                      style: text.bodyMedium?.copyWith(color: scheme.onTertiaryContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
