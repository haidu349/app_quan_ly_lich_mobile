import 'dart:typed_data';

import 'package:excel/excel.dart';

class ExcelSheetData {
  final String name;
  final List<List<Object?>> rows;

  const ExcelSheetData(this.name, this.rows);
}

// Đọc mọi sheet của file .xlsx
List<ExcelSheetData> readExcelSheets(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheets = <ExcelSheetData>[];
  for (final name in excel.tables.keys) {
    final sheet = excel.tables[name];
    if (sheet == null) continue;
    final rows = <List<Object?>>[
      for (final row in sheet.rows)
        [for (final cell in row) _toPrimitive(cell?.value)],
    ];
    sheets.add(ExcelSheetData(name, rows));
  }
  return sheets;
}

Object? _toPrimitive(CellValue? v) {
  if (v == null) return null;
  if (v is TextCellValue) {
    // Tùy bản thư viện, giá trị là String hoặc TextSpan: xử lý cả hai
    final dynamic raw = v.value;
    if (raw is String) return raw;
    try {
      return raw.toPlainText() as String;
    } catch (_) {
      return raw.toString();
    }
  }
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value;
  if (v is BoolCellValue) return v.value;
  if (v is DateCellValue) return DateTime(v.year, v.month, v.day);
  if (v is DateTimeCellValue) {
    return DateTime(v.year, v.month, v.day, v.hour, v.minute);
  }
  if (v is TimeCellValue) return Duration(hours: v.hour, minutes: v.minute);
  return null; // ô công thức hoặc loại khác: coi như trống
}
