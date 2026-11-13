import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/free_slot_service.dart';

final day = DateTime(2026, 11, 20);

Event ev(int id, int sh, int sm, int eh, int em, {int d = 20}) => Event(
  id: id,
  name: 'Sự kiện $id',
  start: DateTime(2026, 11, d, sh, sm),
  end: DateTime(2026, 11, d, eh, em),
);

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// Đổi danh sách khoảng trống thành chuỗi "07:00-09:00" cho dễ so sánh
List<String> show(List<FreeSlot> slots) =>
    slots.map((s) => '${_hm(s.start)}-${_hm(s.end)}').toList();

void main() {
  group('freeSlotsForDay', () {
    test('ngày không có sự kiện: trống cả khung giờ làm việc', () {
      expect(show(freeSlotsForDay(day, [])), ['07:00-21:00']);
    });

    test('một sự kiện chia khung giờ làm hai khoảng', () {
      final slots = freeSlotsForDay(day, [ev(1, 9, 0, 10, 0)]);
      expect(show(slots), ['07:00-09:00', '10:00-21:00']);
    });

    test('hai sự kiện liền kề tạo một khoảng bận liên tục', () {
      final slots = freeSlotsForDay(day, [
        ev(1, 9, 0, 10, 0),
        ev(2, 10, 0, 11, 0),
      ]);
      expect(show(slots), ['07:00-09:00', '11:00-21:00']);
    });

    test('các sự kiện chồng lấn nhau vẫn tính đúng', () {
      final slots = freeSlotsForDay(day, [
        ev(1, 9, 0, 11, 0),
        ev(2, 10, 0, 12, 0),
      ]);
      expect(show(slots), ['07:00-09:00', '12:00-21:00']);
    });

    test('bỏ các khoảng ngắn hơn thời lượng cần', () {
      final slots = freeSlotsForDay(day, [ev(1, 8, 0, 20, 30)], minMinutes: 45);
      // 07:00-08:00 (60 phút) giữ lại, 20:30-21:00 (30 phút) bị loại
      expect(show(slots), ['07:00-08:00']);
    });

    test('hôm nay: không gợi ý giờ đã qua, làm tròn lên 15 phút', () {
      final slots = freeSlotsForDay(
        day,
        [],
        notBefore: DateTime(2026, 11, 20, 10, 7),
      );
      expect(show(slots), ['10:15-21:00']);
    });

    test('bỏ qua chính sự kiện đang sửa', () {
      final slots = freeSlotsForDay(day, [
        ev(1, 9, 0, 10, 0),
      ], ignoreEventId: 1);
      expect(show(slots), ['07:00-21:00']);
    });

    test('sự kiện kéo dài quá giờ làm việc', () {
      final slots = freeSlotsForDay(day, [ev(1, 19, 0, 23, 0)]);
      expect(show(slots), ['07:00-19:00']);
    });
  });

  group('availabilityForRange', () {
    test('bỏ ngày đã qua, đếm việc và nhận biết ngày trống hoàn toàn', () {
      final result = availabilityForRange(
        DateTime(2026, 11, 19),
        DateTime(2026, 11, 22),
        [ev(5, 9, 0, 10, 0, d: 21)],
        durationMinutes: 60,
        now: DateTime(2026, 11, 20, 8, 0),
      );

      expect(result.map((a) => a.day.day), [20, 21, 22]);
      expect(result[1].eventCount, 1);
      expect(result[1].entirelyFree, isFalse);
      expect(result[2].entirelyFree, isTrue);
    });
  });
}
