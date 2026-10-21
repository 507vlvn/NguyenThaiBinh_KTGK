import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'admin_class_students_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản trị'),
          actions: [IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: auth.logout)],
          bottom: const TabBar(tabs: [
            Tab(text: 'Người dùng'),
            Tab(text: 'Môn học'),
            Tab(text: 'Lớp học'),
          ]),
        ),
        body: const TabBarView(children: [_UsersTab(), _SubjectsTab(), _ClassesTab()]),
      ),
    );
  }
}

// Danh sách có nút xoá, dùng chung cho các tab.
class _ListTab extends StatelessWidget {
  const _ListTab({required this.future, required this.itemBuilder, required this.onAdd, required this.onRefresh});

  final Future<List<Json>> future;
  final Widget Function(BuildContext context, Json item) itemBuilder;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: onAdd, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Json>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Chưa có dữ liệu.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => itemBuilder(context, list[i]),
          );
        },
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, String what, Future<void> Function() action, VoidCallback onDone) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xoá?'),
      content: Text('Xoá $what? Không thể hoàn tác.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xoá')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await action();
    onDone();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

// ---------- Người dùng ----------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().users();
  }

  void _reload() => setState(() => _future = context.read<ApiService>().users());

  Future<void> _add() async {
    final api = context.read<ApiService>();
    final username = TextEditingController();
    final email = TextEditingController();
    final fullName = TextEditingController();
    final password = TextEditingController();
    String role = 'SinhVien';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Thêm người dùng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fullName, decoration: const InputDecoration(labelText: 'Họ và tên')),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Tên đăng nhập')),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'SinhVien', child: Text('Sinh viên')),
                    DropdownMenuItem(value: 'GiangVien', child: Text('Giảng viên')),
                    DropdownMenuItem(value: 'Admin', child: Text('Quản trị')),
                  ],
                  onChanged: (v) => setDialog(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      try {
        await api.createUser(
          username: username.text.trim(),
          email: email.text.trim(),
          password: password.text,
          fullName: fullName.text.trim(),
          role: role,
        );
        _reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    for (final c in [username, email, fullName, password]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ListTab(
      future: _future,
      onAdd: _add,
      onRefresh: _reload,
      itemBuilder: (context, u) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text('${u['fullName']} (${u['username']})'),
        subtitle: Text('${u['email']} • ${roleLabel(u['role'].toString())}'),
        trailing: IconButton(
          tooltip: 'Xoá',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(
            context,
            'người dùng ${u['username']}',
            () => context.read<ApiService>().deleteUser(u['id'] as int),
            _reload,
          ),
        ),
      ),
    );
  }
}

// ---------- Môn học ----------

class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().subjects();
  }

  void _reload() => setState(() => _future = context.read<ApiService>().subjects());

  Future<void> _add() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm môn học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã môn')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên môn')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Thêm')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await context.read<ApiService>().createSubject(code.text.trim(), name.text.trim());
        _reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    code.dispose();
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ListTab(
      future: _future,
      onAdd: _add,
      onRefresh: _reload,
      itemBuilder: (context, s) => ListTile(
        title: Text(s['name'].toString()),
        subtitle: Text(s['code'].toString()),
        trailing: IconButton(
          tooltip: 'Xoá',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(
            context,
            'môn ${s['name']}',
            () => context.read<ApiService>().deleteSubject(s['id'] as int),
            _reload,
          ),
        ),
      ),
    );
  }
}

// ---------- Lớp học ----------

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

  void _reload() => setState(() => _future = context.read<ApiService>().classes());

  Future<void> _add() async {
    final api = context.read<ApiService>();
    final name = TextEditingController();
    final subjects = await api.subjects();
    final users = await api.users();
    final teachers = users.where((u) => u['role'] == 'GiangVien').toList();
    if (!mounted) return;
    if (subjects.isEmpty || teachers.isEmpty) {
      showMessage(context, 'Cần có ít nhất 1 môn học và 1 giảng viên.');
      name.dispose();
      return;
    }

    int subjectId = subjects.first['id'] as int;
    int teacherId = teachers.first['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Thêm lớp học'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên lớp')),
                DropdownButtonFormField<int>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Môn học'),
                  items: [for (final s in subjects) DropdownMenuItem(value: s['id'] as int, child: Text(s['name'].toString()))],
                  onChanged: (v) => setDialog(() => subjectId = v ?? subjectId),
                ),
                DropdownButtonFormField<int>(
                  initialValue: teacherId,
                  decoration: const InputDecoration(labelText: 'Giảng viên'),
                  items: [for (final t in teachers) DropdownMenuItem(value: t['id'] as int, child: Text(t['fullName'].toString()))],
                  onChanged: (v) => setDialog(() => teacherId = v ?? teacherId),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      try {
        await api.createClass(name.text.trim(), subjectId, teacherId);
        _reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ListTab(
      future: _future,
      onAdd: _add,
      onRefresh: _reload,
      itemBuilder: (context, c) => ListTile(
        title: Text(c['name'].toString()),
        subtitle: Text('${c['subject']} • GV: ${c['teacher']}'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminClassStudentsScreen(classId: c['id'] as int, className: c['name'].toString())),
        ),
        trailing: IconButton(
          tooltip: 'Xoá lớp',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(
            context,
            'lớp ${c['name']}',
            () => context.read<ApiService>().deleteClass(c['id'] as int),
            _reload,
          ),
        ),
      ),
    );
  }
}
