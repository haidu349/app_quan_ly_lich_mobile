import 'package:quan_ly_lich/models/event.dart';

// Một sự kiện đã được xếp vào cột con trong ngày
class PlacedEvent {
  final Event event;
  final int column; // cột con của sự kiện (từ 0)
  final int columns; // tổng số cột con của cụm trùng giờ chứa sự kiện

  const PlacedEvent(this.event, this.column, this.columns);
}

// Xếp các sự kiện của MỘT ngày. Các sự kiện trùng giờ nhau (dây chuyền) tạo thành
// một cụm và được chia đều bề rộng; sự kiện không trùng ai thì chiếm đủ bề rộng.
List<PlacedEvent> layoutDay(Iterable<Event> dayEvents) {
  final sorted = [...dayEvents]
    ..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : b.end.compareTo(a.end);
    });

  final out = <PlacedEvent>[];
  var cluster = <Event>[];
  DateTime? clusterEnd;

  void flush() {
    if (cluster.isEmpty) return;
    final colEnds = <DateTime>[]; // giờ kết thúc hiện tại của từng cột con
    final cols = <int>[];
    for (final e in cluster) {
      var c = 0;
      while (c < colEnds.length && e.start.isBefore(colEnds[c])) {
        c++;
      }
      if (c == colEnds.length) {
        colEnds.add(e.end);
      } else {
        colEnds[c] = e.end;
      }
      cols.add(c);
    }
    for (var i = 0; i < cluster.length; i++) {
      out.add(PlacedEvent(cluster[i], cols[i], colEnds.length));
    }
    cluster = [];
    clusterEnd = null;
  }

  for (final e in sorted) {
    // Sự kiện bắt đầu sau khi cả cụm đã kết thúc: sang cụm mới
    if (clusterEnd != null && !e.start.isBefore(clusterEnd!)) flush();
    cluster.add(e);
    if (clusterEnd == null || e.end.isAfter(clusterEnd!)) clusterEnd = e.end;
  }
  flush();
  return out;
}

// Làm tròn số phút về bội số của [step] (mặc định 15 phút)
int snapMinute(double minute, {int step = 15}) =>
    (minute / step).round() * step;
