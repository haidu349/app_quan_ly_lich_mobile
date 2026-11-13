import 'package:flutter/material.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/utils/palette.dart';

// Hộp thoại thêm/sửa nhãn. Trả về EventLabel khi bấm Lưu.
class LabelDialog extends StatefulWidget {
  final EventLabel? label;

  const LabelDialog({super.key, this.label});

  @override
  State<LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<LabelDialog> {
  late final TextEditingController _nameController;
  late Color _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.label?.name ?? '');
    _color = widget.label?.colorValue ?? labelPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên nhãn');
      return;
    }
    Navigator.pop(
      context,
      EventLabel(id: widget.label?.id, name: name, color: _color.toARGB32()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label == null ? 'Thêm nhãn' : 'Sửa nhãn'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tên nhãn',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Màu'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in labelPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: c,
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
