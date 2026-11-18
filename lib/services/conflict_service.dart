import 'package:quan_ly_lich/models/event.dart';

// Hai khoảng giờ giao nhau (liền kề như 8:00-9:00 và 9:00-10:00 không tính là trùng)
bool eventsOverlap(Event a, Event b) =>
    a.start.isBefore(b.end) && b.start.isBefore(a.end);

// Các sự kiện trong [existing] đang trùng với [candidate].
// Bỏ qua chính nó (cùng id) để khi sửa không tự trùng với bản cũ của mình.
List<Event> findConflicts(Event candidate, Iterable<Event> existing) {
  final result = existing.where((e) {
    if (candidate.id != null && e.id == candidate.id) return false;
    return eventsOverlap(candidate, e);
  }).toList();
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

// Dời [e] (giữ độ dài) tới ngay sau lịch trùng gần nhất, lặp lại tới khi hết trùng.
// shortcut: có thể đẩy qua nửa đêm sang ngày sau, nâng cấp nếu cần giới hạn trong ngày.
Event moveToNextFree(Event e, Iterable<Event> others) {
  final span = e.end.difference(e.start);
  var cur = e;
  for (var i = 0; i < 200; i++) {
    final c = findConflicts(cur, others);
    if (c.isEmpty) break;
    final end = c.map((x) => x.end).reduce((a, b) => a.isAfter(b) ? a : b);
    cur = cur.copyWith(start: end, end: end.add(span));
  }
  return cur;
}

// Tập id của mọi sự kiện đang trùng với ít nhất một sự kiện khác
Set<int> findConflictingIds(Iterable<Event> events) {
  final sorted = events.where((e) => e.id != null).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final ids = <int>{};
  for (var i = 0; i < sorted.length; i++) {
    for (var j = i + 1; j < sorted.length; j++) {
      // đã sắp theo giờ bắt đầu: gặp sự kiện bắt đầu sau khi [i] kết thúc thì dừng
      if (!sorted[j].start.isBefore(sorted[i].end)) break;
      ids.add(sorted[i].id!);
      ids.add(sorted[j].id!);
    }
  }
  return ids;
}
