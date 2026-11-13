import 'package:quan_ly_lich/models/event.dart';

// Giờ làm việc mặc định dùng để gợi ý (7:00 đến 21:00).
// Sau này sẽ cho chỉnh trong Cài đặt.
const int kWorkStartMinute = 7 * 60;
const int kWorkEndMinute = 21 * 60;
const int kSlotStepMinutes = 15;

// Một khoảng thời gian trống
class FreeSlot {
  final DateTime start;
  final DateTime end;

  const FreeSlot(this.start, this.end);

  int get minutes => end.difference(start).inMinutes;
}

// Tình trạng của một ngày: có bao nhiêu việc và các khoảng trống đủ dài
class DayAvailability {
  final DateTime day;
  final int eventCount;
  final List<FreeSlot> slots;

  const DayAvailability({
    required this.day,
    required this.eventCount,
    required this.slots,
  });

  bool get entirelyFree => eventCount == 0;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Làm tròn lên bội số của 15 phút (10:07 thành 10:15)
DateTime _ceilToStep(DateTime t) {
  final extra =
      (kSlotStepMinutes - t.minute % kSlotStepMinutes) % kSlotStepMinutes;
  return DateTime(t.year, t.month, t.day, t.hour, t.minute + extra);
}

// Các khoảng trống trong giờ làm việc của một ngày.
// - minMinutes: bỏ các khoảng ngắn hơn mức này
// - notBefore: bỏ phần trước mốc này (dùng cho "hôm nay")
// - ignoreEventId: coi sự kiện này như không tồn tại (khi đang sửa chính nó)
List<FreeSlot> freeSlotsForDay(
  DateTime day,
  Iterable<Event> events, {
  int minMinutes = kSlotStepMinutes,
  int workStart = kWorkStartMinute,
  int workEnd = kWorkEndMinute,
  DateTime? notBefore,
  int? ignoreEventId,
}) {
  final d = _dateOnly(day);
  final windowStart = DateTime(d.year, d.month, d.day, 0, workStart);
  final windowEnd = DateTime(d.year, d.month, d.day, 0, workEnd);

  var cursor = windowStart;
  if (notBefore != null) {
    final nb = _ceilToStep(notBefore);
    if (nb.isAfter(cursor)) cursor = nb;
  }

  // Các sự kiện chạm vào khung giờ làm việc của ngày này, xếp theo giờ bắt đầu
  final busy = events.where((e) {
    if (ignoreEventId != null && e.id == ignoreEventId) return false;
    return e.start.isBefore(windowEnd) && e.end.isAfter(windowStart);
  }).toList()..sort((a, b) => a.start.compareTo(b.start));

  final slots = <FreeSlot>[];
  for (final e in busy) {
    // Có khoảng hở giữa mốc hiện tại và sự kiện này
    if (e.start.isAfter(cursor)) {
      final end = e.start.isBefore(windowEnd) ? e.start : windowEnd;
      if (end.difference(cursor).inMinutes >= minMinutes) {
        slots.add(FreeSlot(cursor, end));
      }
    }
    // Đẩy mốc tới cuối sự kiện (xử lý cả trường hợp các sự kiện chồng lấn)
    if (e.end.isAfter(cursor)) cursor = e.end;
  }

  // Khoảng còn lại từ mốc cuối đến hết giờ làm việc
  if (windowEnd.isAfter(cursor) &&
      windowEnd.difference(cursor).inMinutes >= minMinutes) {
    slots.add(FreeSlot(cursor, windowEnd));
  }
  return slots;
}

// Tình trạng từng ngày trong khoảng [from, to], bỏ các ngày đã qua
List<DayAvailability> availabilityForRange(
  DateTime from,
  DateTime to,
  Iterable<Event> events, {
  required int durationMinutes,
  int? ignoreEventId,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = _dateOnly(current);
  final last = _dateOnly(to);

  final result = <DayAvailability>[];
  var day = _dateOnly(from);
  while (!day.isAfter(last)) {
    if (!day.isBefore(today)) {
      final count = events.where((e) {
        if (ignoreEventId != null && e.id == ignoreEventId) return false;
        return _dateOnly(e.start) == day;
      }).length;

      final slots = freeSlotsForDay(
        day,
        events,
        minMinutes: durationMinutes,
        notBefore: day == today ? current : null,
        ignoreEventId: ignoreEventId,
      );
      result.add(DayAvailability(day: day, eventCount: count, slots: slots));
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return result;
}
