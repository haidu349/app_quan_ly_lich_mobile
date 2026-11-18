import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

// Một khối lịch đã vẽ và vùng nó chiếm (tọa độ trong nội dung cuộn)
class _Hit {
  final Event event;
  final Rect rect;

  const _Hit(this.event, this.rect);
}

// Nhận cử chỉ kéo ngay khi ngón tay trượt quá ngưỡng, chỉ khi [allow] cho phép
class _InstantDragRecognizer extends ImmediateMultiDragGestureRecognizer {
  final bool Function(Offset global) allow;

  _InstantDragRecognizer(this.allow);

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      allow(event.position) && super.isPointerAllowed(event);

  // Ngưỡng bằng nửa ngưỡng cuộn: thắng cuộn dọc của bảng nên kéo dọc cũng nhấc được khối
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _HalfSlopState(event.position, event.kind, gestureSettings);
}

class _HalfSlopState extends MultiDragPointerState {
  _HalfSlopState(
    super.initialPosition,
    super.kind,
    super.deviceGestureSettings,
  );

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings) / 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

class _InstantDrag extends Drag {
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  _InstantDrag({
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  void update(DragUpdateDetails details) => onUpdate(details.globalPosition);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onCancel();
}

// Bảng giờ của một tuần: 7 cột (Th 2 đến CN), các hàng là giờ trong ngày.
// - Chạm vào khối: mở sửa
// - Giữ rồi kéo: dời sang giờ/ngày khác; dí sát mép trái/phải để sang tuần khác
// - Kéo thanh nhỏ ở đáy khối: đổi giờ kết thúc
class WeekTimetable extends StatefulWidget {
  final DateTime weekStart; // Thứ Hai đầu tuần
  final List<Event> events;
  final Color Function(Event event) colorOf;
  final bool Function(Event event) hasConflict;
  final bool Function(Event event) isPast;
  final DateTime selectedDay;
  final EventChangedCallback onEventChanged;
  final ValueChanged<Event>? onEventTap;
  final ValueChanged<DateTime>? onDaySelected;

  // Gọi với -1 hoặc +1 khi người dùng giữ khối sát mép để sang tuần khác
  final ValueChanged<int>? onWeekShift;

  // Khối nào được phép dời/giãn (null = tất cả)
  final bool Function(Event event)? canEdit;

  // Khối nào được vẽ viền đậm để nổi bật
  final bool Function(Event event)? isHighlighted;

  // Chạm vào ô trống: nhận thời điểm đã làm tròn 15 phút
  final ValueChanged<DateTime>? onEmptyTap;

  // Giờ (tính bằng phút) cuộn tới khi mở bảng
  final double initialScrollMinute;

  // true: chạm vào khối rồi kéo là dời ngay (không cần giữ). Mặc định phải giữ rồi mới kéo.
  final bool instantDrag;

  const WeekTimetable({
    super.key,
    required this.weekStart,
    required this.events,
    required this.colorOf,
    required this.hasConflict,
    required this.isPast,
    required this.selectedDay,
    required this.onEventChanged,
    this.onEventTap,
    this.onDaySelected,
    this.onWeekShift,
    this.canEdit,
    this.isHighlighted,
    this.onEmptyTap,
    this.initialScrollMinute = 6.5 * 60,
    this.instantDrag = false,
  });

  @override
  State<WeekTimetable> createState() => _WeekTimetableState();
}

class _WeekTimetableState extends State<WeekTimetable>
    with SingleTickerProviderStateMixin {
  static const double _hourHeight = 56; // chiều cao một giờ
  static const double _gutter = 38; // cột ghi giờ bên trái
  static const double _minBlockHeight = 22;
  static const int _maxMinute = 24 * 60 - 1; // 23:59
  static const double _edgeZone = 16; // vùng mép trái/phải để lật tuần

  late final ScrollController _scroll;
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  List<DateTime> _oldDays = const []; // tuần cũ đang trượt ra
  int _slideDir = 1; // 1: sang tuần sau, -1: về tuần trước
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _gestureKey = GlobalKey();

  // Số đo của lần vẽ gần nhất (dùng khi xử lý cử chỉ)
  double _colW = 1;
  List<DateTime> _days = const [];
  List<_Hit> _hits = [];

  // ---- Đang dời ----
  Event? _dragEvent;
  Offset _grab = Offset.zero; // chỗ ngón tay nắm trong khối
  Size _dragSize = Size.zero;
  Offset _finger = Offset.zero; // vị trí ngón tay (tọa độ nội dung)
  Offset _fingerStart = Offset.zero;
  double _scrollAtFinger = 0;
  bool _armed = false; // đã kéo đủ xa mới bật cuộn/lật tuần tự động
  double _autoVelocity = 0;
  Timer? _autoTimer;
  int _edgeDir = 0;
  Timer? _edgeTimer;

  // ---- Đang giãn giờ kết thúc ----
  Event? _resizeEvent;
  double _resizeDy = 0;

  // Lúc kéo chỉ lớp phủ cần vẽ lại, không dựng lại cả lưới 7 ngày.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(
      initialScrollOffset: math.max(
        0.0,
        widget.initialScrollMinute / 60 * _hourHeight,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WeekTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đổi tuần bình thường thì bỏ thao tác dở; đang kéo thì giữ nguyên
    // (kéo sát mép để sang tuần khác chính là lúc tuần đổi).
    if (oldWidget.weekStart != widget.weekStart) {
      if (_dragEvent == null) _cancelResize();
      final old = _dateOnly(oldWidget.weekStart);
      _oldDays = [
        for (var i = 0; i < 7; i++) DateTime(old.year, old.month, old.day + i),
      ];
      _slideDir = widget.weekStart.isAfter(oldWidget.weekStart) ? 1 : -1;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _edgeTimer?.cancel();
    _slide.dispose();
    _scroll.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ---------- Tiện ích ----------

  bool _canEdit(Event e) => widget.canEdit?.call(e) ?? true;

  double _topFor(int minuteOfDay) => minuteOfDay / 60 * _hourHeight;

  int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

  // Số phút tính từ 0:00 của ngày bắt đầu đến giờ kết thúc
  int _endMinute(Event e) => e.end
      .difference(DateTime(e.start.year, e.start.month, e.start.day))
      .inMinutes;

  double get _scrollOffset => _scroll.hasClients ? _scroll.offset : 0;

  _Hit? _hitAt(Offset p) {
    for (final h in _hits.reversed) {
      if (h.rect.contains(p)) return h;
    }
    return null;
  }

  // ---------- Chạm ----------

  void _onTapUp(TapUpDetails d) {
    final p = d.localPosition;
    final hit = _hitAt(p);
    if (hit != null) {
      if (_canEdit(hit.event)) widget.onEventTap?.call(hit.event);
      return;
    }
    final onEmpty = widget.onEmptyTap;
    if (onEmpty == null || p.dx < _gutter || _days.isEmpty) return;
    final day = ((p.dx - _gutter) / _colW).floor().clamp(0, 6).toInt();
    final minute = snapMinute(p.dy / _hourHeight * 60)
        .clamp(0, 23 * 60 + 45)
        .toInt();
    final d0 = _days[day];
    onEmpty(DateTime(d0.year, d0.month, d0.day, 0, minute));
  }

  // ---------- Dời ----------

  void _onLongPressStart(LongPressStartDetails d) =>
      _startDrag(d.localPosition);

  void _startDrag(Offset local) {
    final hit = _hitAt(local);
    if (hit == null || !_canEdit(hit.event)) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dragEvent = hit.event;
      _grab = local - hit.rect.topLeft;
      _dragSize = hit.rect.size;
      _finger = local;
      _fingerStart = local;
      _scrollAtFinger = _scrollOffset;
      _armed = false;
    });
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) =>
      _moveDrag(d.localPosition, d.globalPosition);

  void _moveDrag(Offset local, Offset global) {
    if (_dragEvent == null) return;
    _finger = local;
    _scrollAtFinger = _scrollOffset;
    if (!_armed && (_finger - _fingerStart).distance > 24) _armed = true;
    _updateAutoScrollAndEdges(global);
    _frame.value++;
  }

  void _onLongPressEnd(LongPressEndDetails d) => _endDrag();

  // ---- Kéo ngay khi chạm (instantDrag), không cần giữ ----

  Offset _toLocal(Offset global) {
    final box = _gestureKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  // Chỉ nhận cử chỉ khi chạm trúng khối được phép dời, trừ thanh giãn giờ ở đáy khối
  bool _allowInstant(Offset global) {
    final local = _toLocal(global);
    final hit = _hitAt(local);
    if (hit == null || !_canEdit(hit.event)) return false;
    final handleH = (hit.rect.height / 2.5).clamp(10.0, 16.0).toDouble();
    return local.dy < hit.rect.bottom - handleH;
  }

  Drag? _onInstantStart(Offset global) {
    _startDrag(_toLocal(global));
    if (_dragEvent == null) return null;
    return _InstantDrag(
      onUpdate: (g) => _moveDrag(_toLocal(g), g),
      onEnd: _endDrag,
      onCancel: _cancelDrag,
    );
  }

  // Góc trên trái của khối đang theo ngón tay (tính cả phần bảng đã tự cuộn)
  Offset get _ghostTopLeft {
    final y = _finger.dy + (_scrollOffset - _scrollAtFinger);
    return Offset(_finger.dx - _grab.dx, y - _grab.dy);
  }

  // Ô đích (ngày, phút bắt đầu) ứng với vị trí đang kéo, đã làm tròn 15 phút
  ({int day, int minute}) _target() {
    final e = _dragEvent!;
    final g = _ghostTopLeft;
    final center = g.dx + _dragSize.width / 2;
    final day = ((center - _gutter) / _colW).floor().clamp(0, 6).toInt();
    final dur = e.end.difference(e.start).inMinutes;
    final minute = snapMinute(g.dy / _hourHeight * 60)
        .clamp(0, math.max(0, _maxMinute - dur))
        .toInt();
    return (day: day, minute: minute);
  }

  // Kéo sát mép trên/dưới thì cuộn dọc; sát mép trái/phải thì (sau một lúc) lật tuần
  void _updateAutoScrollAndEdges(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = global - box.localToGlobal(Offset.zero);
    final h = box.size.height;
    final w = box.size.width;

    var v = 0.0;
    if (_armed) {
      const edgeV = 56.0;
      if (local.dy < edgeV) {
        v = -math.min(14.0, (edgeV - local.dy) / edgeV * 14);
      } else if (local.dy > h - edgeV) {
        v = math.min(14.0, (local.dy - (h - edgeV)) / edgeV * 14);
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
        if (mounted) _frame.value++;
      });
    }

    var dir = 0;
    if (_armed && widget.onWeekShift != null) {
      if (local.dx < _gutter + _edgeZone) {
        dir = -1;
      } else if (local.dx > w - _edgeZone) {
        dir = 1;
      }
    }
    _setEdge(dir);
  }

  void _setEdge(int dir) {
    if (dir == _edgeDir) return;
    _edgeDir = dir;
    _edgeTimer?.cancel();
    _edgeTimer = null;
    if (dir != 0) {
      _edgeTimer = Timer(const Duration(milliseconds: 700), _flipWeek);
    }
  }

  void _flipWeek() {
    final shift = widget.onWeekShift;
    if (_dragEvent == null || _edgeDir == 0 || shift == null) return;
    HapticFeedback.selectionClick();
    shift(_edgeDir);
    // Vẫn giữ ở mép thì lật tiếp
    _edgeTimer?.cancel();
    _edgeTimer = Timer(const Duration(milliseconds: 900), _flipWeek);
  }

  void _stopAuto() {
    _autoVelocity = 0;
    _autoTimer?.cancel();
    _autoTimer = null;
    _edgeDir = 0;
    _edgeTimer?.cancel();
    _edgeTimer = null;
  }

  void _endDrag() {
    final e = _dragEvent;
    if (e == null) return;
    final t = _target();
    final day = _days[t.day];
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
    final dragging = _dragEvent != null;

    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ClipRect(
            child: _slid(days, (d, _) => _buildHeader(d, today, scheme)),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(
            key: _viewportKey,
            child: LayoutBuilder(
              builder: (context, c) {
                final colW = (c.maxWidth - _gutter) / 7;
                _colW = colW;
                _days = days;
                return SingleChildScrollView(
                  controller: _scroll,
                  // Đang dời hoặc giãn thì khóa cuộn bằng tay
                  physics: (dragging || _resizeEvent != null)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  child: SizedBox(
                    width: c.maxWidth,
                    height: 24 * _hourHeight,
                    child: Stack(
                      children: [
                        _slid(
                          days,
                          (d, current) => _gridLayer(
                            d,
                            colW,
                            scheme,
                            today,
                            lineColor,
                            current,
                          ),
                        ),
                        // Lớp nhận cử chỉ cho cả bảng (chạm, giữ rồi kéo)
                        Positioned.fill(
                          child: RawGestureDetector(
                            key: _gestureKey,
                            behavior: HitTestBehavior.translucent,
                            gestures: widget.instantDrag
                                ? {
                                    _InstantDragRecognizer:
                                        GestureRecognizerFactoryWithHandlers<
                                          _InstantDragRecognizer
                                        >(
                                          () => _InstantDragRecognizer(
                                            _allowInstant,
                                          ),
                                          (r) => r.onStart = _onInstantStart,
                                        ),
                                  }
                                : const {},
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: _onTapUp,
                              onLongPressStart: widget.instantDrag
                                  ? null
                                  : _onLongPressStart,
                              onLongPressMoveUpdate: widget.instantDrag
                                  ? null
                                  : _onLongPressMove,
                              onLongPressEnd: widget.instantDrag
                                  ? null
                                  : _onLongPressEnd,
                              onLongPressCancel: widget.instantDrag
                                  ? null
                                  : _cancelDrag,
                            ),
                          ),
                        ),
                        // Khối đang kéo, ô đích và dải báo mép
                        if (dragging) ...[
                          ..._edgeStrips(c.maxHeight, scheme),
                          ValueListenableBuilder<int>(
                            valueListenable: _frame,
                            builder: (context, _, _) => Positioned.fill(
                              child: Stack(children: _buildDragOverlay(scheme)),
                            ),
                          ),
                        ],
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

  // Lớp lưới (đường kẻ, khối lịch, đường "bây giờ") của một tuần
  Widget _gridLayer(
    List<DateTime> days,
    double colW,
    ColorScheme scheme,
    DateTime today,
    Color lineColor,
    bool current,
  ) {
    final todayIdx = days.indexOf(today);
    final nowMin = _minuteOfDay(DateTime.now());
    return Stack(
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
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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
              child: ColoredBox(color: scheme.primary.withValues(alpha: 0.06)),
            ),
          ),
        // Các khối lịch
        ..._buildBlocks(days, colW, current: current),
        // Đường "bây giờ"
        if (todayIdx >= 0) ...[
          Positioned(
            left: _gutter + todayIdx * colW,
            width: colW,
            top: _topFor(nowMin) - 1,
            height: 2,
            child: const IgnorePointer(child: ColoredBox(color: Colors.red)),
          ),
          Positioned(
            left: _gutter + todayIdx * colW - 4,
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
      ],
    );
  }

  // Đổi tuần thì tuần cũ trượt ra, tuần mới trượt vào
  Widget _slid(
    List<DateTime> days,
    Widget Function(List<DateTime> days, bool current) layer,
  ) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final cur = layer(days, true);
        if (!_slide.isAnimating) return cur;
        final t = Curves.easeOutCubic.transform(_slide.value);
        return Stack(
          children: [
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(-_slideDir * t, 0),
                child: layer(_oldDays, false),
              ),
            ),
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(_slideDir * (1 - t), 0),
                child: cur,
              ),
            ),
          ],
        );
      },
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
                onTap: () => widget.onDaySelected?.call(day),
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

  List<Widget> _buildBlocks(
    List<DateTime> days,
    double colW, {
    bool current = true,
  }) {
    final widgets = <Widget>[];
    final hits = <_Hit>[];

    for (var di = 0; di < 7; di++) {
      final dayEvents = widget.events
          .where((e) => _dateOnly(e.start) == days[di])
          .toList();
      for (final p in layoutDay(dayEvents)) {
        final e = p.event;
        final editable = _canEdit(e);
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
        hits.add(_Hit(e, Rect.fromLTWH(left, top, width, height)));

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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _blockBody(e, height, editable: editable),
                  ),
                  // Thanh nhỏ ở đáy để đổi giờ kết thúc
                  if (editable)
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
        );
      }
    }
    if (current) _hits = hits;
    return widgets;
  }

  // Nội dung một khối lịch. [start]/[end] dùng để hiện giờ mới khi đang kéo.
  Widget _blockBody(
    Event e,
    double height, {
    bool editable = true,
    bool dragging = false,
    DateTime? start,
    DateTime? end,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final past = widget.isPast(e);
    final highlight = widget.isHighlighted?.call(e) ?? false;
    final base = past ? Colors.grey : widget.colorOf(e);
    final fg = base.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    final lines = math.max(1, ((height - 6) / 12).floor());
    // Giờ đã có ở cột bên trái; chỉ hiện khi đang kéo để thấy giờ mới
    final showTime = dragging && height >= 40;
    final conflict = widget.hasConflict(e) && !past;
    final alpha = dragging ? 0.95 : (!editable ? 0.55 : (past ? 0.75 : 0.88));

    Border? border;
    if (conflict) {
      border = Border.all(color: _orange, width: highlight ? 3 : 2);
    } else if (highlight) {
      border = Border.all(color: scheme.primary, width: 3);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(5),
        border: border,
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

  // Hai dải mờ ở mép trái/phải báo "kéo vào đây để sang tuần khác"
  List<Widget> _edgeStrips(double viewportH, ColorScheme scheme) {
    if (widget.onWeekShift == null) return const [];
    Widget strip({required bool left}) {
      final active = _edgeDir == (left ? -1 : 1);
      return Positioned(
        left: left ? _gutter : null,
        right: left ? null : 0,
        top: _scrollOffset,
        height: viewportH,
        width: _edgeZone + 6,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: active ? 0.30 : 0.10),
            ),
            child: Center(
              child: Icon(
                left ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return [strip(left: true), strip(left: false)];
  }

  List<Widget> _buildDragOverlay(ColorScheme scheme) {
    final e = _dragEvent!;
    final t = _target();
    final day = _days[t.day];
    final newStart = DateTime(day.year, day.month, day.day, 0, t.minute);
    final newEnd = newStart.add(e.end.difference(e.start));
    final g = _ghostTopLeft;

    return [
      // Ô đích đã làm tròn: nơi khối sẽ nằm khi thả tay
      Positioned(
        left: _gutter + t.day * _colW + 1,
        top: _topFor(t.minute),
        width: _colW - 2,
        height: _dragSize.height,
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
        left: g.dx,
        top: g.dy,
        width: _dragSize.width,
        height: _dragSize.height,
        child: IgnorePointer(
          child: _blockBody(
            e,
            _dragSize.height,
            dragging: true,
            start: newStart,
            end: newEnd,
          ),
        ),
      ),
    ];
  }
}
