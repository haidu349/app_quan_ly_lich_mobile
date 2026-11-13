import 'package:flutter/material.dart';
import 'package:quan_ly_lich/database/database_helper.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/widgets/label_dialog.dart';

class LabelScreen extends StatefulWidget {
  const LabelScreen({super.key});

  @override
  State<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  List<EventLabel> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final labels = await DatabaseHelper.instance.getAllLabels();
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _loading = false;
    });
  }

  Future<void> _openEditor({EventLabel? label}) async {
    final result = await showDialog<EventLabel>(
      context: context,
      builder: (_) => LabelDialog(label: label),
    );
    if (result == null) return;

    if (label == null) {
      await DatabaseHelper.instance.insertLabel(result);
    } else {
      await DatabaseHelper.instance.updateLabel(result);
    }
    await _load();
  }

  Future<void> _delete(EventLabel label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhãn?'),
        content: Text(
          'Xóa nhãn "${label.name}"? Các sự kiện đang dùng nhãn này sẽ chuyển thành "Không nhãn".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteLabel(label.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhãn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _labels.isEmpty
          ? const Center(child: Text('Chưa có nhãn nào'))
          : ListView.builder(
              itemCount: _labels.length,
              itemBuilder: (context, index) {
                final label = _labels[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: label.colorValue,
                  ),
                  title: Text(label.name),
                  onTap: () => _openEditor(label: label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xóa nhãn',
                    onPressed: () => _delete(label),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
