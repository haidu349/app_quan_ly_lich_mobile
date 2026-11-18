import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/services/backup_service.dart';

void main() {
  final labels = [const EventLabel(id: 1, name: 'Đi học', color: 0xFF1E88E5)];
  final events = [
    Event(
      id: 7,
      name: 'Toán',
      start: DateTime(2026, 11, 20, 8),
      end: DateTime(2026, 11, 20, 9, 30),
      labelId: 1,
      location: 'P.301',
      note: 'Mang máy tính',
    ),
  ];

  test('xuất rồi nhập lại giữ nguyên dữ liệu', () {
    final back = decodeBackup(encodeBackup(labels, events));
    expect(back.labels.single.name, 'Đi học');
    final e = back.events.single;
    expect(e.id, 7);
    expect(e.start, DateTime(2026, 11, 20, 8));
    expect(e.labelId, 1);
    expect(e.note, 'Mang máy tính');
  });

  test('nhãn không có trong file thì sự kiện thành không nhãn', () {
    final back = decodeBackup(encodeBackup([], events));
    expect(back.events.single.labelId, isNull);
  });

  test('file sai định dạng thì báo FormatException', () {
    expect(() => decodeBackup('không phải json'), throwsFormatException);
    expect(() => decodeBackup('{"app":"khac"}'), throwsFormatException);
    expect(
      () => decodeBackup('{"app":"quan_ly_lich","version":1,"labels":1}'),
      throwsFormatException,
    );
  });
}
