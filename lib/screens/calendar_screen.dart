import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/day_header.dart';
import 'package:quan_ly_lich/widgets/event_tile.dart';
import 'package:quan_ly_lich/widgets/week_timetable.dart';

enum CalendarMode { day, week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Thứ Hai đầu tuần chứa ngày d
DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

// Mọi kiểu ô trên lịch dùng chung một hình chữ nhật bo góc,
// để hiệu ứng chuyển giữa các kiểu không bị lỗi.
const BoxDecoration _cellShape = BoxDecoration(
  shape: BoxShape.rectangle,
  borderRadius: BorderRadius.all(Radius.circular(12)),
);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarMode _mode = CalendarMode.month;
  DateTime _focusedDay = _dateOnly(DateTime.now());
  DateTime _selectedDay = _dateOnly(DateTime.now());

  final ScrollController _scroll = ScrollController();
  // Mỗi tiêu đề ngày có một khóa riêng để cuộn tới đúng chỗ
  final Map<DateTime, GlobalKey> _dayKeys = {};

  CalendarFormat get _format =>
      _mode == CalendarMode.month ? CalendarFormat.month : CalendarFormat.week;

  GlobalKey _keyFor(DateTime day) =>
      _dayKeys.putIfAbsent(day, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Gom sự kiện theo ngày: { ngày: [các sự kiện của ngày đó] }
  Map<DateTime, List<Event>> _groupByDay(List<Event> events) {
    final map = <DateTime, List<Event>>{};
    for (final e in events) {
      map.putIfAbsent(_dateOnly(e.start), () => []).add(e);
    }
    return map;
  }

  // Ở chế độ Tháng: cuộn danh sách tới ngày đang chọn.
  // Nếu ngày đó trống thì cuộn tới ngày kế tiếp có sự kiện trong tháng.
  void _scrollToSelectedDay() {
    if (_mode != CalendarMode.month) return;
    final byDay = _groupByDay(context.read<AppData>().events);
    final days =
        byDay.keys
            .where(
              (d) =>
                  d.year == _selectedDay.year && d.month == _selectedDay.month,
            )
            .toList()
          ..sort();
    if (days.isEmpty) return;

    DateTime target = days.last;
    for (final d in days) {
      if (!d.isBefore(_selectedDay)) {
        target = d;
        break;
      }
    }
    final targetDay = target;

    // Chờ khung hình kế tiếp vẽ xong rồi mới cuộn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dayKeys[targetDay]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0,
        );
      }
    });
  }

  void _goToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
    _scrollToSelectedDay();
  }

  void _shiftWeek(int dir) {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month,
        _focusedDay.day + 7 * dir,
      );
      _selectedDay = _focusedDay;
    });
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = _dateOnly(picked);
      _focusedDay = _selectedDay;
    });
    _scrollToSelectedDay();
  }

  // Sau khi dời hoặc đổi giờ trên bảng tuần: lưu, báo kết quả, cho hoàn tác
  Future<void> _onEventChanged(Event old, DateTime start, DateTime end) async {
    final data = context.read<AppData>();
    final messenger = ScaffoldMessenger.of(context);
    final updated = old.copyWith(start: start, end: end);
    await data.updateEvent(updated);

    final conflicts = data.conflictsFor(updated);
    final when = '${formatDayHeader(start)} ${formatTimeRange(start, end)}';
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            conflicts.isEmpty
                ? 'Đã dời "${old.name}" sang $when'
                : 'Đã dời "${old.name}" sang $when, nhưng trùng với ${conflicts.length} sự kiện',
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => data.updateEvent(old),
          ),
        ),
      );
  }

  // Danh sách hiển thị bên dưới lịch ở chế độ Tháng và Ngày:
  // DateTime = tiêu đề ngày, Event = thẻ sự kiện, String = dòng thông báo trống
  List<Object> _buildItems(Map<DateTime, List<Event>> byDay) {
    final items = <Object>[];

    if (_mode == CalendarMode.month) {
      // Cả tháng đang xem, nhóm theo ngày
      final days =
          byDay.keys
              .where(
                (d) =>
                    d.year == _focusedDay.year && d.month == _focusedDay.month,
              )
              .toList()
            ..sort();
      for (final day in days) {
        items.add(day);
        items.addAll(byDay[day]!);
      }
      if (items.isEmpty) items.add('Tháng này chưa có sự kiện nào');
    } else {
      items.add(_selectedDay);
      final events = byDay[_selectedDay];
      if (events == null || events.isEmpty) {
        items.add('Không có sự kiện nào trong ngày này');
      } else {
        items.addAll(events);
      }
    }
    return items;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _jumpToDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'tháng ${_focusedDay.month}, ${_focusedDay.year}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SegmentedButton<CalendarMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: CalendarMode.day, label: Text('Ngày')),
              ButtonSegment(value: CalendarMode.week, label: Text('Tuần')),
              ButtonSegment(value: CalendarMode.month, label: Text('Tháng')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() {
                _mode = s.first;
                _focusedDay = _selectedDay; // bám theo ngày đang chọn
              });
              _scrollToSelectedDay();
            },
          ),
        ],
      ),
    );
  }

  // Chế độ Tuần: bảng giờ có kéo thả
  Widget _buildWeekView(AppData data) {
    final start = _weekStart(_focusedDay);
    final end = DateTime(start.year, start.month, start.day + 6);

    return Column(
      children: [
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
                  'Tuần ${_dm(start)} - ${_dm(end)}/${end.year}',
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
            weekStart: start,
            events: data.events,
            colorOf: (e) => data.labelOf(e)?.colorValue ?? Colors.grey,
            hasConflict: data.hasConflict,
            isPast: data.isPast,
            selectedDay: _selectedDay,
            onEventTap: (e) => openEventForm(context, event: e),
            onEventChanged: _onEventChanged,
            onDaySelected: (d) => setState(() => _selectedDay = d),
            onWeekShift: _shiftWeek,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final scheme = Theme.of(context).colorScheme;
    final byDay = _groupByDay(data.events);
    final items = _mode == CalendarMode.week
        ? const <Object>[]
        : _buildItems(byDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Về hôm nay',
            onPressed: _goToday,
          ),
        ],
      ),
      body: data.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                if (_mode == CalendarMode.week)
                  Expanded(child: _buildWeekView(data))
                else ...[
                  TableCalendar<Event>(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2100),
                    focusedDay: _focusedDay,
                    calendarFormat: _format,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerVisible: false,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    rowHeight: 54,
                    daysOfWeekHeight: 32,
                    selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                    eventLoader: (d) => byDay[_dateOnly(d)] ?? const [],
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = _dateOnly(selected);
                        _focusedDay = _dateOnly(focused);
                      });
                      _scrollToSelectedDay();
                    },
                    onPageChanged: (focused) {
                      setState(() {
                        _focusedDay = _dateOnly(focused);
                        _selectedDay = _focusedDay;
                      });
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                      _scrollToSelectedDay();
                    },
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      cellMargin: const EdgeInsets.all(6),
                      weekendTextStyle: TextStyle(color: Colors.grey[600]),
                      defaultDecoration: _cellShape,
                      weekendDecoration: _cellShape,
                      holidayDecoration: _cellShape,
                      outsideDecoration: _cellShape,
                      disabledDecoration: _cellShape,
                      selectedDecoration: _cellShape.copyWith(
                        color: scheme.primary,
                      ),
                      selectedTextStyle: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      todayDecoration: _cellShape.copyWith(
                        border: Border.all(color: scheme.primary, width: 1.5),
                      ),
                      todayTextStyle: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders<Event>(
                      // Hàng tên thứ: Th 2 ... Th 7, CN (Th 7 và CN màu đỏ)
                      dowBuilder: (context, day) {
                        final isWeekend = day.weekday >= 6;
                        return Center(
                          child: Text(
                            formatWeekday(day),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isWeekend ? Colors.red : null,
                            ),
                          ),
                        );
                      },
                      // Chấm màu dưới mỗi ngày: mỗi nhãn một chấm, tối đa 4
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;
                        final colors = <Color>[];
                        for (final e in events) {
                          final c = data.labelOf(e)?.colorValue ?? Colors.grey;
                          if (!colors.contains(c)) colors.add(c);
                          if (colors.length == 4) break;
                        }
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final c in colors)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final item in items)
                          if (item is DateTime)
                            KeyedSubtree(
                              key: _keyFor(item),
                              child: DayHeader(day: item),
                            )
                          else if (item is String)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  item,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          else
                            EventTile(
                              key: ValueKey('event_${(item as Event).id}'),
                              event: item,
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab', // tránh trùng tag với nút "+" của tab Sổ cái
        onPressed: () => openEventForm(context, initialDate: _selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }
}
