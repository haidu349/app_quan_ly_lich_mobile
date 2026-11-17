import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/import_parser.dart';

void main() {
  group('normalizeText', () {
    test('bỏ dấu, chữ thường, gộp khoảng trắng', () {
      expect(normalizeText('  Tên   Sự Kiện '), 'ten su kien');
      expect(normalizeText('ĐI HỌC'), 'di hoc');
      expect(normalizeText('Giờ kết thúc'), 'gio ket thuc');
    });
  });

  group('parseImportRows: file không có cột giờ', () {
    final result = parseImportRows([
      ['STT', 'Tên sự kiện', 'Ngày tổ chức', 'Tên người tổ chức'],
      [1, 'Họp khoa', DateTime(2026, 11, 20), 'Khoa CNTT'],
      [2, 'Hội thảo', '21/11/2026', 'Phòng ĐT'],
      [null, null, null, null], // dòng trống bị bỏ qua
    ]);

    test('nhận ra không có cột giờ và bỏ dòng trống', () {
      expect(result.hasStartColumn, isFalse);
      expect(result.rows.length, 2);
    });

    test('dùng giờ mặc định 08:00 - 09:00', () {
      final first = result.rows[0];
      expect(first.isValid, isTrue);
      expect(first.start, DateTime(2026, 11, 20, 8, 0));
      expect(first.end, DateTime(2026, 11, 20, 9, 0));
      expect(first.usedDefaultTime, isTrue);
      expect(first.organizer, 'Khoa CNTT');
    });

    test('đọc được ngày dạng chữ dd/MM/yyyy và đánh số dòng như Excel', () {
      expect(result.rows[1].start, DateTime(2026, 11, 21, 8, 0));
      expect(result.rows[0].rowNumber, 2);
      expect(result.rows[1].rowNumber, 3);
    });

    test('giờ mặc định tùy chỉnh', () {
      final r = parseImportRows(
        [
          ['Tên sự kiện', 'Ngày'],
          ['A', '20/11/2026'],
        ],
        defaultStartMinute: 14 * 60,
        defaultEndMinute: 16 * 60,
      );
      expect(r.rows[0].start, DateTime(2026, 11, 20, 14, 0));
      expect(r.rows[0].end, DateTime(2026, 11, 20, 16, 0));
    });
  });

  group('parseImportRows: báo lỗi từng dòng', () {
    final result = parseImportRows([
      ['Danh sách lịch tuần 47'], // dòng tiêu đề đề tài, không phải tiêu đề cột
      ['Tên sự kiện', 'Ngày tổ chức'],
      ['', '22/11/2026'],
      ['Sai ngày', '31/02/2026'],
      ['Thiếu ngày', null],
      ['Hợp lệ', '23/11/2026'],
    ]);

    test('tìm đúng dòng tiêu đề dù không nằm ở dòng đầu', () {
      expect(result.rows.length, 4);
      expect(result.rows[0].rowNumber, 3);
    });

    test('mỗi dòng sai có lý do riêng', () {
      expect(result.rows[0].error, contains('Thiếu tên'));
      expect(result.rows[1].error, contains('Ngày không hợp lệ'));
      expect(result.rows[2].error, contains('Thiếu ngày'));
      expect(result.rows[3].isValid, isTrue);
    });
  });

  group('parseImportRows: file có cột giờ', () {
    final serial = DateTime(
      2026,
      11,
      20,
    ).difference(DateTime(1899, 12, 30)).inDays;
    final result = parseImportRows([
      ['Tên sự kiện', 'Ngày', 'Giờ bắt đầu', 'Giờ kết thúc'],
      ['A', '20/11/2026', '8:30', '10h'],
      ['B', DateTime(2026, 11, 20), const Duration(hours: 13), 14.0],
      ['C', '20/11/2026', '10:00', '9:00'],
      ['D', serial, '8:00', null],
      ['E', '20/11/2026', null, '9:00'],
    ]);

    test('đọc nhiều kiểu giờ: 8:30, 10h, ô giờ, số giờ', () {
      expect(result.hasStartColumn, isTrue);
      expect(result.rows[0].start, DateTime(2026, 11, 20, 8, 30));
      expect(result.rows[0].end, DateTime(2026, 11, 20, 10, 0));
      expect(result.rows[1].start, DateTime(2026, 11, 20, 13, 0));
      expect(result.rows[1].end, DateTime(2026, 11, 20, 14, 0));
    });

    test('giờ kết thúc phải sau giờ bắt đầu', () {
      expect(result.rows[2].isValid, isFalse);
      expect(result.rows[2].error, contains('Giờ kết thúc phải sau'));
    });

    test('chỉ có giờ bắt đầu thì kéo dài 1 tiếng; ngày dạng số của Excel', () {
      expect(result.rows[3].start, DateTime(2026, 11, 20, 8, 0));
      expect(result.rows[3].end, DateTime(2026, 11, 20, 9, 0));
    });

    test('chỉ có giờ kết thúc thì báo lỗi', () {
      expect(result.rows[4].error, contains('thiếu giờ bắt đầu'));
    });
  });

  group('conflictsForRow', () {
    final rows = parseImportRows([
      ['Tên sự kiện', 'Ngày', 'Giờ bắt đầu', 'Giờ kết thúc'],
      ['A', '20/11/2026', '8:00', '10:00'],
      ['B', '20/11/2026', '9:00', '11:00'],
      ['C', '20/11/2026', '11:00', '12:00'],
    ]).rows;

    test('hai dòng trong file đụng giờ nhau', () {
      expect(conflictsForRow(0, rows, {}, const []).map((e) => e.name), ['B']);
      expect(conflictsForRow(1, rows, {}, const []).map((e) => e.name), ['A']);
    });

    test('liền kề (11:00) không tính là trùng', () {
      expect(conflictsForRow(2, rows, {}, const []), isEmpty);
    });

    test('dòng bị bỏ qua không còn tính là trùng', () {
      expect(conflictsForRow(0, rows, {1}, const []), isEmpty);
    });

    test('trùng với sự kiện có sẵn trong lịch', () {
      final existing = [
        Event(
          id: 7,
          name: 'Họp',
          start: DateTime(2026, 11, 20, 11, 30),
          end: DateTime(2026, 11, 20, 12, 30),
        ),
      ];
      expect(conflictsForRow(2, rows, {}, existing).map((e) => e.id), [7]);
    });
  });

  group('isDuplicateOfExisting', () {
    final row = parseImportRows([
      ['Tên sự kiện', 'Ngày', 'Giờ bắt đầu', 'Giờ kết thúc'],
      ['HỌP KHOA', '20/11/2026', '8:00', '9:00'],
    ]).rows.first;

    test(
      'cùng tên (không phân biệt hoa thường, dấu) và cùng giờ thì là bản lặp',
      () {
        final existing = [
          Event(
            id: 1,
            name: 'Họp khoa',
            start: DateTime(2026, 11, 20, 8, 0),
            end: DateTime(2026, 11, 20, 9, 0),
          ),
        ];
        expect(isDuplicateOfExisting(row, existing), isTrue);
      },
    );

    test('khác giờ thì không phải bản lặp', () {
      final existing = [
        Event(
          id: 1,
          name: 'Họp khoa',
          start: DateTime(2026, 11, 20, 9, 0),
          end: DateTime(2026, 11, 20, 10, 0),
        ),
      ];
      expect(isDuplicateOfExisting(row, existing), isFalse);
    });
  });
}
