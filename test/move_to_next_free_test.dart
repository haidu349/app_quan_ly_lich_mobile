import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';

Event ev(int id, int s, int e) => Event(
  id: id,
  name: 'Sự kiện $id',
  start: DateTime(2026, 11, 10, s),
  end: DateTime(2026, 11, 10, e),
);

void main() {
  test('moveToNextFree dời tới ngay sau lịch trùng, giữ độ dài', () {
    final m = moveToNextFree(ev(1, 8, 10), [ev(2, 9, 11)]);
    expect(m.start, DateTime(2026, 11, 10, 11));
    expect(m.end, DateTime(2026, 11, 10, 13));
  });

  test('moveToNextFree nhảy qua nhiều lịch liên tiếp', () {
    final m = moveToNextFree(ev(1, 8, 9), [ev(2, 8, 10), ev(3, 10, 12)]);
    expect(m.start, DateTime(2026, 11, 10, 12));
  });

  test('moveToNextFree không trùng thì giữ nguyên', () {
    final e = ev(1, 8, 9);
    expect(moveToNextFree(e, [ev(2, 9, 10)]).start, e.start);
  });
}
