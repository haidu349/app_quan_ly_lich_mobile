import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/widgets/week_timetable.dart';

const Color _orange = Color(0xFFE65100);

// Bảng tuần xem trước lịch sắp nhập: các buổi tạm (id âm) kéo thả được, lịch thật đứng yên.
// Trả về giờ mới của từng buổi tạm (khóa = id âm) nếu bấm "Đồng ý nhập", null nếu hủy.
class ImportBoardScreen extends StatefulWidget {
  final List<Event> temps;

  const ImportBoardScreen({super.key, required this.temps});

  @override
  State<ImportBoardScreen> createState() => _ImportBoardScreenState();
}

class _ImportBoardScreenState extends State<ImportBoardScreen> {
  late final Map<int, Event> _temps;
  late DateTime _weekStart;

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _temps = {for (final e in widget.temps) e.id!: e};
    final first = _temps.values
        .map((e) => e.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    _weekStart = _mondayOf(first);
  }

  void _shiftWeek(int dir) => setState(() {
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 7 * dir,
    );
  });

  String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final all = [...data.events, ..._temps.values];

    final bad = <int?>{};
    for (final m in _temps.values) {
      final c = findConflicts(m, all);
      if (c.isEmpty) continue;
      bad.add(m.id);
      bad.addAll(c.map((e) => e.id));
    }
    final conflictCount = _temps.values.where((m) => bad.contains(m.id)).length;
    final weekEnd = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 6,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch tạm thời')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Các buổi sắp nhập hiện ở đây. Kéo sang giờ/ngày khác để chỉnh, '
                'bấm "Đồng ý nhập" để lưu, hoặc "Hủy" để bỏ hết lịch tạm. '
                'Viền cam là buổi đang trùng lịch.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Tuần trước',
                onPressed: () => _shiftWeek(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tuần ${_dm(_weekStart)} - ${_dm(weekEnd)}/${weekEnd.year}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Tuần sau',
                onPressed: () => _shiftWeek(1),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: WeekTimetable(
              weekStart: _weekStart,
              events: all,
              instantDrag: true,
              colorOf: (e) => data.labelOf(e)?.colorValue ?? Colors.grey,
              hasConflict: (e) => bad.contains(e.id),
              isPast: (e) =>
                  !_temps.containsKey(e.id) && !e.end.isAfter(DateTime.now()),
              selectedDay: _weekStart,
              canEdit: (e) => _temps.containsKey(e.id),
              isHighlighted: (e) => _temps.containsKey(e.id),
              onWeekShift: _shiftWeek,
              onEventChanged: (e, s, en) async {
                setState(() {
                  _temps[e.id!] = e.copyWith(start: s, end: en);
                  _weekStart = _mondayOf(s);
                });
              },
              initialScrollMinute: 6.5 * 60,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  conflictCount == 0
                      ? 'Không buổi nào trùng lịch'
                      : '$conflictCount buổi đang trùng lịch',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: conflictCount == 0 ? Colors.green[800] : _orange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {
                        for (final e in _temps.entries) e.key: e.value,
                      }),
                      child: Text('Đồng ý nhập ${_temps.length}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
