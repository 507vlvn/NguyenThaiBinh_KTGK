import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';

class AbsenceReportScreen extends StatefulWidget {
  const AbsenceReportScreen({super.key, required this.classId});

  final int classId;

  @override
  State<AbsenceReportScreen> createState() => _AbsenceReportScreenState();
}

class _AbsenceReportScreenState extends State<AbsenceReportScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().absenceReport(widget.classId);
  }

  Future<void> _sendWarnings() async {
    try {
      final res = await context.read<ApiService>().sendWarnings(widget.classId);
      if (mounted) showMessage(context, 'Đã gửi cảnh báo cho ${res['sent']} sinh viên.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo vắng'),
        actions: [
          TextButton(onPressed: _sendWarnings, child: const Text('Gửi cảnh báo')),
        ],
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('Lớp chưa có sinh viên.'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final warned = r['isWarned'] == true;
              final rate = ((r['absentRate'] as num) * 100).round();
              return ListTile(
                leading: Icon(warned ? Icons.warning : Icons.check_circle, color: warned ? Colors.red : Colors.green),
                title: Text(r['fullName'].toString()),
                subtitle: Text('Vắng ${r['absentSessions']}/${r['totalSessions']} buổi ($rate%)'),
              );
            },
          );
        },
      ),
    );
  }
}
