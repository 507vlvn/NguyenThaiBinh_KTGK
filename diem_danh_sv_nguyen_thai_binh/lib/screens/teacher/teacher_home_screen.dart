import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/class_form.dart';
import '../../widgets/common.dart';
import '../common/profile_view.dart';
import 'teacher_class_screen.dart';

// Dashboard giảng viên: danh sách lớp dạy và tài khoản.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab lớp để tải lại danh sách lớp.
  int _classesVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'Lớp đang dạy' : 'Tài khoản')),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('classes-$_classesVersion'), child: const _ClassesTab()),
          const ProfileView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          if (i == 0) _classesVersion++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.co_present_outlined), selectedIcon: Icon(Icons.co_present_rounded), label: 'Lớp dạy'),
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

  // Giảng viên tự tạo lớp; server tự gán giảng viên là người tạo.
  Future<void> _createClass() async {
    final api = context.read<ApiService>();
    final List<Json> subjects;
    try {
      subjects = await api.subjects();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (subjects.isEmpty) {
      showMessage(context, 'Chưa có môn học nào. Hãy nhờ quản trị viên tạo môn học trước.');
      return;
    }
    final data = await showClassForm(context, subjects: subjects);
    if (data == null || !mounted) return;
    try {
      await api.createClass(data);
      if (mounted) showMessage(context, 'Đã tạo lớp ${data['name']}.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().fullName ?? '';
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo lớp'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.co_present_outlined,
        emptyTitle: 'Bạn chưa có lớp nào',
        emptyMessage: 'Bấm "Tạo lớp" để tạo lớp học đầu tiên, sau đó thêm sinh viên vào lớp.',
        headerBuilder: (items) => Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chào thầy/cô $name', style: text.titleLarge?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Bạn đang phụ trách ${items.length} lớp. Chọn lớp để mở buổi học và điểm danh.',
                  style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        itemBuilder: (context, c) {
          final room = c['room']?.toString();
          final schedule = c['schedule']?.toString();
          return TapCard(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeacherClassScreen(classId: c['id'] as int, className: c['name'].toString())),
              );
              _reload();
            },
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
                      if (schedule != null && schedule.isNotEmpty) InfoLine(icon: Icons.calendar_month_outlined, text: schedule),
                      InfoLine(
                        icon: Icons.groups_outlined,
                        text: '${c['studentCount']} sinh viên${room != null && room.isNotEmpty ? ' • $room' : ''}',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          );
        },
      ),
    );
  }
}
