import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/stats_service.dart';

Event ev(int id, int? labelId, int day, int sh, int sm, int eh, int em) =>
    Event(
      id: id,
      name: 'Sự kiện $id',
      start: DateTime(2026, 11, day, sh, sm),
      end: DateTime(2026, 11, day, eh, em),
      labelId: labelId,
    );

void main() {
  final events = [
    ev(1, 1, 16, 8, 0, 10, 0), // nhãn 1, 120 phút, ngày 16
    ev(2, 1, 16, 13, 0, 14, 0), // nhãn 1, 60 phút, ngày 16
    ev(3, 2, 17, 9, 0, 10, 0), // nhãn 2, 60 phút, ngày 17
    ev(4, null, 18, 9, 0, 9, 30), // không nhãn, 30 phút, ngày 18
    ev(5, 1, 25, 8, 0, 9, 0), // ngoài tuần đang xét
  ];

  group('computeStats', () {
    final stats = computeStats(
      events,
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 22),
    );

    test('một tuần có 7 ngày', () {
      expect(stats.days.length, 7);
    });

    test('cộng đúng số việc và số phút từng ngày', () {
      expect(stats.days[0].count, 2);
      expect(stats.days[0].minutes, 180);
      expect(stats.days[1].count, 1);
      expect(stats.days[1].minutes, 60);
      expect(stats.days[6].count, 0);
    });

    test('bỏ qua sự kiện ngoài kỳ', () {
      expect(stats.totalCount, 4);
      expect(stats.totalMinutes, 270);
    });

    test('cộng theo nhãn, nhãn null là "không nhãn"', () {
      expect(stats.byLabel[1]!.minutes, 180);
      expect(stats.byLabel[1]!.count, 2);
      expect(stats.byLabel[2]!.minutes, 60);
      expect(stats.byLabel[null]!.minutes, 30);
      expect(stats.byLabel[3], isNull);
    });

    test('tìm ngày bận nhất', () {
      expect(stats.busiestDay!.day.day, 16);
    });
  });

  group('trường hợp đặc biệt', () {
    test('kỳ không có sự kiện: tổng bằng 0 và không có ngày bận nhất', () {
      final stats = computeStats(
        [],
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 7),
      );
      expect(stats.totalCount, 0);
      expect(stats.totalMinutes, 0);
      expect(stats.busiestDay, isNull);
      expect(stats.byLabel, isEmpty);
    });

    test('một tháng 11 có 30 ngày', () {
      final stats = computeStats(
        events,
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30),
      );
      expect(stats.days.length, 30);
      expect(stats.totalCount, 5);
    });
  });
}
