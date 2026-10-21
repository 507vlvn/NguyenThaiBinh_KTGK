import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

// Danh sách sinh viên của lớp. Admin và giảng viên phụ trách đều thêm/bớt sinh viên được.
class ClassMembersScreen extends StatefulWidget {
  const ClassMembersScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<ClassMembersScreen> createState() => _ClassMembersScreenState();
}

class _ClassMembersScreenState extends State<ClassMembersScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classStudents(widget.classId);
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().classStudents(widget.classId));
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _add() async {
    final api = context.read<ApiService>();
    final picked = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StudentPicker(classId: widget.classId),
    );
    if (picked == null || !mounted) return;
    try {
      await api.enroll(widget.classId, picked['id'] as int);
      if (mounted) showMessage(context, 'Đã thêm ${picked['fullName']} vào lớp.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(Json s) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Bỏ khỏi lớp?',
      message: 'Bỏ ${s['fullName']} khỏi lớp ${widget.className}. Dữ liệu điểm danh cũ vẫn được giữ.',
      confirmLabel: 'Bỏ khỏi lớp',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.unenroll(widget.classId, s['studentId'] as int);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Sinh viên • ${widget.className}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm sinh viên'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: 'Lớp chưa có sinh viên',
        emptyMessage: 'Bấm "Thêm sinh viên" để đưa sinh viên vào lớp.',
        headerBuilder: (items) => Text('${items.length} sinh viên', style: text.titleMedium),
        itemBuilder: (context, s) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: InitialsAvatar(name: s['fullName'].toString()),
            title: Text(s['fullName'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${s['username']} • ${s['email']}'),
            trailing: IconButton(
              tooltip: 'Bỏ ${s['fullName']} khỏi lớp',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () => _remove(s),
            ),
          ),
        ),
      ),
    );
  }
}

// Tìm sinh viên chưa có trong lớp (tìm trên server, chờ 300ms sau khi ngừng gõ).
class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.classId});

  final int classId;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  Timer? _debounce;
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classCandidates(widget.classId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _future = context.read<ApiService>().classCandidates(widget.classId, query: q.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Tìm theo tên, tài khoản, email', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: _onQuery,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Json>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text(snap.error.toString()));
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Không tìm thấy sinh viên',
                      message: 'Sinh viên cần có tài khoản và đã xác nhận email.',
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return ListTile(
                        leading: InitialsAvatar(name: s['fullName'].toString(), size: 40),
                        title: Text(s['fullName'].toString()),
                        subtitle: Text('${s['username']} • ${s['email']}'),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
