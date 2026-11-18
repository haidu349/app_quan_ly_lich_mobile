import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/bulk_reschedule_screen.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/calendar_timetable.dart';

enum CalendarMode { day, week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
  DateTime _selectedDay = _dateOnly(DateTime.now());
  DateTime _focusedDay = _dateOnly(DateTime.now()); // tháng đang hiện trên lưới
  bool _selecting = false; // đang chọn một khối trên bảng giờ

  // Nhóm sự kiện theo ngày chỉ tính lại khi danh sách sự kiện thực sự đổi.
  List<Event>? _groupedSource;
  Map<DateTime, List<Event>> _groupedByDay = const {};

  // Tuần và Tháng dùng chung một bảng; Ngày dùng bảng riêng
  bool _sameGroup(CalendarMode a, CalendarMode b) =>
      (a == CalendarMode.day) == (b == CalendarMode.day);

  void _setMode(CalendarMode m) {
    setState(() {
      if (!_sameGroup(_mode, m)) _selecting = false;
      _mode = m;
      _focusedDay = _selectedDay;
    });
  }

  void _goToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
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
  }

  // Gom sự kiện theo ngày (dùng cho chấm màu trên lưới tháng)
  Map<DateTime, List<Event>> _groupByDay(List<Event> events) {
    if (identical(_groupedSource, events)) return _groupedByDay;
    final map = <DateTime, List<Event>>{};
    for (final e in events) {
      map.putIfAbsent(_dateOnly(e.start), () => []).add(e);
    }
    _groupedSource = events;
    _groupedByDay = map;
    return map;
  }

  String _headerTitle() {
    switch (_mode) {
      case CalendarMode.day:
        return formatDayHeader(_selectedDay);
      case CalendarMode.week:
        final monday = _selectedDay.subtract(
          Duration(days: _selectedDay.weekday - 1),
        );
        final sunday = monday.add(const Duration(days: 6));
        return 'Tuần ${monday.day}/${monday.month} - ${sunday.day}/${sunday.month}';
      case CalendarMode.month:
        return 'tháng ${_selectedDay.month}, ${_selectedDay.year}';
    }
  }

  // Sau khi dời hoặc đổi giờ trên bảng: chỉ lưu, không hiện thông báo
  Future<void> _onEventChanged(Event old, DateTime start, DateTime end) {
    return context.read<AppData>().updateEvent(
      old.copyWith(start: start, end: end),
    );
  }

  Future<void> _deleteEvent(Event e) async {
    final ok = await confirmDeleteEvent(context, e);
    if (ok && mounted) deleteEventAndNotify(context, e);
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
                          _headerTitle(),
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
            onSelectionChanged: (s) => _setMode(s.first),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(AppData data, Map<DateTime, List<Event>> byDay) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TableCalendar<Event>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerVisible: false,
          availableGestures: AvailableGestures.horizontalSwipe,
          rowHeight: 42,
          daysOfWeekHeight: 28,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          eventLoader: (d) => byDay[_dateOnly(d)] ?? const [],
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = _dateOnly(selected);
              _focusedDay = _dateOnly(focused);
            });
          },
          onPageChanged: (focused) {
            // Chỉ khi người dùng vuốt lưới sang tháng khác mới đổi ngày đang chọn
            // (đổi tháng do bảng bên dưới vuốt tuần thì giữ nguyên)
            if (focused.year == _selectedDay.year &&
                focused.month == _selectedDay.month) {
              _focusedDay = _dateOnly(focused);
              return;
            }
            setState(() {
              _focusedDay = _dateOnly(focused);
              _selectedDay = _focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: const EdgeInsets.all(4),
            weekendTextStyle: TextStyle(color: Colors.grey[600]),
            defaultDecoration: _cellShape,
            weekendDecoration: _cellShape,
            holidayDecoration: _cellShape,
            outsideDecoration: _cellShape,
            disabledDecoration: _cellShape,
            selectedDecoration: _cellShape.copyWith(color: scheme.primary),
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
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final byDay = _groupByDay(data.events);
    final isDay = _mode == CalendarMode.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_repeat),
            tooltip: 'Dời lịch hàng loạt',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BulkRescheduleScreen()),
            ),
          ),
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
                // Lưới tháng trượt xuống, đẩy bảng giờ xuống dưới
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: _mode == CalendarMode.month
                      ? _buildMonthGrid(data, byDay)
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: CalendarTimetable(
                    key: ValueKey(isDay ? 'timetable_day' : 'timetable_week'),
                    mode: isDay ? TimetableMode.day : TimetableMode.week,
                    anchorDay: _selectedDay,
                    events: data.events,
                    colorOf: (e) => data.labelOf(e)?.colorValue ?? Colors.grey,
                    hasConflict: data.hasConflict,
                    isPast: data.isPast,
                    onAnchorChanged: (d) => setState(() {
                      _selectedDay = d;
                      _focusedDay = d;
                    }),
                    onDayTap: (d) => setState(() {
                      _selectedDay = d;
                      _focusedDay = d;
                    }),
                    onEventChanged: _onEventChanged,
                    onOpenEvent: (e) => openEventForm(context, event: e),
                    onCreate: (s, e) =>
                        openEventForm(context, initialStart: s, initialEnd: e),
                    onDeleteEvent: _deleteEvent,
                    onSelectionChanged: (v) => setState(() => _selecting = v),
                  ),
                ),
              ],
            ),
      // Đang chọn khối thì ẩn nút "+" để không đè lên thanh hành động
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              heroTag: 'calendar_fab', // tránh trùng tag với nút "+" của Sổ cái
              onPressed: () =>
                  openEventForm(context, initialDate: _selectedDay),
              child: const Icon(Icons.add),
            ),
    );
  }
}
