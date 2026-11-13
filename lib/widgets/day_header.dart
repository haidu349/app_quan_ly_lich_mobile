import 'package:flutter/material.dart';
import 'package:quan_ly_lich/utils/format.dart';

// Tiêu đề ngày kiểu "Th 2, 02/11/2026" như app của trường
class DayHeader extends StatelessWidget {
  final DateTime day;

  const DayHeader({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isToday
                  ? '${formatDayHeader(day)} • Hôm nay'
                  : formatDayHeader(day),
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 8)),
        ],
      ),
    );
  }
}
