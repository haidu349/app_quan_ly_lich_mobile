import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/services/import_parser.dart' show normalizeText;

// Kiểu dời hàng loạt
enum BulkMode {
  shift, // dời cả chuỗi lùi/tới N ngày, giữ nguyên thứ và giờ
  makeUp, // dạy bù: xếp các buổi bị nghỉ vào cuối chuỗi, đúng thứ và giờ cũ
}

// Kết quả dời một buổi
class BulkMove {
  final Event original;
  final Event moved;

  // Lịch khác đang trùng với giờ mới (không tính các buổi cùng đợt dời
  // ở vị trí cũ, vì chúng đã đi chỗ khác)
  final List<Event> conflicts;

  const BulkMove({
    required this.original,
    required this.moved,
    required this.conflicts,
  });

  bool get hasConflict => conflicts.isNotEmpty;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Cộng [days] ngày theo lịch rồi giữ nguyên giờ:phút. Không dùng
// add(Duration) vì phép đó cộng theo giờ chứ không theo ngày lịch.
DateTime _addDays(DateTime t, int days) =>
    DateTime(t.year, t.month, t.day + days, t.hour, t.minute);

// Các buổi bắt đầu trong khoảng ngày [from, to] (gồm cả hai đầu).
// - where: bộ lọc thêm (ví dụ theo nhãn)
// - now: nếu có thì bỏ các buổi đã kết thúc
List<Event> selectInRange(
  Iterable<Event> events,
  DateTime from,
  DateTime to, {
  bool Function(Event)? where,
  DateTime? now,
}) {
  final first = _dateOnly(from);
  final last = _dateOnly(to);
  final result = events.where((e) {
    if (e.id == null) return false;
    final d = _dateOnly(e.start);
    if (d.isBefore(first) || d.isAfter(last)) return false;
    if (now != null && !e.end.isAfter(now)) return false;
    return where == null || where(e);
  }).toList();
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

// Dời cả chuỗi [selected] đi [days] ngày (âm = lùi về trước).
// [all] là toàn bộ lịch hiện có, dùng để báo trùng giờ.
List<BulkMove> planShift(
  List<Event> selected,
  Iterable<Event> all, {
  required int days,
}) {
  final ordered = [...selected]..sort((a, b) => a.start.compareTo(b.start));
  final moved = [
    for (final e in ordered)
      e.copyWith(start: _addDays(e.start, days), end: _addDays(e.end, days)),
  ];
  return _withConflicts(ordered, moved, all);
}

// Dạy bù: mỗi buổi trong [selected] được xếp lại đúng thứ và giờ cũ, ở sau
// buổi cuối cùng của cùng chuỗi (cùng tên, cùng nhãn) nằm ngoài [selected].
// Gặp giờ đã có lịch thì nhích thêm một tuần.
List<BulkMove> planMakeUp(List<Event> selected, Iterable<Event> all) {
  final ordered = [...selected]..sort((a, b) => a.start.compareTo(b.start));
  final selectedIds = {for (final e in ordered) e.id};
  final others = all.where((e) => !selectedIds.contains(e.id)).toList();

  String keyOf(Event e) => '${normalizeText(e.name)}|${e.labelId}';

  final cursor = <String, DateTime>{}; // ngày cuối đã dùng của từng chuỗi
  final placed = <Event>[];
  final movedById = <int?, Event>{};

  for (final e in ordered) {
    final key = keyOf(e);
    var from = cursor[key];
    if (from == null) {
      // Mốc bắt đầu: ngày muộn nhất trong chuỗi (ngoài đợt nghỉ) và các buổi
      // cùng chuỗi trong đợt nghỉ, để buổi bù không rơi vào giữa chuỗi.
      var last = _dateOnly(ordered.last.start);
      for (final o in others) {
        if (keyOf(o) != key) continue;
        final d = _dateOnly(o.start);
        if (d.isAfter(last)) last = d;
      }
      from = last;
    }

    // Ngày đầu tiên sau [from] có cùng thứ với buổi gốc
    var date = _dateOnly(from).add(const Duration(days: 1));
    date = DateTime(
      date.year,
      date.month,
      date.day + (e.start.weekday - date.weekday + 7) % 7,
    );

    final span = e.end.difference(e.start);
    Event build(DateTime day) {
      final s = DateTime(
        day.year,
        day.month,
        day.day,
        e.start.hour,
        e.start.minute,
      );
      return e.copyWith(start: s, end: s.add(span));
    }

    var candidate = build(date);
    // Giới hạn số vòng để không bao giờ lặp vô hạn
    for (var i = 0; i < 520; i++) {
      final pool = [...others, ...placed];
      if (findConflicts(candidate, pool).isEmpty) break;
      date = DateTime(date.year, date.month, date.day + 7);
      candidate = build(date);
    }

    placed.add(candidate);
    movedById[e.id] = candidate;
    cursor[key] = _dateOnly(candidate.start);
  }

  final moved = [for (final e in ordered) movedById[e.id]!];
  return _withConflicts(ordered, moved, all);
}

// Thay giờ mới của một số buổi bằng giờ người dùng tự chọn (khóa = id buổi
// gốc), rồi tính lại trùng giờ cho cả đợt.
List<BulkMove> overrideMoves(
  List<BulkMove> plan,
  Map<int, ({DateTime start, DateTime end})> overrides,
  Iterable<Event> all,
) {
  final originals = [for (final m in plan) m.original];
  final moved = [
    for (final m in plan)
      if (overrides[m.original.id] case final o?)
        m.moved.copyWith(start: o.start, end: o.end)
      else
        m.moved,
  ];
  return _withConflicts(originals, moved, all);
}

List<BulkMove> _withConflicts(
  List<Event> originals,
  List<Event> moved,
  Iterable<Event> all,
) {
  final ids = {for (final e in originals) e.id};
  final pool = [...all.where((e) => !ids.contains(e.id)), ...moved];
  return [
    for (var i = 0; i < originals.length; i++)
      BulkMove(
        original: originals[i],
        moved: moved[i],
        conflicts: findConflicts(moved[i], pool),
      ),
  ];
}
