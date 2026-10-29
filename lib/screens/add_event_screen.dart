import 'package:flutter/material.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/utils/format.dart';

class AddEventScreen extends StatefulWidget {
  final Event? event; // null = thêm mới, có giá trị = đang sửa

  const AddEventScreen({super.key, this.event});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _organizerController;
  late DateTime _selectedDate;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameController = TextEditingController(text: e?.name ?? '');
    _organizerController = TextEditingController(text: e?.organizer ?? '');
    _selectedDate = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final event = Event(
      id: widget.event?.id, // giữ nguyên id khi sửa
      name: _nameController.text.trim(),
      date: _selectedDate,
      organizer: _organizerController.text.trim(),
    );
    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Sửa sự kiện' : 'Thêm sự kiện')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sự kiện',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên sự kiện'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _organizerController,
                decoration: const InputDecoration(
                  labelText: 'Người tổ chức',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập người tổ chức'
                    : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.calendar_today),
                title: Text('Ngày tổ chức: ${formatDate(_selectedDate)}'),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Cập nhật' : 'Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
