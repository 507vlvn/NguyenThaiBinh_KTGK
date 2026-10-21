import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';

// Quản trị viên thêm/bớt sinh viên trong lớp.
class AdminClassStudentsScreen extends StatefulWidget {
  const AdminClassStudentsScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<AdminClassStudentsScreen> createState() => _AdminClassStudentsScreenState();
}

class _AdminClassStudentsScreenState extends State<AdminClassStudentsScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classStudents(widget.classId);
  }

  void _reload() => setState(() => _future = context.read<ApiService>().classStudents(widget.classId));

  Future<void> _enroll() async {
    final api = context.read<ApiService>();
    final all = await api.users();
    final enrolled = (await api.classStudents(widget.classId)).map((s) => s['studentId']).toSet();
    final candidates = all.where((u) => u['role'] == 'SinhVien' && !enrolled.contains(u['id'])).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      showMessage(context, 'Không còn sinh viên nào để thêm.');
      return;
    }

    int studentId = candidates.first['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Thêm sinh viên'),
          content: DropdownButtonFormField<int>(
            initialValue: studentId,
            isExpanded: true,
            items: [
              for (final s in candidates) DropdownMenuItem(value: s['id'] as int, child: Text('${s['fullName']} (${s['username']})')),
            ],
            onChanged: (v) => setDialog(() => studentId = v ?? studentId),
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
        await api.enroll(widget.classId, studentId);
        _reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sinh viên - ${widget.className}')),
      floatingActionButton: FloatingActionButton(onPressed: _enroll, child: const Icon(Icons.person_add)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Lớp chưa có sinh viên.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return ListTile(
                title: Text(s['fullName'].toString()),
                subtitle: Text(s['username'].toString()),
                trailing: IconButton(
                  tooltip: 'Bỏ khỏi lớp',
                  icon: const Icon(Icons.person_remove),
                  onPressed: () async {
                    try {
                      await context.read<ApiService>().unenroll(widget.classId, s['studentId'] as int);
                      _reload();
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
