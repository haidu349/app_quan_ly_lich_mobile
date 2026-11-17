import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/utils/format.dart';

const int kReminderDaysAhead = 30; // hẹn trước bao nhiêu ngày
const int kDefaultReminderMinute = 6 * 60; // 06:00

// Một thông báo sẽ được hẹn
class PlannedReminder {
  final int id; // dạng yyyyMMdd, mỗi ngày một thông báo
  final DateTime when; // thời điểm báo (giờ máy)
  final String title;
  final String summary; // dòng ngắn khi thông báo đang thu gọn
  final String body; // nội dung đầy đủ, mỗi lịch một dòng

  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.summary,
    required this.body,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _line(Event e) {
  final place = e.location.isEmpty ? '' : ' • ${e.location}';
  return '${formatTimeRange(e.start, e.end)}  ${e.name}$place';
}

// Với mỗi ngày trong [daysAhead] ngày tới có lịch và giờ báo còn ở tương lai,
// tạo một thông báo liệt kê các lịch của ngày đó.
List<PlannedReminder> planReminders(
  Iterable<Event> events, {
  required DateTime now,
  int minuteOfDay = kDefaultReminderMinute,
  int daysAhead = kReminderDaysAhead,
  int maxLines = 8,
}) {
  final byDay = <DateTime, List<Event>>{};
  for (final e in events) {
    byDay.putIfAbsent(_dateOnly(e.start), () => []).add(e);
  }

  final plan = <PlannedReminder>[];
  for (var i = 0; i < daysAhead; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final when = DateTime(day.year, day.month, day.day, 0, minuteOfDay);
    // Giờ báo đã qua thì bỏ (ví dụ 6:00 hôm nay mà bây giờ đã 7:00)
    if (!when.isAfter(now.add(const Duration(seconds: 10)))) continue;

    final list = byDay[day];
    if (list == null || list.isEmpty) continue; // ngày trống: không báo

    final sorted = [...list]..sort((a, b) => a.start.compareTo(b.start));
    final lines = [for (final e in sorted.take(maxLines)) _line(e)];
    final more = sorted.length - lines.length;
    if (more > 0) lines.add('... và $more lịch nữa');

    final first = _line(sorted.first);
    plan.add(
      PlannedReminder(
        id: day.year * 10000 + day.month * 100 + day.day,
        when: when,
        title: 'Hôm nay có ${sorted.length} lịch',
        summary: sorted.length == 1
            ? first
            : '$first (+${sorted.length - 1} lịch khác)',
        body: lines.join('\n'),
      ),
    );
  }
  return plan;
}
