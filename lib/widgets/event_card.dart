import 'package:flutter/material.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/utils/format.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final EventLabel? label;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = label?.colorValue ?? Colors.grey;
    final labelName = label?.name ?? 'Không nhãn';
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
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
              // Chip nhãn
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.schedule,
                text:
                    '${formatDate(event.start)}  •  ${formatTimeRange(event.start, event.end)}',
              ),
              if (event.location.isNotEmpty)
                _InfoRow(icon: Icons.place_outlined, text: event.location),
              if (event.organizer.isNotEmpty)
                _InfoRow(icon: Icons.person_outline, text: event.organizer),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
