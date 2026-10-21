import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'my_leaves_screen.dart';
import 'student_class_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classes();
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<ApiService>().classes());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào, ${auth.fullName ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Đơn xin nghỉ',
            icon: const Icon(Icons.assignment),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLeavesScreen())),
          ),
          IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: auth.logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Json>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text(snap.error.toString()));
            final classes = snap.data!;
            if (classes.isEmpty) return const Center(child: Text('Bạn chưa được thêm vào lớp nào.'));
            return ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, i) {
                final c = classes[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text(c['name'].toString()),
                  subtitle: Text('${c['subject']} • GV: ${c['teacher']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudentClassScreen(classId: c['id'] as int, className: c['name'].toString())),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
