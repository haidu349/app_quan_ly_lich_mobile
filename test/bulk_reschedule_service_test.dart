import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/bulk_reschedule_service.dart';

// 2/11/2026 là thứ Hai
Event ev(
  int id,
  DateTime start, {
  String name = 'Lớp A',
  int? labelId,
  int hours = 2,
}) => Event(
  id: id,
  name: name,
  start: start,
  end: start.add(Duration(hours: hours)),
  labelId: labelId,
);

DateTime d(int month, int day, [int hour = 8, int minute = 0]) =>
    DateTime(2026, month, day, hour, minute);

void main() {
  group('selectInRange', () {
    final events = [
      ev(1, d(11, 1)),
      ev(2, d(11, 2)),
      ev(3, d(11, 10, 23)),
      ev(4, d(11, 11)),
      ev(5, d(11, 20), labelId: 7),
    ];

    test('lấy cả hai đầu khoảng ngày, kể cả buổi muộn trong ngày cuối', () {
      final r = selectInRange(events, d(11, 2), d(11, 10));
      expect(r.map((e) => e.id), [2, 3]);
    });

    test('kết quả xếp theo giờ bắt đầu dù đầu vào lộn xộn', () {
      final r = selectInRange(events.reversed, d(11, 1), d(11, 30));
      expect(r.map((e) => e.id), [1, 2, 3, 4, 5]);
    });

    test('bỏ buổi đã kết thúc khi có now', () {
      final r = selectInRange(events, d(11, 1), d(11, 30), now: d(11, 10, 12));
      expect(r.map((e) => e.id), [3, 4, 5]);
    });

    test('lọc thêm theo điều kiện (nhãn)', () {
      final r = selectInRange(
        events,
        d(11, 1),
        d(11, 30),
        where: (e) => e.labelId == 7,
      );
      expect(r.map((e) => e.id), [5]);
    });

    test('bỏ sự kiện chưa có id', () {
      final r = selectInRange(
        [Event(name: 'x', start: d(11, 2), end: d(11, 2, 9))],
        d(11, 1),
        d(11, 30),
      );
      expect(r, isEmpty);
    });
  });

  group('planShift', () {
    test('lùi 7 ngày, giữ giờ, id và nhãn', () {
      final a = ev(1, d(11, 2, 8, 15), labelId: 3);
      final r = planShift([a], [a], days: 7);
      expect(r.single.moved.id, 1);
      expect(r.single.moved.labelId, 3);
      expect(r.single.moved.start, d(11, 9, 8, 15));
      expect(r.single.moved.end, d(11, 9, 10, 15));
      expect(r.single.original, same(a));
    });

    test('qua ranh giới tháng và năm', () {
      final a = ev(1, DateTime(2026, 12, 28, 19));
      final r = planShift([a], [a], days: 7);
      expect(r.single.moved.start, DateTime(2027, 1, 4, 19));
    });

    test('số ngày âm là dời về trước', () {
      final a = ev(1, d(11, 10));
      final r = planShift([a], [a], days: -7);
      expect(r.single.moved.start, d(11, 3));
    });

    test(
      'cả chuỗi lùi 1 tuần: không trùng nhau dù rơi vào chỗ cũ của nhau',
      () {
        final a = ev(1, d(11, 2));
        final b = ev(2, d(11, 9));
        final c = ev(3, d(11, 16));
        final r = planShift([a, b, c], [a, b, c], days: 7);
        expect(r.map((m) => m.moved.start), [d(11, 9), d(11, 16), d(11, 23)]);
        expect(r.any((m) => m.hasConflict), isFalse);
      },
    );

    test('báo trùng với lịch khác không thuộc đợt dời', () {
      final a = ev(1, d(11, 2));
      final other = ev(9, d(11, 9, 9), name: 'Họp');
      final r = planShift([a], [a, other], days: 7);
      expect(r.single.conflicts.map((e) => e.id), [9]);
    });

    test('kết quả xếp theo giờ dù đầu vào lộn xộn', () {
      final a = ev(1, d(11, 2));
      final b = ev(2, d(11, 9));
      final r = planShift([b, a], [a, b], days: 14);
      expect(r.map((m) => m.original.id), [1, 2]);
    });
  });

  group('overrideMoves', () {
    test('thay giờ một buổi và tính lại trùng giờ', () {
      final a = ev(1, d(11, 2));
      final b = ev(2, d(11, 9));
      final other = ev(9, d(11, 20, 9), name: 'Họp');
      final plan = planShift([a, b], [a, b, other], days: 7);
      final r = overrideMoves(
        plan,
        {1: (start: d(11, 20, 8), end: d(11, 20, 10))},
        [a, b, other],
      );
      expect(r[0].moved.start, d(11, 20, 8));
      expect(r[0].conflicts.map((e) => e.id), [9]);
      expect(
        r[1].moved.start,
        d(11, 16),
      ); // buổi không chỉnh giữ nguyên kết quả
      expect(r[1].hasConflict, isFalse);
    });
  });

  group('planMakeUp', () {
    // Thứ Hai hằng tuần 8:00-10:00: 2, 9, 16, 23, 30/11
    final mondays = [for (var i = 0; i < 5; i++) ev(i + 1, d(11, 2 + 7 * i))];

    test('buổi nghỉ được xếp vào sau buổi cuối của chuỗi, đúng thứ và giờ', () {
      final r = planMakeUp([mondays[1], mondays[2]], mondays);
      expect(r.map((m) => m.original.id), [2, 3]);
      expect(r.map((m) => m.moved.start), [d(12, 7), d(12, 14)]);
      expect(r.map((m) => m.moved.end), [d(12, 7, 10), d(12, 14, 10)]);
      expect(r.any((m) => m.hasConflict), isFalse);
    });

    test('nghỉ cả đoạn cuối chuỗi: bù sau ngày cuối của đợt nghỉ', () {
      final r = planMakeUp([mondays[3], mondays[4]], mondays);
      expect(r.map((m) => m.moved.start), [d(12, 7), d(12, 14)]);
    });

    test('gặp giờ đã có lịch khác thì nhích thêm một tuần', () {
      final busy = ev(20, d(12, 7), name: 'Họp');
      final r = planMakeUp([mondays[1], mondays[2]], [...mondays, busy]);
      expect(r.map((m) => m.moved.start), [d(12, 14), d(12, 21)]);
      expect(r.any((m) => m.hasConflict), isFalse);
    });

    test(
      'hai chuỗi khác tên được xếp riêng, tên so sánh không phân biệt dấu',
      () {
        final b1 = ev(11, d(11, 3), name: 'lop b');
        final b2 = ev(12, d(11, 10), name: 'Lớp B');
        final b3 = ev(13, d(11, 17), name: 'LỚP B');
        final all = [...mondays, b1, b2, b3];
        final r = planMakeUp([mondays[1], b2], all);
        final byId = {for (final m in r) m.original.id: m.moved.start};
        expect(byId[2], d(12, 7)); // Lớp A: sau thứ Hai 30/11
        expect(byId[12], d(11, 24)); // Lớp B: sau thứ Ba 17/11 (cùng thứ Ba)
      },
    );

    test('giữ đúng thứ khi một chuỗi có nhiều thứ trong tuần', () {
      final mon = ev(1, d(11, 9));
      final thu = ev(2, d(11, 12));
      final r = planMakeUp([mon, thu], [mon, thu]);
      expect(r[0].moved.start.weekday, DateTime.monday);
      expect(r[1].moved.start.weekday, DateTime.thursday);
      expect(r[0].moved.start.isBefore(r[1].moved.start), isTrue);
    });

    test('buổi bù không nằm trước hoặc trong đợt nghỉ', () {
      final r = planMakeUp([mondays[1], mondays[2]], mondays);
      final lastBreak = mondays[2].start;
      for (final m in r) {
        expect(m.moved.start.isAfter(lastBreak), isTrue);
      }
    });
  });
}
