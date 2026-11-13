import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/day_header.dart';
import 'package:quan_ly_lich/widgets/event_tile.dart';

enum CalendarMode { day, week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Thứ Hai đầu tuần chứa ngày d
DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

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

  // Danh sách hiển thị bên dưới lịch: DateTime = tiêu đề ngày,
  // Event = thẻ sự kiện, String = dòng thông báo trống
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
    } else if (_mode == CalendarMode.week) {
      final start = _weekStart(_focusedDay);
      for (var i = 0; i < 7; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        final events = byDay[day];
        if (events == null || events.isEmpty) continue;
        items.add(day);
        items.addAll(events);
      }
      if (items.isEmpty) items.add('Tuần này chưa có sự kiện nào');
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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final scheme = Theme.of(context).colorScheme;
    final byDay = _groupByDay(data.events);
    final items = _buildItems(byDay);

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
                    selectedDecoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selectedTextStyle: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    todayDecoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
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
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab', // tránh trùng tag với nút "+" của tab Sổ cái
        onPressed: () => openEventForm(context, initialDate: _selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }
}
