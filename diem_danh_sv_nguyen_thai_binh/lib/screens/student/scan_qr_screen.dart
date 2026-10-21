import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Quét mã QR của buổi học, trả về nội dung mã (QR token) cho màn hình trước.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã QR điểm danh')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done || capture.barcodes.isEmpty) return;
          final code = capture.barcodes.first.rawValue;
          if (code == null || code.isEmpty) return;
          _done = true;
          Navigator.pop(context, code);
        },
      ),
    );
  }
}
