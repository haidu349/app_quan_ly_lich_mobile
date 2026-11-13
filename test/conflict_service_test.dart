import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';

Event ev(int id, int startHour, int endHour, {int day = 10}) => Event(
  id: id,
  name: 'Sự kiện $id',
  start: DateTime(2026, 11, day, startHour),
  end: DateTime(2026, 11, day, endHour),
);

void main() {
  group('eventsOverlap', () {
    test('hai khoảng giờ giao nhau thì trùng', () {
      expect(eventsOverlap(ev(1, 8, 10), ev(2, 9, 11)), isTrue);
    });

    test('liền kề (kết thúc 9:00, bắt đầu 9:00) thì không trùng', () {
      expect(eventsOverlap(ev(1, 8, 9), ev(2, 9, 10)), isFalse);
    });

    test('khác ngày thì không trùng', () {
      expect(eventsOverlap(ev(1, 8, 10), ev(2, 8, 10, day: 11)), isFalse);
    });

    test('sự kiện nằm trọn trong sự kiện khác thì trùng', () {
      expect(eventsOverlap(ev(1, 8, 12), ev(2, 9, 10)), isTrue);
    });
  });

  group('findConflicts', () {
    test('bỏ qua chính nó khi sửa', () {
      final existing = [ev(1, 8, 10), ev(2, 9, 11), ev(3, 13, 14)];
      final result = findConflicts(ev(1, 8, 10), existing);
      expect(result.map((e) => e.id), [2]);
    });

    test('không có sự kiện trùng thì trả về danh sách rỗng', () {
      final existing = [ev(1, 8, 9), ev(2, 13, 14)];
      expect(findConflicts(ev(3, 10, 11), existing), isEmpty);
    });
  });

  group('findConflictingIds', () {
    test('trả về đúng các sự kiện đang trùng nhau', () {
      final events = [ev(1, 8, 10), ev(2, 9, 11), ev(3, 13, 14), ev(4, 10, 12)];
      // 1 trùng 2, 2 trùng 4, 1 và 4 chỉ liền kề, 3 đứng riêng
      expect(findConflictingIds(events), {1, 2, 4});
    });
  });
}
