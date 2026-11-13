import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/add_event_screen.dart';

// event = null: thêm mới, có giá trị: sửa.
// Để riêng ra vì tab Sổ cái và tab Lịch (bước sau) đều dùng.
Future<void> openEventForm(BuildContext context, {Event? event}) async {
  final data = context.read<AppData>();
  final result = await Navigator.push<Event>(
    context,
    MaterialPageRoute(builder: (_) => AddEventScreen(event: event)),
  );
  if (result == null) return;

  if (event == null) {
    await data.addEvent(result);
  } else {
    await data.updateEvent(result);
  }
}
