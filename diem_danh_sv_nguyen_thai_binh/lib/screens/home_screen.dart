import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin/admin_home_screen.dart';
import 'student/student_home_screen.dart';
import 'teacher/teacher_home_screen.dart';

// Chọn màn hình chính theo role lấy từ JWT khi đăng nhập.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    switch (role) {
      case 'Admin':
        return const AdminHomeScreen();
      case 'GiangVien':
        return const TeacherHomeScreen();
      default:
        return const StudentHomeScreen();
    }
  }
}
