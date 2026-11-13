import 'package:flutter/material.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/utils/format.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final EventLabel? label;
  final bool hasConflict;
  final bool isPast; // đã kết thúc: bôi xám
  final bool isOngoing; // đang diễn ra
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.label,
    this.hasConflict = false,
    this.isPast = false,
    this.isOngoing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Sự kiện đã qua: mọi màu chuyển sang xám
    final color = isPast ? Colors.grey : (label?.colorValue ?? Colors.grey);
    final labelName = label?.name ?? 'Không nhãn';
    final titleColor = isPast ? Colors.grey[700] : null;

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: isPast ? 0 : null,
      color: isPast ? scheme.surfaceContainerHighest : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Chip nhãn
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: color),
                        const SizedBox(width: 6),
                        Text(
                          labelName,
                          style: textTheme.labelMedium?.copyWith(
                            color: isPast ? Colors.grey[700] : color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPast)
                    _Badge(
                      icon: Icons.history,
                      text: 'Đã qua',
                      color: Colors.grey.shade700,
                    ),
                  if (isOngoing)
                    const _Badge(
                      icon: Icons.play_circle_outline,
                      text: 'Đang diễn ra',
                      color: Color(0xFF2E7D32),
                    ),
                  // Lịch đã qua thì không cần cảnh báo trùng nữa
                  if (hasConflict && !isPast)
                    const _Badge(
                      icon: Icons.warning_amber_rounded,
                      text: 'Trùng lịch',
                      color: Color(0xFFE65100),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.schedule,
                text:
                    '${formatDate(event.start)}  •  ${formatTimeRange(event.start, event.end)}',
                muted: isPast,
              ),
              if (event.location.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  text: event.location,
                  muted: isPast,
                ),
              if (event.organizer.isNotEmpty)
                _InfoRow(
                  icon: Icons.person_outline,
                  text: event.organizer,
                  muted: isPast,
                ),
            ],
          ),
        ),
      ),
    );

    // Làm mờ thêm để thẻ đã qua lùi hẳn về phía sau
    return isPast ? Opacity(opacity: 0.65, child: card) : card;
  }
}

// Nhãn nhỏ có biểu tượng (Đã qua, Đang diễn ra, Trùng lịch)
class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Badge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _InfoRow({required this.icon, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted ? Colors.grey[600] : Colors.grey[700];
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: muted ? Colors.grey[700] : null),
            ),
          ),
        ],
      ),
    );
  }
}
