import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/widgets/label_dialog.dart';

class LabelScreen extends StatelessWidget {
  const LabelScreen({super.key});

  Future<void> _openEditor(BuildContext context, {EventLabel? label}) async {
    final data = context.read<AppData>();
    final result = await showDialog<EventLabel>(
      context: context,
      builder: (_) => LabelDialog(label: label),
    );
    if (result == null) return;

    if (label == null) {
      await data.addLabel(result);
    } else {
      await data.updateLabel(result);
    }
  }

  Future<void> _delete(BuildContext context, EventLabel label) async {
    final data = context.read<AppData>();
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
    await data.deleteLabel(label.id!);
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<AppData>().labels;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhãn')),
      body: labels.isEmpty
          ? const Center(child: Text('Chưa có nhãn nào'))
          : ListView.builder(
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: label.colorValue,
                  ),
                  title: Text(label.name),
                  onTap: () => _openEditor(context, label: label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xóa nhãn',
                    onPressed: () => _delete(context, label),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
