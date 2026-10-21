import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'common.dart';

// Thẻ thông tin lớp: môn học, giảng viên, phòng, lịch học, sĩ số, số buổi.
class ClassInfoCard extends StatelessWidget {
  const ClassInfoCard({super.key, required this.detail, this.onEdit});

  final Json detail;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final room = detail['room']?.toString();
    final schedule = detail['schedule']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.menu_book_rounded, color: scheme.onSecondaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail['subject'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Mã môn: ${detail['subjectCode']}', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(tooltip: 'Sửa thông tin lớp', icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              ],
            ),
            const SizedBox(height: 12),
            InfoLine(icon: Icons.person_outline_rounded, text: 'Giảng viên: ${detail['teacher']}'),
            InfoLine(icon: Icons.meeting_room_outlined, text: 'Phòng: ${room == null || room.isEmpty ? 'Chưa cập nhật' : room}'),
            InfoLine(icon: Icons.calendar_month_outlined, text: 'Lịch học: ${schedule == null || schedule.isEmpty ? 'Chưa cập nhật' : schedule}'),
            InfoLine(
              icon: Icons.groups_outlined,
              text: '${detail['studentCount']} sinh viên • ${detail['sessionCount']}/${detail['plannedSessions']} buổi đã tạo',
            ),
          ],
        ),
      ),
    );
  }
}

// Ô số liệu nhỏ: con số lớn + nhãn.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, this.color});

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: c)),
            Text(label, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
