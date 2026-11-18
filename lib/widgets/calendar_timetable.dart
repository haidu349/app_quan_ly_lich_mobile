import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/services/timetable_layout.dart';
import 'package:quan_ly_lich/services/timetable_pages.dart';
import 'package:quan_ly_lich/utils/format.dart';

enum TimetableMode { day, week }

const Color _orange = Color(0xFFE65100);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Khối đang được chọn: lịch có sẵn (source != null) hoặc lịch nháp mới (source == null)
class _Active {
  final Event? source;
  final DateTime start;
  final DateTime end;

  const _Active({this.source, required this.start, required this.end});

  _Active withTimes(DateTime s, DateTime e) =>
      _Active(source: source, start: s, end: e);
}

// Bảng giờ: các hàng là giờ trong ngày, mỗi trang là một tuần (7 cột) hoặc một ngày (1 cột).
// - Chạm vào ô trống: tạo khối nháp 1 giờ. Chạm vào lịch: chọn lịch.
// - Khối đang chọn có viền: giữ và kéo để dời, kéo chấm tròn để đổi giờ bắt đầu/kết thúc.
// - Chạm ra ngoài: bỏ chọn. Không chọn gì thì vuốt trái phải để đổi trang.
class CalendarTimetable extends StatefulWidget {
  final TimetableMode mode;
  final DateTime anchorDay; // ngày đang chọn: xác định trang đang hiển thị
  final List<Event> events;
  final Color Function(Event event) colorOf;
  final bool Function(Event event) hasConflict;
  final bool Function(Event event) isPast;
  final ValueChanged<DateTime> onAnchorChanged;
  final Future<void> Function(Event old, DateTime start, DateTime end)
  onEventChanged;
  final void Function(Event event) onOpenEvent;
  final Future<void> Function(DateTime start, DateTime end) onCreate;
  final void Function(Event event) onDeleteEvent;
  final ValueChanged<bool>? onSelectionChanged;
  final ValueChanged<DateTime>? onDayTap;

  const CalendarTimetable({
    super.key,
    required this.mode,
    required this.anchorDay,
    required this.events,
    required this.colorOf,
    required this.hasConflict,
    required this.isPast,
    required this.onAnchorChanged,
    required this.onEventChanged,
    required this.onOpenEvent,
    required this.onCreate,
    required this.onDeleteEvent,
    this.onSelectionChanged,
    this.onDayTap,
  });

  @override
  State<CalendarTimetable> createState() => _CalendarTimetableState();
}

class _CalendarTimetableState extends State<CalendarTimetable> {
  static const double _hourHeight = 56; // chiều cao một giờ (một ô)
  static const double _gutter = 40; // cột ghi giờ bên trái
  static const double _minBlockHeight = 20;
  static const double _handleZone = 30; // vùng chạm của chấm tròn
  static const double _edgeZone = 28; // vùng mép trái/phải để lật trang
  static const int _lastMinute = 24 * 60 - 1; // 23:59

  late final PageController _pages;
  late final ScrollController _vScroll;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  late int _page;
  double _bodyW = 1; // bề rộng vùng các trang (không gồm cột giờ)
  double _colW = 1; // bề rộng một cột ngày
  // Chiều cao vùng cuộn, lấy từ LayoutBuilder. Không đọc context.size trong
  // build vì sẽ báo lỗi "Cannot get size during build".
  double _viewportH = 400;

  _Active? _active;
  bool _committing = false;

  // ---- Đang dời cả khối ----
  bool _moving = false;
  bool _armed = false; // đã kéo đủ xa mới bật tự cuộn và lật trang
  int? _pointer;
  Offset _moveDown = Offset.zero; // vị trí chạm đầu tiên (toạ độ màn hình)
  Offset _fingerGlobal = Offset.zero;
  Offset _grab = Offset.zero; // chỗ ngón tay nắm trong khối
  Size _moveSize = Size.zero;

  // ---- Đang giãn khối: -1 = cạnh trên, 1 = cạnh dưới, 0 = không ----
  int _resizeEdge = 0;
  double _resizeGrab = 0;

  Timer? _autoTimer;
  double _autoVelocity = 0;
  Timer? _edgeTimer;
  int _edgeDir = 0;

  // Khi kéo/thả, chỉ các lớp phủ cần vẽ lại. Tăng giá trị này thay vì gọi
  // setState() trên toàn widget, nếu không cả bảng giờ sẽ bị dựng lại mỗi frame.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // Cache kết quả tìm lịch trùng theo (giờ, id, danh sách sự kiện) để không
  // phải duyệt lại toàn bộ sự kiện ở mỗi chuyển động của ngón tay.
  int? _conflictKey;
  List<Event>? _conflictCache;

  bool get _isWeek => widget.mode == TimetableMode.week;
  int get _cols => _isWeek ? 7 : 1;

  int _pageFor(DateTime d) => pageOfDay(d, week: _isWeek);
  int _firstDayNumber(int page) => firstDayNumberOfPage(page, week: _isWeek);

  // ---------- Vòng đời ----------

  @override
  void initState() {
    super.initState();
    _page = _pageFor(widget.anchorDay);
    _pages = PageController(initialPage: _page);
    final hour = DateTime.now().hour;
    _vScroll = ScrollController(
      initialScrollOffset: math.max(0, hour - 1) * _hourHeight,
    );
  }

  @override
  void didUpdateWidget(covariant CalendarTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Bên ngoài đổi ngày (bấm lưới tháng, chọn ngày...) thì chuyển trang theo
    final target = _pageFor(widget.anchorDay);
    if (target != _page && _pages.hasClients) {
      if (_active != null) {
        _active = null;
        _notifySelection();
      }
      if ((target - _page).abs() <= 3) {
        _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pages.jumpToPage(target);
      }
    }

    // Dữ liệu đổi (sửa, hoàn tác, xóa) thì cập nhật khối đang chọn
    if (!_moving && _resizeEdge == 0 && !_committing) _refreshActive();
  }

  @override
  void dispose() {
    _stopAuto();
    _pages.dispose();
    _vScroll.dispose();
    _frame.dispose();
    super.dispose();
  }

  // Đồng bộ khối đang chọn với dữ liệu mới nhất
  void _refreshActive() {
    final a = _active;
    final src = a?.source;
    if (a == null || src == null) return;
    Event? fresh;
    for (final e in widget.events) {
      if (e.id == src.id) {
        fresh = e;
        break;
      }
    }
    if (fresh == null) {
      _active = null; // lịch đã bị xóa
      _notifySelection();
      return;
    }
    _active = _Active(source: fresh, start: fresh.start, end: fresh.end);
  }

  void _notifySelection() {
    final has = _active != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectionChanged?.call(has);
    });
  }

  // Tìm lịch trùng cho khối đang chọn. Kết quả được nhớ theo thời gian + danh
  // sách sự kiện để không phải duyệt lại trên từng frame lúc kéo/giãn.
  List<Event> _conflictsFor(DateTime start, DateTime end, int? id) {
    final key = Object.hash(
      identityHashCode(widget.events),
      widget.events.length,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      id,
    );
    final cached = _conflictCache;
    if (_conflictKey == key && cached != null) return cached;
    final result = findConflicts(
      Event(id: id, name: '', start: start, end: end),
      widget.events,
    );
    _conflictKey = key;
    _conflictCache = result;
    return result;
  }

  // Đặt (hoặc bỏ) khối đang chọn; chỉ gọi từ các hàm xử lý cử chỉ
  void _setActive(_Active? a) {
    final had = _active != null;
    _stopAuto();
    setState(() {
      _active = a;
      _moving = false;
      _resizeEdge = 0;
      _pointer = null;
    });
    if (had != (a != null)) widget.onSelectionChanged?.call(a != null);
  }

  // ---------- Tiện ích ----------

  double _topFor(int minuteOfDay) => minuteOfDay / 60 * _hourHeight;

  double get _pageFloat {
    if (_pages.hasClients &&
        _pages.position.hasPixels &&
        _pages.position.hasContentDimensions) {
      return _pages.page ?? _page.toDouble();
    }
    return _page.toDouble();
  }

  Offset _localOf(Offset global) {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return global;
    return box.globalToLocal(global);
  }

  Rect _blockRect(PlacedEvent pl, int col) {
    final e = pl.event;
    final startMin = e.start.hour * 60 + e.start.minute;
    final durMin = e.end.difference(e.start).inMinutes;
    final subW = _colW / pl.columns;
    final left = col * _colW + pl.column * subW + 1;
    final width = math.max(8.0, subW - 2);
    final top = _topFor(startMin);
    final height = math.max(_minBlockHeight, durMin / 60 * _hourHeight - 1);
    return Rect.fromLTWH(left, top, width, height);
  }

  void _onPageChanged(int p) {
    _page = p;
    final first = dateOfDayNumber(_firstDayNumber(p));
    DateTime anchor = first;
    if (_isWeek) {
      final off = widget.anchorDay.weekday - 1; // giữ nguyên thứ trong tuần
      anchor = DateTime(first.year, first.month, first.day + off);
    }
    widget.onAnchorChanged(anchor);
  }

  // ---------- Chạm vào trang ----------

  void _onPageTap(int p, Offset local, Map<int, List<Event>> byDay) {
    final col = clampInt((local.dx / _colW).floor(), 0, _cols - 1);
    final n = _firstDayNumber(p) + col;

    // Chạm trúng lịch nào không
    Event? hit;
    final list = byDay[n];
    if (list != null) {
      final placed = layoutDay(list);
      for (var i = placed.length - 1; i >= 0; i--) {
        if (_blockRect(placed[i], col).contains(local)) {
          hit = placed[i].event;
          break;
        }
      }
    }

    if (hit != null) {
      HapticFeedback.selectionClick();
      _setActive(_Active(source: hit, start: hit.start, end: hit.end));
      _reveal();
      return;
    }
    // Đang chọn mà chạm ra ngoài: chỉ bỏ chọn
    if (_active != null) {
      _setActive(null);
      return;
    }
    // Ô trống: tạo khối nháp dài đúng 1 giờ (1 ô)
    final day = dateOfDayNumber(n);
    final hour = clampInt((local.dy / _hourHeight).floor(), 0, 23);
    final start = DateTime(day.year, day.month, day.day, hour);
    final end = hour == 23
        ? DateTime(day.year, day.month, day.day, 23, 59)
        : start.add(const Duration(hours: 1));
    HapticFeedback.selectionClick();
    _setActive(_Active(start: start, end: end));
    _reveal();
  }

  // Cuộn để khối đang chọn không bị khuất sau thanh dưới
  void _reveal() {
    Future.delayed(const Duration(milliseconds: 220), () {
      final a = _active;
      if (!mounted || a == null || !_vScroll.hasClients) return;
      final top = _topFor(a.start.hour * 60 + a.start.minute);
      final dur = a.end.difference(a.start).inMinutes;
      final bottom = top + math.max(_minBlockHeight, dur / 60 * _hourHeight);
      final vh = _viewportH;
      final off = _vScroll.offset;
      double? target;
      if (top - 24 < off) {
        target = top - 24;
      } else if (bottom + 24 > off + vh) {
        target = bottom + 24 - vh;
      }
      if (target != null) {
        _vScroll.animateTo(
          target.clamp(0.0, _vScroll.position.maxScrollExtent).toDouble(),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- Mở form từ khối đang chọn ----------

  Future<void> _openActive() async {
    final a = _active;
    if (a == null) return;
    final src = a.source;
    if (src != null) {
      widget.onOpenEvent(src);
      return;
    }
    await widget.onCreate(a.start, a.end);
    if (mounted) _setActive(null);
  }

  // Lưu thay đổi giờ của lịch có sẵn (có Hoàn tác ở màn hình ngoài)
  Future<void> _commit(Event source, DateTime s, DateTime e) async {
    if (s == source.start && e == source.end) return;
    _committing = true;
    try {
      await widget.onEventChanged(source, s, e);
    } finally {
      _committing = false;
      if (mounted) setState(_refreshActive);
    }
  }

  // ---------- Dời cả khối ----------

  void _bodyDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _moveDown = e.position;
    _fingerGlobal = e.position;
    _moving = false;
    _armed = false;
  }

  void _bodyMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _fingerGlobal = e.position;
    if (!_moving) {
      if ((e.position - _moveDown).distance < 8) return;
      _beginMove();
    }
    if (!_armed && (e.position - _moveDown).distance > 24) _armed = true;
    // Chỉ vẽ lại lớp phủ đang kéo, không dựng lại cả bảng giờ.
    _frame.value++;
    _updateAutoScroll(e.position, edges: true);
  }

  void _bodyUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_moving) {
      _endMove();
    } else {
      _openActive();
    }
  }

  void _bodyCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _stopAuto();
    if (_moving) setState(() => _moving = false);
  }

  void _beginMove() {
    final a = _active;
    if (a == null) return;
    final pf = _pageFloat;
    final n = dayNumber(a.start);
    final left = _gutter + n * _colW - pf * _bodyW + 1;
    final top = _topFor(a.start.hour * 60 + a.start.minute);
    final dur = a.end.difference(a.start).inMinutes;
    _moveSize = Size(
      math.max(8.0, _colW - 2),
      math.max(_minBlockHeight, dur / 60 * _hourHeight - 1),
    );
    _grab = _localOf(_moveDown) - Offset(left, top);
    _moving = true;
    HapticFeedback.mediumImpact();
  }

  // Góc trên trái của khối đang theo ngón tay (toạ độ trong vùng các trang)
  Offset _ghostTopLeftRel() {
    final f = _localOf(_fingerGlobal);
    return Offset(f.dx - _grab.dx - _gutter, f.dy - _grab.dy);
  }

  // Ô đích (số ngày, phút bắt đầu) ứng với vị trí khối, đã làm tròn 15 phút
  ({int absDay, int minute}) _moveTarget(
    double relLeft,
    double top,
    int dur,
    double pf,
  ) {
    final centerX = relLeft + _moveSize.width / 2;
    final absDay = math.max(0, ((pf * _bodyW + centerX) / _colW).floor());
    final minute = clampInt(
      snapMinute(top / _hourHeight * 60),
      0,
      _lastMinute - dur,
    );
    return (absDay: absDay, minute: minute);
  }

  void _endMove() {
    final a = _active;
    if (a == null) {
      _moving = false;
      return;
    }
    final dur = a.end.difference(a.start).inMinutes;
    final g = _ghostTopLeftRel();
    final t = _moveTarget(g.dx, g.dy, dur, _pageFloat);
    final day = dateOfDayNumber(t.absDay);
    final s = DateTime(day.year, day.month, day.day, 0, t.minute);
    final e = s.add(Duration(minutes: dur));
    _stopAuto();
    setState(() {
      _moving = false;
      _active = a.withTimes(s, e);
    });
    final src = a.source;
    if (src != null) _commit(src, s, e);
  }

  // ---------- Giãn khối bằng chấm tròn ----------

  void _handleDown(PointerDownEvent e, int edge) {
    final a = _active;
    if (a == null || _pointer != null) return;
    _pointer = e.pointer;
    _fingerGlobal = e.position;
    final day0 = _dateOnly(a.start);
    final edgeMin = edge < 0
        ? a.start.hour * 60 + a.start.minute
        : a.end.difference(day0).inMinutes;
    _resizeEdge = edge;
    _resizeGrab = _localOf(e.position).dy - _topFor(edgeMin);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _handleMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _resizeEdge == 0) return;
    _fingerGlobal = e.position;
    _applyResize();
    _updateAutoScroll(e.position, edges: false);
  }

  void _handleUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _stopAuto();
    final a = _active;
    setState(() => _resizeEdge = 0);
    final src = a?.source;
    if (a != null && src != null) _commit(src, a.start, a.end);
  }

  void _handleCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _stopAuto();
    setState(() => _resizeEdge = 0);
  }

  void _applyResize() {
    final a = _active;
    if (a == null || _resizeEdge == 0) return;
    final y = _localOf(_fingerGlobal).dy - _resizeGrab;
    final day0 = _dateOnly(a.start);
    final startMin = a.start.hour * 60 + a.start.minute;
    final endMin = a.end.difference(day0).inMinutes;
    final m = snapMinute(y / _hourHeight * 60);
    var s = a.start;
    var e = a.end;
    if (_resizeEdge < 0) {
      s = DateTime(
        day0.year,
        day0.month,
        day0.day,
        0,
        clampInt(m, 0, endMin - 15),
      );
    } else {
      e = DateTime(
        day0.year,
        day0.month,
        day0.day,
        0,
        clampInt(m, startMin + 15, _lastMinute),
      );
    }
    if (s != a.start || e != a.end) {
      // Cập nhật trực tiếp rồi báo lớp phủ tự vẽ; setState() ở đây sẽ dựng
      // lại toàn bộ PageView và các khối lịch trên mỗi chuyển động của tay.
      _active = a.withTimes(s, e);
      _frame.value++;
    }
  }

  // ---------- Tự cuộn và lật trang khi kéo sát mép ----------

  void _updateAutoScroll(Offset global, {required bool edges}) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(global);
    final h = box.size.height;
    final w = box.size.width;

    var v = 0.0;
    const edgeV = 56.0;
    if (local.dy < edgeV) {
      v = -math.min(14.0, (edgeV - local.dy) / edgeV * 14);
    } else if (local.dy > h - edgeV) {
      v = math.min(14.0, (local.dy - (h - edgeV)) / edgeV * 14);
    }
    _autoVelocity = v;
    if (v != 0 && _autoTimer == null) {
      _autoTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (_autoVelocity == 0 || !_vScroll.hasClients) return;
        final target = (_vScroll.offset + _autoVelocity)
            .clamp(0.0, _vScroll.position.maxScrollExtent)
            .toDouble();
        _vScroll.jumpTo(target);
        if (!mounted) return;
        if (_resizeEdge != 0) {
          _applyResize();
        } else {
          _frame.value++;
        }
      });
    }

    var dir = 0;
    if (edges && _armed) {
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
      _edgeTimer = Timer(const Duration(milliseconds: 700), _flipPage);
    }
  }

  void _flipPage() {
    if (!_moving || _edgeDir == 0) return;
    final target = _page + _edgeDir;
    if (target < 0) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    _edgeTimer?.cancel();
    _edgeTimer = Timer(const Duration(milliseconds: 950), _flipPage);
  }

  void _stopAuto() {
    _autoVelocity = 0;
    _autoTimer?.cancel();
    _autoTimer = null;
    _edgeDir = 0;
    _edgeTimer?.cancel();
    _edgeTimer = null;
  }

  // ---------- Giao diện ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Gom lịch theo ngày; lịch đang chọn được vẽ riêng ở lớp phủ
    final activeId = _active?.source?.id;
    final byDay = <int, List<Event>>{};
    for (final e in widget.events) {
      if (activeId != null && e.id == activeId) continue;
      byDay.putIfAbsent(dayNumber(e.start), () => []).add(e);
    }

    return Column(
      children: [
        _buildHeaderBar(scheme),
        const Divider(height: 1),
        Expanded(child: _buildBody(scheme, byDay)),
        _buildActionBar(scheme),
      ],
    );
  }

  // ----- Hàng tên thứ và ngày, trượt theo các trang -----

  Widget _buildHeaderBar(ColorScheme scheme) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: _gutter),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _pages,
                    builder: (context, _) {
                      final pf = _pageFloat;
                      final lo = pf.floor();
                      return Stack(
                        children: [
                          for (final p in [lo, lo + 1])
                            if (p >= 0)
                              Positioned(
                                left: (p - pf) * w,
                                top: 0,
                                bottom: 0,
                                width: w,
                                child: _headerPage(p, scheme),
                              ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPage(int p, ColorScheme scheme) {
    final today = _dateOnly(DateTime.now());
    final selected = _dateOnly(widget.anchorDay);
    final first = _firstDayNumber(p);
    return Row(
      children: [
        for (var i = 0; i < _cols; i++)
          Expanded(
            child: _headerCell(
              dateOfDayNumber(first + i),
              today,
              selected,
              scheme,
            ),
          ),
      ],
    );
  }

  Widget _headerCell(
    DateTime day,
    DateTime today,
    DateTime selected,
    ColorScheme scheme,
  ) {
    return InkWell(
      onTap: widget.onDayTap == null ? null : () => widget.onDayTap!(day),
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
              border: (day == selected && day != today && _isWeek)
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
    );
  }

  // ----- Thân bảng: cuộn dọc, các trang vuốt ngang -----

  Widget _buildBody(ColorScheme scheme, Map<int, List<Event>> byDay) {
    final lineColor = Colors.grey.withValues(alpha: 0.25);
    return KeyedSubtree(
      key: _viewportKey,
      child: LayoutBuilder(
        builder: (context, c) {
          _bodyW = math.max(1.0, c.maxWidth - _gutter);
          _colW = _bodyW / _cols;
          if (c.hasBoundedHeight) _viewportH = c.maxHeight;

          return SingleChildScrollView(
            controller: _vScroll,
            child: SizedBox(
              width: c.maxWidth,
              height: 24 * _hourHeight,
              child: Stack(
                key: _contentKey,
                children: [
                  ..._hourGrid(lineColor),
                  Positioned(
                    left: _gutter,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: PageView.builder(
                      controller: _pages,
                      // Đang chọn khối thì tắt vuốt ngang; bỏ chọn là vuốt lại được
                      physics: _active != null
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, p) => _buildPage(p, byDay),
                    ),
                  ),
                  if (_active != null) _buildActiveLayer(scheme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _hourGrid(Color lineColor) {
    return [
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
    ];
  }

  // Một trang: các cột ngày, lịch (chưa chọn), đường "bây giờ", lớp nhận chạm
  Widget _buildPage(int p, Map<int, List<Event>> byDay) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = Colors.grey.withValues(alpha: 0.25);
    final firstN = _firstDayNumber(p);
    final now = DateTime.now();
    final todayCol = dayNumber(now) - firstN;
    final nowMin = now.hour * 60 + now.minute;
    final children = <Widget>[];

    for (var i = 0; i <= _cols; i++) {
      children.add(
        Positioned(
          left: i * _colW,
          top: 0,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: lineColor),
        ),
      );
    }
    if (todayCol >= 0 && todayCol < _cols) {
      children.add(
        Positioned(
          left: todayCol * _colW,
          width: _colW,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: ColoredBox(color: scheme.primary.withValues(alpha: 0.06)),
          ),
        ),
      );
    }

    for (var i = 0; i < _cols; i++) {
      final list = byDay[firstN + i];
      if (list == null) continue;
      for (final pl in layoutDay(list)) {
        final e = pl.event;
        final rect = _blockRect(pl, i);
        children.add(
          Positioned.fromRect(
            key: ValueKey('ev_${e.id}'),
            rect: rect,
            child: IgnorePointer(
              child: _blockBody(
                title: e.name,
                start: e.start,
                end: e.end,
                height: rect.height,
                base: widget.colorOf(e),
                past: widget.isPast(e),
                conflict: widget.hasConflict(e) && !widget.isPast(e),
              ),
            ),
          ),
        );
      }
    }

    if (todayCol >= 0 && todayCol < _cols) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: _topFor(nowMin) - 1,
          height: 2,
          child: const IgnorePointer(child: ColoredBox(color: Colors.red)),
        ),
      );
      children.add(
        Positioned(
          left: todayCol * _colW - 4,
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
      );
    }

    // Lớp nhận chạm cho cả trang (chạm ô trống hoặc chạm vào lịch)
    children.add(
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onPageTap(p, d.localPosition, byDay),
        ),
      ),
    );

    return Stack(children: children);
  }

  // Giao diện một khối lịch (dùng cho khối thường và khối đang chọn)
  Widget _blockBody({
    required String title,
    required DateTime start,
    required DateTime end,
    required double height,
    required Color base,
    bool past = false,
    bool conflict = false,
    bool selected = false,
    bool dragging = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final c = past ? Colors.grey : base;
    final fg = c.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    final lines = math.max(1, ((height - 6) / 12).floor());
    final showTime = height >= 40;

    Border? border;
    if (conflict) {
      border = Border.all(color: _orange, width: selected ? 3 : 2);
    } else if (selected) {
      border = Border.all(color: scheme.onSurface, width: 2);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      decoration: BoxDecoration(
        color: c.withValues(
          alpha: (dragging || selected) ? 0.95 : (past ? 0.75 : 0.88),
        ),
        borderRadius: BorderRadius.circular(5),
        border: border,
        boxShadow: (dragging || selected)
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
            TextSpan(text: title),
            if (showTime)
              TextSpan(
                text: '\n${formatTimeRange(start, end)}',
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

  // ----- Lớp phủ: khối đang chọn, chấm tròn, ô đích -----

  Widget _buildActiveLayer(ColorScheme scheme) {
    return Positioned(
      left: _gutter,
      right: 0,
      top: 0,
      bottom: 0,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _pages,
          builder: (context, _) => ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, _) => _activeStack(scheme),
          ),
        ),
      ),
    );
  }

  Widget _activeStack(ColorScheme scheme) {
    final a = _active;
    if (a == null) return const SizedBox.shrink();
    final pf = _pageFloat;
    final dur = a.end.difference(a.start).inMinutes;
    final width = math.max(8.0, _colW - 2);
    final height = math.max(_minBlockHeight, dur / 60 * _hourHeight - 1);
    final n = dayNumber(a.start);

    var left = n * _colW - pf * _bodyW + 1;
    var top = _topFor(a.start.hour * 60 + a.start.minute);
    var shownStart = a.start;
    var shownEnd = a.end;
    final extras = <Widget>[];

    if (_moving) {
      final g = _ghostTopLeftRel();
      left = g.dx;
      top = g.dy;
      final t = _moveTarget(g.dx, g.dy, dur, pf);
      final day = dateOfDayNumber(t.absDay);
      shownStart = DateTime(day.year, day.month, day.day, 0, t.minute);
      shownEnd = shownStart.add(Duration(minutes: dur));
      // Ô đích đã làm tròn: nơi khối sẽ nằm khi thả tay
      extras.add(
        Positioned(
          left: t.absDay * _colW - pf * _bodyW + 1,
          top: _topFor(t.minute),
          width: width,
          height: height,
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
      );
      extras.addAll(_edgeStrips(scheme));
    }

    final src = a.source;
    final base = src != null ? widget.colorOf(src) : scheme.primary;
    final conflict = _conflictsFor(shownStart, shownEnd, src?.id).isNotEmpty;

    final body = _EagerPointer(
      onDown: _bodyDown,
      onMove: _bodyMove,
      onUp: _bodyUp,
      onCancel: _bodyCancel,
      child: _blockBody(
        title: src?.name ?? 'Lịch mới',
        start: shownStart,
        end: shownEnd,
        height: height,
        base: base,
        conflict: conflict,
        selected: true,
        dragging: _moving,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...extras,
        Positioned(
          left: left,
          top: top - _handleZone,
          width: width,
          height: height + 2 * _handleZone,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _handleZone,
                height: height,
                child: body,
              ),
              if (!_moving) ...[
                // Chấm tròn ở cạnh trên: đổi giờ bắt đầu
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _handleZone + 7,
                  child: _EagerPointer(
                    onDown: (e) => _handleDown(e, -1),
                    onMove: _handleMove,
                    onUp: _handleUp,
                    onCancel: _handleCancel,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _handleDot(scheme),
                    ),
                  ),
                ),
                // Chấm tròn ở cạnh dưới: đổi giờ kết thúc
                Positioned(
                  left: 0,
                  right: 0,
                  top: _handleZone + height - 7,
                  height: _handleZone + 7,
                  child: _EagerPointer(
                    onDown: (e) => _handleDown(e, 1),
                    onMove: _handleMove,
                    onUp: _handleUp,
                    onCancel: _handleCancel,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _handleDot(scheme),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _handleDot(ColorScheme scheme) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
    );
  }

  // Hai dải mờ ở mép trái/phải báo "kéo vào đây để sang trang khác"
  List<Widget> _edgeStrips(ColorScheme scheme) {
    final vh = _viewportH;
    final off = _vScroll.hasClients ? _vScroll.offset : 0.0;

    Widget strip({required bool left}) {
      final active = _edgeDir == (left ? -1 : 1);
      return Positioned(
        left: left ? 0 : null,
        right: left ? null : 0,
        top: off,
        height: vh,
        width: _edgeZone,
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

  // ----- Thanh hành động ở dưới khi có khối đang chọn -----

  Widget _buildActionBar(ColorScheme scheme) {
    final a = _active;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: a == null
          ? const SizedBox(width: double.infinity)
          : _actionBarContent(a, scheme),
    );
  }

  Widget _actionBarContent(_Active a, ColorScheme scheme) {
    final src = a.source;
    final isDraft = src == null;
    final base = isDraft ? scheme.primary : widget.colorOf(src);
    final conflicts = _conflictsFor(a.start, a.end, src?.id);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDraft ? 'Lịch mới' : src.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${formatDayHeader(a.start)}  •  ${formatTimeRange(a.start, a.end)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                  if (conflicts.isNotEmpty)
                    Text(
                      'Trùng với ${conflicts.length} lịch',
                      style: const TextStyle(
                        color: _orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (isDraft) ...[
              TextButton(
                onPressed: () => _setActive(null),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: _openActive,
                child: const Text('Nhập chi tiết'),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xóa',
                onPressed: () => widget.onDeleteEvent(src),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Bỏ chọn',
                onPressed: () => _setActive(null),
              ),
              FilledButton.tonal(
                onPressed: _openActive,
                child: const Text('Sửa'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Vùng nhận cử chỉ "thắng ngay": ngón tay chạm vào đây thì không bị bảng cuộn
// dọc cướp mất. Việc dời và giãn tự tính từ các sự kiện chạm thô (Listener).
class _EagerPointer extends StatelessWidget {
  final Widget child;
  final void Function(PointerDownEvent event)? onDown;
  final void Function(PointerMoveEvent event)? onMove;
  final void Function(PointerUpEvent event)? onUp;
  final void Function(PointerCancelEvent event)? onCancel;

  const _EagerPointer({
    required this.child,
    this.onDown,
    this.onMove,
    this.onUp,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              () => EagerGestureRecognizer(),
              (EagerGestureRecognizer instance) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onDown,
        onPointerMove: onMove,
        onPointerUp: onUp,
        onPointerCancel: onCancel,
        child: child,
      ),
    );
  }
}
