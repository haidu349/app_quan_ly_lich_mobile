import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/services/timetable_pages.dart';

void main() {
  group('dayNumber và dateOfDayNumber', () {
    test('đổi qua lại cho cùng một ngày', () {
      final d = DateTime(2026, 11, 18);
      expect(dateOfDayNumber(dayNumber(d)), d);
    });

    test('ngày thứ Hai làm mốc có số 0 và các thứ Hai chia hết cho 7', () {
      expect(dayNumber(DateTime(2000, 1, 3)), 0);
      expect(dayNumber(DateTime(2026, 11, 16)) % 7, 0); // 16/11/2026 là thứ Hai
    });
  });

  group('pageOfDay', () {
    test('theo tuần: thứ Hai đến Chủ nhật cùng một trang', () {
      final mon = pageOfDay(DateTime(2026, 11, 16), week: true);
      final sun = pageOfDay(DateTime(2026, 11, 22), week: true);
      final nextMon = pageOfDay(DateTime(2026, 11, 23), week: true);
      expect(sun, mon);
      expect(nextMon, mon + 1);
    });

    test('theo ngày: mỗi ngày một trang', () {
      final a = pageOfDay(DateTime(2026, 11, 18), week: false);
      final b = pageOfDay(DateTime(2026, 11, 19), week: false);
      expect(b, a + 1);
    });

    test('trang đầu của một tuần trỏ về thứ Hai', () {
      final wed = DateTime(2026, 11, 18);
      final page = pageOfDay(wed, week: true);
      final first = dateOfDayNumber(firstDayNumberOfPage(page, week: true));
      expect(first, DateTime(2026, 11, 16));
    });

    test('ngày trước mốc được kẹp về trang 0', () {
      expect(pageOfDay(DateTime(1999, 5, 1), week: true), 0);
      expect(pageOfDay(DateTime(1999, 5, 1), week: false), 0);
    });
  });

  group('clampInt', () {
    test('kẹp vào khoảng', () {
      expect(clampInt(5, 0, 10), 5);
      expect(clampInt(-3, 0, 10), 0);
      expect(clampInt(99, 0, 10), 10);
    });

    test('khoảng ngược thì trả về cận dưới, không báo lỗi', () {
      expect(clampInt(5, 10, 2), 10);
    });
  });
}
