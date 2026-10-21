import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';

// Giảng viên chỉ xem danh sách sinh viên. Thêm/bớt sinh viên do quản trị viên thực hiện.
class ClassStudentsScreen extends StatelessWidget {
  const ClassStudentsScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sinh viên - $className')),
      body: FutureBuilder<List<Json>>(
        future: context.read<ApiService>().classStudents(classId),
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
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(s['fullName'].toString()),
                subtitle: Text('${s['username']} • ${s['email']}'),
              );
            },
          );
        },
      ),
    );
  }
}
