import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../common/profile_view.dart';
import '../../widgets/class_form.dart';
import '../teacher/teacher_class_screen.dart';

// Trang quản trị: người dùng, môn học, lớp học và tài khoản.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab để tab đó tạo lại và tải dữ liệu mới.
  final _versions = [0, 0, 0, 0];

  static const _titles = ['Người dùng', 'Môn học', 'Lớp học', 'Tài khoản'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('users-${_versions[0]}'), child: const _UsersTab()),
          KeyedSubtree(key: ValueKey('subjects-${_versions[1]}'), child: const _SubjectsTab()),
          KeyedSubtree(key: ValueKey('classes-${_versions[2]}'), child: const _ClassesTab()),
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
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Người dùng'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book_rounded), label: 'Môn học'),
          NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_rounded), label: 'Lớp học'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

// Menu "Sửa / Xoá" trên mỗi thẻ.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      tooltip: 'Tuỳ chọn',
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa'))),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: error), title: Text('Xoá', style: TextStyle(color: error))),
        ),
      ],
    );
  }
}

Future<void> _delete(BuildContext context, String what, Future<void> Function() action, VoidCallback onDone) async {
  final ok = await confirmAction(
    context,
    title: 'Xoá $what?',
    message: 'Thao tác này không thể hoàn tác.',
    confirmLabel: 'Xoá',
    destructive: true,
  );
  if (!ok) return;
  try {
    await action();
    if (context.mounted) showMessage(context, 'Đã xoá $what.');
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
  List<Json>? _users;
  String? _error;
  String _query = '';
  String _role = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<ApiService>().users();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Json> get _filtered {
    final q = _query.trim().toLowerCase();
    return (_users ?? []).where((u) {
      if (_role != 'All' && u['role'] != _role) return false;
      if (q.isEmpty) return true;
      return '${u['fullName']} ${u['username']} ${u['email']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openForm([Json? user]) async {
    final api = context.read<ApiService>();
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserForm(user: user),
    );
    if (values == null || !mounted) return;
    try {
      if (user == null) {
        await api.createUser(
          username: values['username'],
          email: values['email'],
          password: values['password'],
          fullName: values['fullName'],
          role: values['role'],
        );
      } else {
        await api.updateUser(
          user['id'] as int,
          email: values['email'],
          fullName: values['fullName'],
          role: values['role'],
          isActive: values['isActive'],
        );
      }
      if (mounted) showMessage(context, user == null ? 'Đã thêm người dùng.' : 'Đã lưu thay đổi.');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_users == null) {
      body = const SkeletonList();
    } else {
      final list = _filtered;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Tìm theo tên, tài khoản, email', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [('All', 'Tất cả'), ('SinhVien', 'Sinh viên'), ('GiangVien', 'Giảng viên'), ('Admin', 'Quản trị')])
                  ChoiceChip(label: Text(label), selected: _role == value, onSelected: (_) => setState(() => _role = value)),
              ],
            ),
            const SizedBox(height: 16),
            Text('${list.length} người dùng', style: text.titleMedium),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(icon: Icons.person_search_outlined, title: 'Không tìm thấy người dùng phù hợp')
            else
              for (final u in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TapCard(
                    onTap: () => _openForm(u),
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        InitialsAvatar(name: u['fullName'].toString()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['fullName'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text('${u['username']} • ${u['email']}', style: text.bodySmall),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  StatusChip(label: roleLabel(u['role'].toString()), icon: Icons.badge_outlined, tone: StatusTone.info),
                                  if (u['isActive'] != true)
                                    const StatusChip(label: 'Chưa kích hoạt', icon: Icons.block_rounded, tone: StatusTone.warning),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _ItemMenu(
                          onEdit: () => _openForm(u),
                          onDelete: () => _delete(
                            context,
                            'người dùng ${u['username']}',
                            () => context.read<ApiService>().deleteUser(u['id'] as int),
                            _load,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm'),
      ),
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final Json? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user?['fullName']?.toString() ?? '');
  late final _email = TextEditingController(text: widget.user?['email']?.toString() ?? '');
  final _username = TextEditingController();
  final _password = TextEditingController();
  late String _role = widget.user?['role']?.toString() ?? 'SinhVien';
  late bool _isActive = widget.user?['isActive'] != false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [_fullName, _email, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'username': _username.text.trim(),
      'password': _password.text,
      'role': _role,
      'isActive': _isActive,
    });
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Sửa người dùng' : 'Thêm người dùng', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email chưa đúng định dạng' : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Tên đăng nhập'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu', helperText: 'Tối thiểu 6 ký tự'),
                  validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu cần tối thiểu 6 ký tự' : null,
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SinhVien', label: Text('Sinh viên')),
                  ButtonSegment(value: 'GiangVien', label: Text('Giảng viên')),
                  ButtonSegment(value: 'Admin', label: Text('Quản trị')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (_isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tài khoản đang hoạt động'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm người dùng')),
            ],
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

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().subjects());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _openForm([Json? subject]) async {
    final api = context.read<ApiService>();
    final code = TextEditingController(text: subject?['code']?.toString() ?? '');
    final name = TextEditingController(text: subject?['name']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(subject == null ? 'Thêm môn học' : 'Sửa môn học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Mã môn')),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên môn')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Lưu')),
        ],
      ),
    );
    final codeText = code.text.trim();
    final nameText = name.text.trim();
    code.dispose();
    name.dispose();
    if (ok != true || !mounted) return;
    if (codeText.isEmpty || nameText.isEmpty) {
      showMessage(context, 'Vui lòng nhập đủ mã môn và tên môn.');
      return;
    }
    try {
      if (subject == null) {
        await api.createSubject(codeText, nameText);
      } else {
        await api.updateSubject(subject['id'] as int, codeText, nameText);
      }
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.book_outlined,
        emptyTitle: 'Chưa có môn học',
        emptyMessage: 'Bấm "Thêm" để tạo môn học đầu tiên.',
        itemBuilder: (context, s) => TapCard(
          onTap: () => _openForm(s),
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(s['code'].toString(), style: text.labelLarge?.copyWith(color: scheme.onSecondaryContainer)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(s['name'].toString(), style: text.titleMedium)),
              _ItemMenu(
                onEdit: () => _openForm(s),
                onDelete: () => _delete(context, 'môn ${s['name']}', () => context.read<ApiService>().deleteSubject(s['id'] as int), _reload),
              ),
            ],
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

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().classes());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _openForm([Json? cls]) async {
    final api = context.read<ApiService>();
    final List<Json> subjects;
    final List<Json> teachers;
    try {
      subjects = await api.subjects();
      teachers = (await api.users()).where((u) => u['role'] == 'GiangVien').toList();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (subjects.isEmpty || teachers.isEmpty) {
      showMessage(context, 'Cần có ít nhất 1 môn học và 1 giảng viên trước khi tạo lớp.');
      return;
    }

    final data = await showClassForm(context, cls: cls, subjects: subjects, teachers: teachers);
    if (data == null || !mounted) return;
    try {
      if (cls == null) {
        await api.createClass(data);
      } else {
        await api.updateClass(cls['id'] as int, data);
      }
      if (mounted) showMessage(context, cls == null ? 'Đã tạo lớp ${data['name']}.' : 'Đã lưu thay đổi.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.class_outlined,
        emptyTitle: 'Chưa có lớp học',
        emptyMessage: 'Tạo môn học và tài khoản giảng viên trước, rồi bấm "Thêm".',
        itemBuilder: (context, c) => TapCard(
          // Admin vào màn hình lớp giống giảng viên: lịch học, mở điểm danh, QR, đơn nghỉ, báo cáo vắng, sinh viên.
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeacherClassScreen(classId: c['id'] as int, className: c['name'].toString())),
          ).then((_) => _reload()),
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
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
                    InfoLine(
                      icon: Icons.groups_outlined,
                      text: '${c['studentCount']} sinh viên • Chạm để quản lý lớp và điểm danh',
                    ),
                  ],
                ),
              ),
              _ItemMenu(
                onEdit: () => _openForm(c),
                onDelete: () => _delete(context, 'lớp ${c['name']}', () => context.read<ApiService>().deleteClass(c['id'] as int), _reload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
