import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/reminder_planner.dart';

Event ev(int id, int day, int startHour, int endHour, {String location = ''}) =>
    Event(
      id: id,
      name: 'Sự kiện $id',
      start: DateTime(2026, 11, day, startHour),
      end: DateTime(2026, 11, day, endHour),
      location: location,
    );

void main() {
  // 7:00 sáng 17/11: giờ nhắc 6:00 hôm nay đã qua
  final now = DateTime(2026, 11, 17, 7, 0);

  group('planReminders', () {
    test('bỏ ngày không có lịch và giờ nhắc đã qua', () {
      final plan = planReminders([
        ev(1, 17, 9, 10),
        ev(2, 19, 9, 10),
      ], now: now);
      expect(plan.length, 1); // 17/11 đã qua 6:00, 18/11 trống
      expect(plan.first.id, 20261119);
      expect(plan.first.when, DateTime(2026, 11, 19, 6, 0));
    });

    test('trước 6:00 thì tính cả lịch của hôm nay', () {
      final plan = planReminders([
        ev(1, 17, 9, 10),
      ], now: DateTime(2026, 11, 17, 5, 0));
      expect(plan.length, 1);
      expect(plan.first.id, 20261117);
    });

    test('nhiều lịch cùng ngày: xếp theo giờ, tiêu đề đúng số lượng', () {
      final plan = planReminders([
        ev(1, 19, 13, 14),
        ev(2, 19, 8, 9),
      ], now: now);
      expect(plan.single.title, 'Hôm nay có 2 lịch');
      expect(plan.single.body.split('\n').first, contains('Sự kiện 2'));
      expect(plan.single.summary, contains('(+1 lịch khác)'));
    });

    test('một lịch thì tiêu đề và dòng tóm tắt gọn', () {
      final plan = planReminders([
        ev(1, 19, 8, 9, location: 'P.A101'),
      ], now: now);
      expect(plan.single.title, 'Hôm nay có 1 lịch');
      expect(plan.single.summary, contains('08:00 - 09:00'));
      expect(plan.single.body, contains(' • P.A101'));
    });

    test('đổi giờ nhắc', () {
      final plan = planReminders(
        [ev(1, 19, 9, 10)],
        now: now,
        minuteOfDay: 7 * 60 + 30,
      );
      expect(plan.single.when, DateTime(2026, 11, 19, 7, 30));
    });

    test('chỉ hẹn trong số ngày quy định', () {
      final far = Event(
        id: 9,
        name: 'Xa',
        start: DateTime(2027, 1, 5, 8),
        end: DateTime(2027, 1, 5, 9),
      );
      expect(planReminders([far], now: now), isEmpty);
    });

    test('quá nhiều lịch thì rút gọn và ghi "và N lịch nữa"', () {
      final events = [
        for (var i = 1; i <= 10; i++) ev(i, 19, 6 + (i ~/ 2), 7 + (i ~/ 2)),
      ];
      final plan = planReminders(events, now: now);
      final lines = plan.single.body.split('\n');
      expect(lines.length, 9);
      expect(lines.last, contains('và 2 lịch nữa'));
    });
  });
}
