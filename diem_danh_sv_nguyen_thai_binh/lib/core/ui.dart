import 'package:flutter/material.dart';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString())),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// Định dạng thời gian ISO từ API thành dd/MM/yyyy HH:mm (giờ địa phương).
String formatDateTime(String iso) {
  final d = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
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
