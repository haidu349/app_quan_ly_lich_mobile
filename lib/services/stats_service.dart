import 'package:quan_ly_lich/models/event.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Số liệu của một ngày, tách theo nhãn (khóa null = không nhãn)
class DayStat {
  final DateTime day;
  final Map<int?, int> minutesByLabel;
  final Map<int?, int> countByLabel;

  const DayStat({
    required this.day,
    required this.minutesByLabel,
    required this.countByLabel,
  });

  int get minutes => minutesByLabel.values.fold(0, (a, b) => a + b);
  int get count => countByLabel.values.fold(0, (a, b) => a + b);
}

// Tổng của một nhãn trong cả kỳ
class LabelTotal {
  final int minutes;
  final int count;

  const LabelTotal(this.minutes, this.count);
}

// Số liệu của cả kỳ (một tuần hoặc một tháng)
class PeriodStats {
  final List<DayStat> days;
  final Map<int?, LabelTotal> byLabel;

  const PeriodStats({required this.days, required this.byLabel});

  int get totalMinutes => days.fold(0, (s, d) => s + d.minutes);
  int get totalCount => days.fold(0, (s, d) => s + d.count);

  // Ngày có tổng thời lượng lớn nhất (null nếu cả kỳ không có việc)
  DayStat? get busiestDay {
    DayStat? best;
    for (final d in days) {
      if (d.minutes == 0) continue;
      if (best == null || d.minutes > best.minutes) best = d;
    }
    return best;
  }
}

// Tính thống kê cho các ngày từ [from] đến [to] (gồm cả hai đầu).
// Mỗi sự kiện được tính vào ngày bắt đầu của nó.
PeriodStats computeStats(Iterable<Event> events, DateTime from, DateTime to) {
  final first = _dateOnly(from);
  final last = _dateOnly(to);

  final dayList = <DateTime>[];
  for (
    var d = first;
    !d.isAfter(last);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    dayList.add(d);
  }

  final minutes = {for (final d in dayList) d: <int?, int>{}};
  final counts = {for (final d in dayList) d: <int?, int>{}};

  for (final e in events) {
    final day = _dateOnly(e.start);
    final m = minutes[day];
    if (m == null) continue; // ngoài kỳ đang xem
    final mins = e.end.difference(e.start).inMinutes;
    m[e.labelId] = (m[e.labelId] ?? 0) + mins;
    final c = counts[day]!;
    c[e.labelId] = (c[e.labelId] ?? 0) + 1;
  }

  final totalMinutes = <int?, int>{};
  final totalCounts = <int?, int>{};
  final days = <DayStat>[];
  for (final d in dayList) {
    final m = minutes[d]!;
    final c = counts[d]!;
    m.forEach((id, v) => totalMinutes[id] = (totalMinutes[id] ?? 0) + v);
    c.forEach((id, v) => totalCounts[id] = (totalCounts[id] ?? 0) + v);
    days.add(DayStat(day: d, minutesByLabel: m, countByLabel: c));
  }

  return PeriodStats(
    days: days,
    byLabel: {
      for (final id in totalCounts.keys)
        id: LabelTotal(totalMinutes[id] ?? 0, totalCounts[id]!),
    },
  );
}
