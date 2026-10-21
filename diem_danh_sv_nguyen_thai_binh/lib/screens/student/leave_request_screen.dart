import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../../services/api_service.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key, required this.sessionId, required this.sessionTitle});

  final int sessionId;
  final String sessionTitle;

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String? _evidencePath;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _evidencePath = picked.path);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<ApiService>().submitLeave(
            sessionId: widget.sessionId,
            reason: _reason.text.trim(),
            evidencePath: _evidencePath,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Đã gửi đơn xin nghỉ.')));
      navigator.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Xin nghỉ: ${widget.sessionTitle}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _reason,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Lý do', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập lý do' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickEvidence,
                icon: const Icon(Icons.attach_file),
                label: Text(_evidencePath == null ? 'Chọn ảnh minh chứng (không bắt buộc)' : 'Đã chọn ảnh minh chứng'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Đang gửi...' : 'Gửi đơn'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
