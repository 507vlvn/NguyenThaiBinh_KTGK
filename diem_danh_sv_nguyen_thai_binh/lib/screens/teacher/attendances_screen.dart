import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/protected_image.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';

class AttendancesScreen extends StatefulWidget {
  const AttendancesScreen({super.key, required this.sessionId, required this.title});

  final int sessionId;
  final String title;

  @override
  State<AttendancesScreen> createState() => _AttendancesScreenState();
}

class _AttendancesScreenState extends State<AttendancesScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().attendances(widget.sessionId);
  }

  void _reload() => setState(() => _future = context.read<ApiService>().attendances(widget.sessionId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(tooltip: 'Làm mới', icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Chưa có sinh viên nào điểm danh.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(a['fullName'].toString()),
                subtitle: Text(
                  '${a['username']} • ${formatDateTime(a['checkedInAt'].toString())}\n'
                  'Cách lớp ${(a['distanceMeters'] as num).round()} m',
                ),
                isThreeLine: true,
                trailing: a['hasPhoto'] == true
                    ? IconButton(
                        tooltip: 'Xem ảnh',
                        icon: const Icon(Icons.photo),
                        onPressed: () => showProtectedImage(context, '/api/attendances/${a['id']}/photo'),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
