import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/timetable_layout.dart';

Event ev(int id, int sh, int sm, int eh, int em) => Event(
  id: id,
  name: 'E$id',
  start: DateTime(2026, 11, 20, sh, sm),
  end: DateTime(2026, 11, 20, eh, em),
);

// Gom kết quả thành { id: (cột, tổng số cột) } cho dễ so sánh
Map<int?, (int, int)> place(List<Event> events) => {
  for (final p in layoutDay(events)) p.event.id: (p.column, p.columns),
};

void main() {
  group('layoutDay', () {
    test('không trùng giờ: mỗi sự kiện chiếm đủ bề rộng', () {
      final m = place([ev(1, 8, 0, 9, 0), ev(2, 10, 0, 11, 0)]);
      expect(m[1], (0, 1));
      expect(m[2], (0, 1));
    });

    test('hai sự kiện trùng giờ: xếp cạnh nhau', () {
      final m = place([ev(1, 8, 0, 10, 0), ev(2, 9, 0, 11, 0)]);
      expect(m[1], (0, 2));
      expect(m[2], (1, 2));
    });

    test('trùng dây chuyền: dùng lại cột khi đã trống', () {
      final m = place([
        ev(1, 8, 0, 10, 0),
        ev(2, 9, 0, 11, 0),
        ev(3, 10, 0, 12, 0), // bắt đầu đúng lúc sự kiện 1 kết thúc
      ]);
      expect(m[1], (0, 2));
      expect(m[2], (1, 2));
      expect(m[3], (0, 2));
    });

    test('các cụm tách biệt không ảnh hưởng nhau', () {
      final m = place([
        ev(1, 8, 0, 9, 0),
        ev(2, 8, 30, 9, 30),
        ev(3, 13, 0, 14, 0),
      ]);
      expect(m[1], (0, 2));
      expect(m[2], (1, 2));
      expect(m[3], (0, 1));
    });

    test('danh sách rỗng', () {
      expect(layoutDay([]), isEmpty);
    });
  });

  group('snapMinute', () {
    test('làm tròn về bội số của 15 phút', () {
      expect(snapMinute(7), 0);
      expect(snapMinute(8), 15);
      expect(snapMinute(22.4), 15);
      expect(snapMinute(22.5), 30);
      expect(snapMinute(38), 45);
    });
  });
}
