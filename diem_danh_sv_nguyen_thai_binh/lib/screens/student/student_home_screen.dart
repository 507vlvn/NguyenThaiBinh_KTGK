import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../common/profile_view.dart';
import 'my_leaves_screen.dart';
import 'student_class_screen.dart';

// Khu vực sinh viên: thanh điều hướng dưới với 3 mục chính.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab để tab đó tạo lại và tải dữ liệu mới.
  final _versions = [0, 0, 0];

  static const _titles = ['Lớp học của tôi', 'Đơn xin nghỉ', 'Tài khoản'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('classes-${_versions[0]}'), child: const _ClassesTab()),
          KeyedSubtree(key: ValueKey('leaves-${_versions[1]}'), child: const MyLeavesView()),
          const ProfileView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _versions[i]++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_rounded), label: 'Lớp học'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Đơn nghỉ'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class _ClassesTab extends StatefulWidget {
  const _ClassesTab();

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classes();
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().classes());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().fullName ?? '';
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AsyncListView(
      future: _future,
      onRefresh: _reload,
      emptyIcon: Icons.class_outlined,
      emptyTitle: 'Bạn chưa có lớp nào',
      emptyMessage: 'Khi quản trị viên thêm bạn vào lớp, lớp sẽ hiện ở đây.',
      headerBuilder: (items) => Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xin chào, $name', style: text.titleLarge?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                items.isEmpty ? 'Hôm nay bạn chưa có lớp nào.' : 'Bạn đang học ${items.length} lớp. Chọn lớp để điểm danh.',
                style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (context, c) => TapCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentClassScreen(classId: c['id'] as int, className: c['name'].toString())),
        ),
        child: Row(
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
                  Text(c['name'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  InfoLine(icon: Icons.book_outlined, text: c['subject'].toString()),
                  InfoLine(icon: Icons.person_outline_rounded, text: 'GV: ${c['teacher']}'),
                  if ((c['schedule']?.toString() ?? '').isNotEmpty)
                    InfoLine(
                      icon: Icons.calendar_month_outlined,
                      text: '${c['schedule']}${(c['room']?.toString() ?? '').isNotEmpty ? ' • ${c['room']}' : ''}',
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
