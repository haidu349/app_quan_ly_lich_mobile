import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/add_event_screen.dart';

// event = null: thêm mới, có giá trị: sửa.
// initialDate: ngày chọn sẵn khi thêm mới.
Future<void> openEventForm(
  BuildContext context, {
  Event? event,
  DateTime? initialDate,
}) async {
  final data = context.read<AppData>();
  final result = await Navigator.push<Event>(
    context,
    MaterialPageRoute(
      builder: (_) => AddEventScreen(event: event, initialDate: initialDate),
    ),
  );
  if (result == null) return;

  if (event == null) {
    await data.addEvent(result);
  } else {
    await data.updateEvent(result);
  }
}

// Hộp thoại hỏi lại trước khi xóa. Trả về true nếu người dùng bấm "Xóa".
Future<bool> confirmDeleteEvent(BuildContext context, Event event) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 32),
      title: const Text('Xóa sự kiện?'),
      content: Text(
        'Bạn có chắc muốn xóa "${event.name}"?\nHành động này không thể hoàn tác.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// Xóa sự kiện rồi hiện thông báo ngắn
void deleteEventAndNotify(BuildContext context, Event event) {
  final data = context.read<AppData>();
  final messenger = ScaffoldMessenger.of(context);
  data.deleteEvent(event.id!);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('Đã xóa "${event.name}"')));
}
