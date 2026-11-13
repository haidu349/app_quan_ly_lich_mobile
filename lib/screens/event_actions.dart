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

// Xóa sự kiện và hiện thanh "Hoàn tác"
void deleteEventWithUndo(BuildContext context, Event event) {
  final data = context.read<AppData>();
  data.deleteEvent(event.id!);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text('Đã xóa "${event.name}"'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () => data.addEvent(event),
        ),
      ),
    );
}
