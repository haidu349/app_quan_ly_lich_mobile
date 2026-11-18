import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/widgets/event_card.dart';

class EventTile extends StatelessWidget {
  final Event event;
  // Chế độ chọn nhiều: không vuốt xóa, chạm để chọn/bỏ chọn
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;

  const EventTile({
    super.key,
    required this.event,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    final card = EventCard(
      event: event,
      label: data.labelOf(event),
      hasConflict: data.hasConflict(event),
      isPast: data.isPast(event),
      isOngoing: data.isOngoing(event),
      onTap: selecting ? onToggle : () => openEventForm(context, event: event),
    );

    if (selecting) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onToggle?.call()),
            Expanded(child: card),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Dismissible(
        key: ValueKey(event.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        // Hỏi xác nhận trước: trả về false thì thẻ trượt về chỗ cũ
        confirmDismiss: (_) => confirmDeleteEvent(context, event),
        onDismissed: (_) => deleteEventAndNotify(context, event),
        child: card,
      ),
    );
  }
}
