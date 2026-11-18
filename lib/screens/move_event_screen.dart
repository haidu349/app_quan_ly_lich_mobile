import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/services/free_slot_service.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/week_timetable.dart';

// Kết quả khi người dùng chọn xong khung giờ mới
class MoveResult {
  final DateTime start;
  final DateTime end;

  const MoveResult(this.start, this.end);
}

// Mở màn hình bảng tuần để chọn chỗ dời cho một sự kiện.
// - ignoreEventId: sự kiện đang sửa (không tính nó là "lịch khác")
// - ignoreEventIds: nhiều sự kiện cùng bị bỏ qua (dời hàng loạt: các buổi
//   trong đợt sắp đi chỗ khác nên không còn chiếm giờ cũ)
// - extraEvents: lịch chưa lưu nhưng cần tránh (ví dụ các dòng chờ nhập từ Excel)
Future<MoveResult?> showMoveEventScreen(
  BuildContext context, {
  required String title,
  required Color color,
  required DateTime start,
  required DateTime end,
  int? ignoreEventId,
  Set<int> ignoreEventIds = const {},
  List<Event> extraEvents = const [],
}) {
  return Navigator.push<MoveResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MoveEventScreen(
        title: title,
        color: color,
        start: start,
        end: end,
        ignoreEventId: ignoreEventId,
        ignoreEventIds: ignoreEventIds,
        extraEvents: extraEvents,
      ),
    ),
  );
}

class MoveEventScreen extends StatefulWidget {
  final String title;
  final Color color;
  final DateTime start;
  final DateTime end;
  final int? ignoreEventId;
  final Set<int> ignoreEventIds;
  final List<Event> extraEvents;

  const MoveEventScreen({
    super.key,
    required this.title,
    required this.color,
    required this.start,
    required this.end,
    this.ignoreEventId,
    this.ignoreEventIds = const {},
    this.extraEvents = const [],
  });

  @override
  State<MoveEventScreen> createState() => _MoveEventScreenState();
}

class _MoveEventScreenState extends State<MoveEventScreen> {
  static const int _pendingId = -1; // id tạm của khối đang dời
  static const Color _orange = Color(0xFFE65100);

  late DateTime _start;
  late DateTime _end;
  late DateTime _weekStart;
  late final List<Event> _others; // các lịch khác (đều có id khác nhau)

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  int get _duration => _end.difference(_start).inMinutes;

  Event get _pending =>
      Event(id: _pendingId, name: widget.title, start: _start, end: _end);

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end;
    _weekStart = _mondayOf(_start);

    final data = context.read<AppData>();
    var nextId = -2; // lịch chưa lưu cần id riêng để bảng phân biệt được
    _others = [
      for (final e in data.events)
        if (e.id != widget.ignoreEventId &&
            !widget.ignoreEventIds.contains(e.id))
          e,
      for (final e in widget.extraEvents) e.copyWith(id: nextId--),
    ];
  }

  // Đặt khối bắt đầu tại [start], giữ nguyên thời lượng và không tràn qua nửa đêm
  void _place(DateTime start) {
    final dur = _duration;
    var s = start;
    final latest = DateTime(
      s.year,
      s.month,
      s.day,
      23,
      59,
    ).subtract(Duration(minutes: dur));
    if (s.isAfter(latest)) s = latest;
    setState(() {
      _start = s;
      _end = s.add(Duration(minutes: dur));
      _weekStart = _mondayOf(s);
    });
  }

  void _shiftWeek(int dir) {
    setState(() {
      _weekStart = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + 7 * dir,
      );
    });
  }

  String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // Mỗi ngày trống gần nhất lấy một khoảng đầu tiên đủ chỗ
  List<({DateTime day, FreeSlot slot})> _suggestions() {
    final from = DateTime.now();
    final avail = availabilityForRange(
      from,
      from.add(const Duration(days: 21)),
      _others,
      durationMinutes: _duration,
    );
    final out = <({DateTime day, FreeSlot slot})>[];
    for (final a in avail) {
      if (a.slots.isEmpty) continue;
      out.add((day: a.day, slot: a.slots.first));
      if (out.length == 8) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final textTheme = Theme.of(context).textTheme;
    final pending = _pending;
    final conflicts = findConflicts(pending, _others);
    final conflictIds = {for (final e in conflicts) e.id};
    final weekEnd = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 6,
    );
    final suggestions = _suggestions();

    return Scaffold(
      appBar: AppBar(
        title: Text('Dời: ${widget.title}', overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          // Giờ đang chọn + gợi ý nhanh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatDayHeader(_start)}  •  ${formatTimeRange(_start, _end)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chạm vào khối rồi kéo để dời, kéo thanh đáy khối để đổi giờ kết thúc',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ),
          ),
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('Gợi ý:'),
                    ),
                  ),
                  for (final s in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.bolt, size: 16),
                        label: Text(
                          '${formatWeekday(s.day)} ${_dm(s.day)} • ${formatTime(s.slot.start)}',
                        ),
                        onPressed: () => _place(s.slot.start),
                      ),
                    ),
                ],
              ),
            ),

          // Đổi tuần
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
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              events: [..._others, pending],
              colorOf: (e) => e.id == _pendingId
                  ? widget.color
                  : (data.labelOf(e)?.colorValue ?? Colors.grey),
              // Chỉ tô cam khối đang dời và các lịch đang đụng giờ với nó
              hasConflict: (e) => e.id == _pendingId
                  ? conflicts.isNotEmpty
                  : conflictIds.contains(e.id),
              isPast: (e) =>
                  e.id != _pendingId && !e.end.isAfter(DateTime.now()),
              selectedDay: _start,
              canEdit: (e) => e.id == _pendingId,
              isHighlighted: (e) => e.id == _pendingId,
              onEmptyTap: _place,
              instantDrag: true,
              onWeekShift: _shiftWeek,
              onEventChanged: (e, s, en) async {
                setState(() {
                  _start = s;
                  _end = en;
                  _weekStart = _mondayOf(s);
                });
              },
              initialScrollMinute: math
                  .max(0, _start.hour * 60 + _start.minute - 90)
                  .toDouble(),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (conflicts.isEmpty ? Colors.green : _orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      conflicts.isEmpty
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: conflicts.isEmpty ? Colors.green[700] : _orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: conflicts.isEmpty
                          ? Text(
                              'Không trùng lịch',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 96),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Trùng với ${conflicts.length} sự kiện:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _orange,
                                      ),
                                    ),
                                    for (final e in conflicts)
                                      Text(
                                        '• ${e.name}  ${formatDate(e.start)} '
                                        '${formatTimeRange(e.start, e.end)}',
                                        style: const TextStyle(color: _orange),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, MoveResult(_start, _end)),
                      child: const Text('Chọn khung giờ này'),
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
