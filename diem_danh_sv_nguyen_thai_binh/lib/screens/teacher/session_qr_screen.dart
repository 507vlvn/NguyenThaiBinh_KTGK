import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';

// Hiển thị mã QR để sinh viên quét. Đóng điểm danh từ đây sẽ trả về true cho màn hình trước.
class SessionQrScreen extends StatelessWidget {
  const SessionQrScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final qr = session['qrToken'].toString();
    return Scaffold(
      appBar: AppBar(title: Text(session['title'].toString())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(data: qr, size: 260),
            const SizedBox(height: 16),
            const Text('Sinh viên quét mã này để điểm danh.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.lock),
                label: const Text('Đóng điểm danh'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  try {
                    await context.read<ApiService>().closeSession(session['id'] as int);
                    navigator.pop(true);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
