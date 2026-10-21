import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/protected_image.dart';
import '../../core/ui.dart';
import '../../services/api_service.dart';

class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key, required this.classId});

  final int classId;

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classLeaves(widget.classId);
  }

  void _reload() => setState(() => _future = context.read<ApiService>().classLeaves(widget.classId));

  Future<void> _review(Json l, bool approve) async {
    try {
      await context.read<ApiService>().reviewLeave(l['id'] as int, approve: approve);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn xin nghỉ')),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Chưa có đơn xin nghỉ nào.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final l = list[i];
              final pending = l['status'] == 'Pending';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l['student']} • ${l['session']}', style: Theme.of(context).textTheme.titleSmall),
                      Text(l['reason'].toString()),
                      const SizedBox(height: 4),
                      Text(leaveStatusLabel(l['status'].toString())),
                      Row(
                        children: [
                          if (l['hasEvidence'] == true)
                            TextButton.icon(
                              onPressed: () => showProtectedImage(context, '/api/leave-requests/${l['id']}/evidence'),
                              icon: const Icon(Icons.photo),
                              label: const Text('Minh chứng'),
                            ),
                          const Spacer(),
                          if (pending) ...[
                            TextButton(onPressed: () => _review(l, false), child: const Text('Từ chối')),
                            FilledButton(onPressed: () => _review(l, true), child: const Text('Duyệt')),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
