import 'package:flutter/material.dart';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString())),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// API lưu giờ UTC nhưng trả về chuỗi không có hậu tố múi giờ, nên phải coi là UTC
// trước khi đổi sang giờ địa phương (nếu không sẽ lệch 7 tiếng ở Việt Nam).
DateTime parseApiDate(String iso) {
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso);
  return DateTime.parse(hasZone ? iso : '${iso}Z').toLocal();
}

String _two(int n) => n.toString().padLeft(2, '0');

// dd/MM/yyyy HH:mm (giờ địa phương).
String formatDateTime(String iso) {
  final d = parseApiDate(iso);
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

// HH:mm (giờ địa phương).
String formatTime(String iso) {
  final d = parseApiDate(iso);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

const _weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

// "Thứ 2, 26/10/2026 • 07:00 - 10:30" cho giờ học của một buổi.
String formatSchedule(Object startsAt, Object? endsAt) {
  final s = parseApiDate(startsAt.toString());
  final day = '${_weekdays[s.weekday - 1]}, ${_two(s.day)}/${_two(s.month)}/${s.year}';
  final end = endsAt == null ? '' : ' - ${formatTime(endsAt.toString())}';
  return '$day • ${_two(s.hour)}:${_two(s.minute)}$end';
}

// "Hôm nay", "Ngày mai", hoặc null.
String? relativeDayLabel(Object startsAt) {
  final s = parseApiDate(startsAt.toString());
  final today = DateTime.now();
  final d = DateTime(s.year, s.month, s.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  return switch (d) { 0 => 'Hôm nay', 1 => 'Ngày mai', _ => null };
}

// "Còn 12 phút" cho buổi có hạn điểm danh; null nếu không có hạn hoặc đã hết giờ.
String? remainingLabel(Object? endsAt) {
  if (endsAt == null) return null;
  final left = parseApiDate(endsAt.toString()).difference(DateTime.now());
  if (left.isNegative) return null;
  if (left.inMinutes < 1) return 'Còn dưới 1 phút';
  if (left.inMinutes < 60) return 'Còn ${left.inMinutes} phút';
  return 'Còn ${left.inHours} giờ ${left.inMinutes % 60} phút';
}

String leaveStatusLabel(String status) {
  switch (status) {
    case 'Approved':
      return 'Được duyệt';
    case 'Rejected':
      return 'Từ chối';
    default:
      return 'Chờ duyệt';
  }
}

String roleLabel(String role) {
  switch (role) {
    case 'Admin':
      return 'Quản trị';
    case 'GiangVien':
      return 'Giảng viên';
    default:
      return 'Sinh viên';
  }
}
