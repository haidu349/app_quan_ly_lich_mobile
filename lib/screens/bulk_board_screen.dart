import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/bulk_reschedule_service.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/widgets/week_timetable.dart';

typedef BulkOverrides = Map<int, ({DateTime start, DateTime end})>;
typedef BulkBoardResult = ({BulkOverrides overrides, bool apply});

const Color _orange = Color(0xFFE65100);

// Bảng tuần cho đợt dời hàng loạt: mọi buổi sắp dời đều kéo thả được,
// lịch khác đứng yên. Trả về giờ mới của từng buổi (khóa = id buổi gốc).
class BulkBoardScreen extends StatefulWidget {
  final List<BulkMove> plan;

  const BulkBoardScreen({super.key, required this.plan});

  @override
  State<BulkBoardScreen> createState() => _BulkBoardScreenState();
}

class _BulkBoardScreenState extends State<BulkBoardScreen> {
  late final Map<int, Event> _moved; // id buổi gốc -> buổi ở giờ mới
  late DateTime _weekStart;

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _moved = {for (final m in widget.plan) m.original.id!: m.moved};
    final first = _moved.values
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

  // apply = true: người dùng bấm "Dời"; false: quay lại nhưng vẫn giữ giờ đã kéo
  void _close(bool apply) => Navigator.pop<BulkBoardResult>(context, (
    overrides: {
      for (final e in _moved.entries)
        e.key: (start: e.value.start, end: e.value.end),
    },
    apply: apply,
  ));

  String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final fixed = [
      for (final e in data.events)
        if (!_moved.containsKey(e.id)) e,
    ];
    final all = [...fixed, ..._moved.values];

    // Buổi bị trùng: buổi đang dời trùng ai thì cả hai bên cùng báo cam
    final bad = <int?>{};
    for (final m in _moved.values) {
      final c = findConflicts(m, all);
      if (c.isEmpty) continue;
      bad.add(m.id);
      bad.addAll(c.map((e) => e.id));
    }
    final conflictCount = _moved.values.where((m) => bad.contains(m.id)).length;
    final weekEnd = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 6,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(false);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Xem trước lịch dời')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Đây là nơi các buổi sẽ dời tới. Kéo từng buổi sang giờ/ngày khác '
                  'để chỉnh, bấm "Dời" khi ưng. Viền cam là buổi đang trùng lịch.',
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
                    !_moved.containsKey(e.id) && !e.end.isAfter(DateTime.now()),
                selectedDay: _weekStart,
                canEdit: (e) => _moved.containsKey(e.id),
                isHighlighted: (e) => _moved.containsKey(e.id),
                onWeekShift: _shiftWeek,
                onEventChanged: (e, s, en) async {
                  setState(() {
                    _moved[e.id!] = e.copyWith(start: s, end: en);
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
            child: Row(
              children: [
                Expanded(
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
                FilledButton(
                  onPressed: () => _close(true),
                  child: Text('Dời ${_moved.length} buổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
