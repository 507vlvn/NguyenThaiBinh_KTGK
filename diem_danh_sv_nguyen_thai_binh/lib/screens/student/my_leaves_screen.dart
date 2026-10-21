import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';

class MyLeavesScreen extends StatelessWidget {
  const MyLeavesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn xin nghỉ của tôi')),
      body: FutureBuilder<List<Json>>(
        future: context.read<ApiService>().myLeaves(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Bạn chưa gửi đơn nào.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final l = list[i];
              return ListTile(
                title: Text(l['session'].toString()),
                subtitle: Text('${l['reason']}\n${formatDateTime(l['createdAt'].toString())}'),
                isThreeLine: true,
                trailing: Chip(label: Text(leaveStatusLabel(l['status'].toString()))),
              );
            },
          );
        },
      ),
    );
  }
}
