import 'package:flutter/material.dart';

import '../services/api_service.dart';

// Bảng trượt tạo/sửa lớp. Trả về dữ liệu gửi lên API, hoặc null nếu huỷ.
// teachers = null khi giảng viên tự tạo/sửa lớp: không hiện ô chọn giảng viên.
Future<Json?> showClassForm(
  BuildContext context, {
  Json? cls,
  required List<Json> subjects,
  List<Json>? teachers,
}) {
  return showModalBottomSheet<Json>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ClassForm(cls: cls, subjects: subjects, teachers: teachers),
  );
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({this.cls, required this.subjects, this.teachers});

  final Json? cls;
  final List<Json> subjects;
  final List<Json>? teachers;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.cls?['name']?.toString() ?? '');
  late final _room = TextEditingController(text: widget.cls?['room']?.toString() ?? '');
  late final _schedule = TextEditingController(text: widget.cls?['schedule']?.toString() ?? '');
  late final _planned = TextEditingController(text: (widget.cls?['plannedSessions'] ?? 15).toString());
  late int _subjectId = _pick(widget.subjects, widget.cls?['subjectId']);
  late int _teacherId = widget.teachers == null ? 0 : _pick(widget.teachers!, widget.cls?['teacherId']);

  // Giữ lựa chọn hiện tại nếu còn trong danh sách, nếu không chọn mục đầu tiên.
  static int _pick(List<Json> items, Object? current) =>
      items.any((i) => i['id'] == current) ? current as int : items.first['id'] as int;

  @override
  void dispose() {
    for (final c in [_name, _room, _schedule, _planned]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'subjectId': _subjectId,
      'teacherId': _teacherId,
      'room': _room.text.trim(),
      'schedule': _schedule.text.trim(),
      'plannedSessions': int.parse(_planned.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cls != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Sửa thông tin lớp' : 'Tạo lớp học', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tên lớp', hintText: 'Ví dụ: Lập trình di động - 23DTHC4'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên lớp' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Môn học'),
                items: [
                  for (final s in widget.subjects)
                    DropdownMenuItem(value: s['id'] as int, child: Text('${s['code']} - ${s['name']}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _subjectId = v ?? _subjectId),
              ),
              if (widget.teachers != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _teacherId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Giảng viên phụ trách'),
                  items: [
                    for (final t in widget.teachers!)
                      DropdownMenuItem(value: t['id'] as int, child: Text(t['fullName'].toString(), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _teacherId = v ?? _teacherId),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(
                  labelText: 'Phòng học',
                  hintText: 'Ví dụ: Phòng A.301',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schedule,
                decoration: const InputDecoration(
                  labelText: 'Lịch học',
                  hintText: 'Ví dụ: Thứ 2, tiết 1-4 (7:00 - 10:30)',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _planned,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số buổi dự kiến',
                  helperText: 'Dùng để tính số buổi sinh viên còn được nghỉ (tối đa 20%)',
                  prefixIcon: Icon(Icons.event_repeat_outlined),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  return (n == null || n < 1 || n > 100) ? 'Nhập số từ 1 đến 100' : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo lớp')),
            ],
          ),
        ),
      ),
    );
  }
}
