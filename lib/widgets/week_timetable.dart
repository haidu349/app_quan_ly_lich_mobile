import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/timetable_layout.dart';
import 'package:quan_ly_lich/utils/format.dart';

typedef EventChangedCallback = Future<void> Function(
  Event event,
  DateTime newStart,
  DateTime newEnd,
);

const Color _orange = Color(0xFFE65100);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Bảng giờ của một tuần: 7 cột (Th 2 đến CN), các hàng là giờ trong ngày.
// - Chạm vào khối: mở sửa
// - Giữ rồi kéo: dời sang giờ hoặc ngày khác
// - Kéo thanh nhỏ ở đáy khối: đổi giờ kết thúc
class WeekTimetable extends StatefulWidget {
  final DateTime weekStart; // Thứ Hai đầu tuần
  final List<Event> events;
  final Color Function(Event event) colorOf;
  final bool Function(Event event) hasConflict;
  final bool Function(Event event) isPast;
  final DateTime selectedDay;
  final ValueChanged<Event> onEventTap;
  final EventChangedCallback onEventChanged;
  final ValueChanged<DateTime> onDaySelected;

  const WeekTimetable({
    super.key,
    required this.weekStart,
    required this.events,
    required this.colorOf,
    required this.hasConflict,
    required this.isPast,
    required this.selectedDay,
    required this.onEventTap,
    required this.onEventChanged,
    required this.onDaySelected,
  });

  @override
  State<WeekTimetable> createState() => _WeekTimetableState();
}

class _WeekTimetableState extends State<WeekTimetable> {
  static const double _hourHeight = 56; // chiều cao một giờ
  static const double _gutter = 38; // cột ghi giờ bên trái
  static const double _minBlockHeight = 22;
  static const int _maxMinute = 24 * 60 - 1; // 23:59

  final ScrollController _scroll = ScrollController(
    initialScrollOffset: 6.5 * _hourHeight,
  );
  final GlobalKey _viewportKey = GlobalKey();

  // ---- Trạng thái đang dời ----
  Event? _dragEvent;
  double _dragLeft0 = 0;
  double _dragTop0 = 0;
  double _dragW = 0;
  double _dragH = 0;
  Offset _dragDelta = Offset.zero;
  double _dragScroll0 = 0;
  double _autoVelocity = 0;
  Timer? _autoTimer;

  // ---- Trạng thái đang giãn giờ kết thúc ----
  Event? _resizeEvent;
  double _resizeDy = 0;

  @override
  void didUpdateWidget(covariant WeekTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) _cancelAll();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- Tiện ích ----------

  double _topFor(int minuteOfDay) => minuteOfDay / 60 * _hourHeight;

  int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

  // Số phút tính từ 0:00 của ngày bắt đầu đến giờ kết thúc
  int _endMinute(Event e) => e.end
      .difference(DateTime(e.start.year, e.start.month, e.start.day))
      .inMinutes;

  double get _scrollOffset => _scroll.hasClients ? _scroll.offset : 0;

  void _stopAuto() {
    _autoVelocity = 0;
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  void _cancelAll() {
    _stopAuto();
    _dragEvent = null;
    _resizeEvent = null;
    _resizeDy = 0;
  }

  // ---------- Dời ----------

  void _startDrag(Event e, double left, double top, double w, double h) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragEvent = e;
      _dragLeft0 = left;
      _dragTop0 = top;
      _dragW = w;
      _dragH = h;
      _dragDelta = Offset.zero;
      _dragScroll0 = _scrollOffset;
    });
  }

  void _updateDrag(LongPressMoveUpdateDetails d) {
    if (_dragEvent == null) return;
    _dragDelta = d.offsetFromOrigin;

    // Kéo sát mép trên/dưới thì bảng tự cuộn
    var v = 0.0;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      const edge = 56.0;
      final y = d.globalPosition.dy;
      if (y < top + edge) {
        v = -math.min(14.0, (top + edge - y) / edge * 14);
      } else if (y > bottom - edge) {
        v = math.min(14.0, (y - (bottom - edge)) / edge * 14);
      }
    }
    _autoVelocity = v;
    if (v != 0 && _autoTimer == null) {
      _autoTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (_autoVelocity == 0 || !_scroll.hasClients) return;
        final target = (_scroll.offset + _autoVelocity)
            .clamp(0.0, _scroll.position.maxScrollExtent)
            .toDouble();
        _scroll.jumpTo(target);
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  // Ô đích (ngày, phút bắt đầu) ứng với vị trí đang kéo, đã làm tròn 15 phút
  ({int day, int minute}) _target(double colW) {
    final e = _dragEvent!;
    final top = _dragTop0 + _dragDelta.dy + (_scrollOffset - _dragScroll0);
    final left = _dragLeft0 + _dragDelta.dx;
    final center = left + _dragW / 2;
    final day = ((center - _gutter) / colW).floor().clamp(0, 6).toInt();
    final dur = e.end.difference(e.start).inMinutes;
    final minute = snapMinute(top / _hourHeight * 60)
        .clamp(0, math.max(0, _maxMinute - dur))
        .toInt();
    return (day: day, minute: minute);
  }

  void _endDrag(double colW, List<DateTime> days) {
    final e = _dragEvent;
    if (e == null) return;
    final t = _target(colW);
    final day = days[t.day];
    final newStart = DateTime(day.year, day.month, day.day, 0, t.minute);
    final newEnd = newStart.add(e.end.difference(e.start));
    _stopAuto();
    setState(() => _dragEvent = null);
    if (newStart != e.start) widget.onEventChanged(e, newStart, newEnd);
  }

  void _cancelDrag() {
    _stopAuto();
    if (_dragEvent != null) setState(() => _dragEvent = null);
  }

  // ---------- Giãn giờ kết thúc ----------

  void _startResize(Event e) {
    setState(() {
      _resizeEvent = e;
      _resizeDy = 0;
    });
  }

  void _updateResize(DragUpdateDetails d) {
    setState(() => _resizeDy += d.delta.dy);
  }

  int _resizedEndMinute(Event e) {
    final start = _minuteOfDay(e.start);
    final raw = _endMinute(e) + _resizeDy / _hourHeight * 60;
    return snapMinute(raw).clamp(start + 15, _maxMinute).toInt();
  }

  void _endResize() {
    final e = _resizeEvent;
    if (e == null) return;
    final endMin = _resizedEndMinute(e);
    final changed = endMin != _endMinute(e);
    setState(() {
      _resizeEvent = null;
      _resizeDy = 0;
    });
    if (changed) {
      final newEnd = DateTime(
        e.start.year,
        e.start.month,
        e.start.day,
        0,
        endMin,
      );
      widget.onEventChanged(e, e.start, newEnd);
    }
  }

  void _cancelResize() {
    if (_resizeEvent != null) {
      setState(() {
        _resizeEvent = null;
        _resizeDy = 0;
      });
    }
  }

  // ---------- Giao diện ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _dateOnly(DateTime.now());
    final ws = _dateOnly(widget.weekStart);
    final days = [
      for (var i = 0; i < 7; i++) DateTime(ws.year, ws.month, ws.day + i),
    ];
    final lineColor = Colors.grey.withValues(alpha: 0.25);

    return Column(
      children: [
        _buildHeader(days, today, scheme),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(
            key: _viewportKey,
            child: LayoutBuilder(
              builder: (context, c) {
                final colW = (c.maxWidth - _gutter) / 7;
                final todayIdx = days.indexOf(today);
                final nowMin = _minuteOfDay(DateTime.now());

                return SingleChildScrollView(
                  controller: _scroll,
                  // Đang dời hoặc giãn thì khóa cuộn bằng tay
                  physics: (_dragEvent != null || _resizeEvent != null)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  child: SizedBox(
                    width: c.maxWidth,
                    height: 24 * _hourHeight,
                    child: Stack(
                      children: [
                        // Đường kẻ giờ và nhãn giờ
                        for (var h = 0; h <= 24; h++) ...[
                          Positioned(
                            top: h * _hourHeight,
                            left: _gutter,
                            right: 0,
                            height: 1,
                            child: ColoredBox(color: lineColor),
                          ),
                          if (h > 0 && h < 24)
                            Positioned(
                              top: h * _hourHeight - 7,
                              left: 0,
                              width: _gutter - 4,
                              height: 14,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                        ],
                        // Đường kẻ giữa các cột
                        for (var i = 0; i <= 7; i++)
                          Positioned(
                            left: _gutter + i * colW,
                            top: 0,
                            bottom: 0,
                            width: 1,
                            child: ColoredBox(color: lineColor),
                          ),
                        // Tô nhẹ cột hôm nay
                        if (todayIdx >= 0)
                          Positioned(
                            left: _gutter + todayIdx * colW,
                            width: colW,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: scheme.primary.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                        // Các khối lịch
                        ..._buildBlocks(days, colW),
                        // Đường "bây giờ"
                        if (todayIdx >= 0) ...[
                          Positioned(
                            left: _gutter,
                            right: 0,
                            top: _topFor(nowMin) - 1,
                            height: 2,
                            child: const IgnorePointer(
                              child: ColoredBox(color: Colors.red),
                            ),
                          ),
                          Positioned(
                            left: _gutter - 4,
                            top: _topFor(nowMin) - 4,
                            width: 8,
                            height: 8,
                            child: const IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Khối đang kéo + ô đích
                        if (_dragEvent != null)
                          ..._buildDragOverlay(days, colW, scheme),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<DateTime> days, DateTime today, ColorScheme scheme) {
    final selected = _dateOnly(widget.selectedDay);
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: _gutter),
          for (final day in days)
            Expanded(
              child: InkWell(
                onTap: () => widget.onDaySelected(day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatWeekday(day),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: day.weekday >= 6 ? Colors.red : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day == today ? scheme.primary : null,
                        border: (day == selected && day != today)
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: day == today ? scheme.onPrimary : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildBlocks(List<DateTime> days, double colW) {
    final widgets = <Widget>[];
    for (var di = 0; di < 7; di++) {
      final dayEvents = widget.events
          .where((e) => _dateOnly(e.start) == days[di])
          .toList();
      for (final p in layoutDay(dayEvents)) {
        final e = p.event;
        final startMin = _minuteOfDay(e.start);
        final durMin = e.end.difference(e.start).inMinutes;
        final subW = colW / p.columns;
        final left = _gutter + di * colW + p.column * subW + 1;
        final width = math.max(8.0, subW - 2);
        final top = _topFor(startMin);
        var height = math.max(_minBlockHeight, durMin / 60 * _hourHeight - 1);

        // Đang giãn: hiện chiều cao theo giờ kết thúc mới
        if (_resizeEvent != null && _resizeEvent!.id == e.id) {
          final endMin = _resizedEndMinute(e);
          height = math.max(
            _minBlockHeight,
            (endMin - startMin) / 60 * _hourHeight - 1,
          );
        }
        final faded = _dragEvent != null && _dragEvent!.id == e.id;
        final handleH = (height / 2.5).clamp(10.0, 16.0).toDouble();

        widgets.add(
          Positioned(
            key: ValueKey('ev_${e.id}'),
            left: left,
            top: top,
            width: width,
            height: height,
            child: Opacity(
              opacity: faded ? 0.3 : 1,
              child: GestureDetector(
                onTap: () => widget.onEventTap(e),
                onLongPressStart: (_) =>
                    _startDrag(e, left, top, width, height),
                onLongPressMoveUpdate: _updateDrag,
                onLongPressEnd: (_) => _endDrag(colW, days),
                onLongPressCancel: _cancelDrag,
                child: Stack(
                  children: [
                    Positioned.fill(child: _blockBody(e, height)),
                    // Thanh nhỏ ở đáy để đổi giờ kết thúc
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: handleH,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (_) => _startResize(e),
                        onVerticalDragUpdate: _updateResize,
                        onVerticalDragEnd: (_) => _endResize(),
                        onVerticalDragCancel: _cancelResize,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Container(
                              width: 16,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // Nội dung một khối lịch. [start]/[end] dùng để hiện giờ mới khi đang kéo.
  Widget _blockBody(
    Event e,
    double height, {
    bool dragging = false,
    DateTime? start,
    DateTime? end,
  }) {
    final past = widget.isPast(e);
    final base = past ? Colors.grey : widget.colorOf(e);
    final fg = base.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    final lines = math.max(1, ((height - 6) / 12).floor());
    final showTime = height >= 40;
    final conflict = widget.hasConflict(e) && !past;

    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: dragging ? 0.95 : (past ? 0.75 : 0.88)),
        borderRadius: BorderRadius.circular(5),
        border: conflict ? Border.all(color: _orange, width: 2) : null,
        boxShadow: dragging
            ? const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: e.name),
            if (showTime)
              TextSpan(
                text: '\n${formatTimeRange(start ?? e.start, end ?? e.end)}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          height: 1.15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildDragOverlay(
    List<DateTime> days,
    double colW,
    ColorScheme scheme,
  ) {
    final e = _dragEvent!;
    final t = _target(colW);
    final day = days[t.day];
    final newStart = DateTime(day.year, day.month, day.day, 0, t.minute);
    final newEnd = newStart.add(e.end.difference(e.start));
    final top = _dragTop0 + _dragDelta.dy + (_scrollOffset - _dragScroll0);

    return [
      // Ô đích đã làm tròn: nơi khối sẽ nằm khi thả tay
      Positioned(
        left: _gutter + t.day * colW + 1,
        top: _topFor(t.minute),
        width: colW - 2,
        height: _dragH,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              border: Border.all(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ),
      // Khối đang theo ngón tay
      Positioned(
        left: _dragLeft0 + _dragDelta.dx,
        top: top,
        width: _dragW,
        height: _dragH,
        child: IgnorePointer(
          child: _blockBody(
            e,
            _dragH,
            dragging: true,
            start: newStart,
            end: newEnd,
          ),
        ),
      ),
    ];
  }
}
