import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';

// ---------- Chuẩn hóa chữ để so sánh ----------

const Map<String, String> _vnGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _vnMap = {
  for (final entry in _vnGroups.entries)
    for (final ch in entry.value.split('')) ch: entry.key,
};

// Chữ thường, bỏ dấu tiếng Việt, gộp khoảng trắng: "Tên Sự Kiện" -> "ten su kien"
String normalizeText(String input) {
  final lower = input.toLowerCase();
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    sb.write(_vnMap[ch] ?? ch);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '') // dấu rời (kiểu gõ Mac)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// ---------- Các cột nhận biết trong file ----------

enum ImportField {
  stt,
  name,
  date,
  start,
  end,
  organizer,
  location,
  note,
  label,
}

const Map<ImportField, List<String>> _aliases = {
  ImportField.stt: ['stt', 'so thu tu', 'tt'],
  ImportField.name: [
    'ten su kien',
    'su kien',
    'ten cong viec',
    'cong viec',
    'noi dung',
    'ten',
  ],
  ImportField.date: ['ngay to chuc', 'ngay', 'ngay dien ra', 'ngay thang'],
  ImportField.start: ['gio bat dau', 'bat dau', 'tu gio', 'gio'],
  ImportField.end: ['gio ket thuc', 'ket thuc', 'den gio'],
  ImportField.organizer: [
    'ten nguoi to chuc',
    'nguoi to chuc',
    'to chuc',
    'giang vien',
    'nguoi phu trach',
  ],
  ImportField.location: ['dia diem', 'phong', 'noi to chuc'],
  ImportField.note: ['ghi chu', 'mo ta'],
  ImportField.label: ['nhan', 'loai', 'phan loai'],
};

// ---------- Đọc giá trị của ô ----------
// Ô đã được đổi sang kiểu cơ bản: String, int, double, bool,
// DateTime (ô ngày), Duration (ô giờ) hoặc null (ô trống).

String cellText(Object? v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
  return v.toString().trim();
}

bool isBlankCell(Object? v) => cellText(v).isEmpty;

({int y, int m, int d})? _splitDate(String token) {
  final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$')
      .firstMatch(token);
  if (ymd != null) {
    return (
      y: int.parse(ymd.group(1)!),
      m: int.parse(ymd.group(2)!),
      d: int.parse(ymd.group(3)!),
    );
  }
  final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$')
      .firstMatch(token);
  if (dmy != null) {
    var y = int.parse(dmy.group(3)!);
    if (y < 100) y += 2000;
    return (y: y, m: int.parse(dmy.group(2)!), d: int.parse(dmy.group(1)!));
  }
  return null;
}

// Trả về ngày (giờ 00:00) hoặc null nếu không đọc được
DateTime? parseDateCell(Object? v) {
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  if (v is num) {
    // Số ngày kể từ 30/12/1899 (cách Excel lưu ngày)
    if (v < 1 || v > 2958465) return null;
    return DateTime(1899, 12, 30 + v.floor());
  }
  if (v is String) {
    final token = v.trim().split(RegExp(r'\s+')).first;
    final parts = _splitDate(token);
    if (parts == null) return null;
    final date = DateTime(parts.y, parts.m, parts.d);
    // Loại các ngày không tồn tại như 31/02
    if (date.year != parts.y || date.month != parts.m || date.day != parts.d) {
      return null;
    }
    return date;
  }
  return null;
}

Duration? _minutesOrNull(int minutes) =>
    (minutes < 0 || minutes >= 24 * 60) ? null : Duration(minutes: minutes);

// Trả về giờ trong ngày (dạng Duration) hoặc null nếu không đọc được
Duration? parseTimeCell(Object? v) {
  if (v is Duration) return _minutesOrNull(v.inMinutes);
  if (v is DateTime) return Duration(hours: v.hour, minutes: v.minute);
  if (v is num) {
    if (v >= 0 && v < 1) {
      return _minutesOrNull((v * 1440).round()); // phần của ngày
    }
    if (v >= 1 && v < 24) {
      return _minutesOrNull((v * 60).round()); // số giờ
    }
    return null;
  }
  if (v is String) {
    final text = v.trim();
    final onlyHour = int.tryParse(text);
    if (onlyHour != null) return _minutesOrNull(onlyHour * 60);
    final m = RegExp(r'^(\d{1,2})\s*[:hHgG]\s*(\d{1,2})?(?:\s*:\s*\d{1,2})?$')
        .firstMatch(text);
    if (m == null) return null;
    final hour = int.parse(m.group(1)!);
    final minute = m.group(2) == null ? 0 : int.parse(m.group(2)!);
    if (minute > 59) return null;
    return _minutesOrNull(hour * 60 + minute);
  }
  return null;
}

// ---------- Một dòng đã đọc từ file ----------

class ImportRow {
  final int rowNumber; // số dòng trong Excel (dòng đầu tiên là 1)
  final String? error; // null = dòng hợp lệ
  final String name;
  final DateTime? start;
  final DateTime? end;
  final String organizer;
  final String location;
  final String note;
  final String labelName; // tên nhãn ghi trong file ('' = không có)
  final bool usedDefaultTime; // dòng không có giờ, đang dùng giờ mặc định
  final bool moved; // đã được dời sang giờ khác

  const ImportRow({
    required this.rowNumber,
    required this.name,
    this.error,
    this.start,
    this.end,
    this.organizer = '',
    this.location = '',
    this.note = '',
    this.labelName = '',
    this.usedDefaultTime = false,
    this.moved = false,
  });

  bool get isValid => error == null;

  int get durationMinutes =>
      (start == null || end == null) ? 0 : end!.difference(start!).inMinutes;

  ImportRow copyWith({
    DateTime? start,
    DateTime? end,
    bool? usedDefaultTime,
    bool? moved,
  }) {
    return ImportRow(
      rowNumber: rowNumber,
      name: name,
      error: error,
      start: start ?? this.start,
      end: end ?? this.end,
      organizer: organizer,
      location: location,
      note: note,
      labelName: labelName,
      usedDefaultTime: usedDefaultTime ?? this.usedDefaultTime,
      moved: moved ?? this.moved,
    );
  }

  Event toEvent({int? labelId}) => Event(
    name: name,
    start: start!,
    end: end!,
    labelId: labelId,
    organizer: organizer,
    location: location,
    note: note,
  );
}

class ImportParseResult {
  final List<ImportRow> rows;
  final bool hasStartColumn; // file có cột giờ bắt đầu

  const ImportParseResult({required this.rows, required this.hasStartColumn});
}

// Tìm dòng tiêu đề (trong 20 dòng đầu): phải có cột tên sự kiện và cột ngày
({int rowIndex, Map<ImportField, int> columns})? findImportHeader(
  List<List<Object?>> rows,
) {
  final limit = rows.length < 20 ? rows.length : 20;
  for (var i = 0; i < limit; i++) {
    final cols = <ImportField, int>{};
    for (var c = 0; c < rows[i].length; c++) {
      final h = normalizeText(cellText(rows[i][c]));
      if (h.isEmpty) continue;
      for (final entry in _aliases.entries) {
        if (entry.value.contains(h) && !cols.containsKey(entry.key)) {
          cols[entry.key] = c;
          break;
        }
      }
    }
    if (cols.containsKey(ImportField.name) &&
        cols.containsKey(ImportField.date)) {
      return (rowIndex: i, columns: cols);
    }
  }
  return null;
}

bool hasImportHeader(List<List<Object?>> rows) =>
    findImportHeader(rows) != null;

// Đọc các dòng dữ liệu. Dòng không đọc được vẫn được giữ lại kèm lý do lỗi.
ImportParseResult parseImportRows(
  List<List<Object?>> rows, {
  int defaultStartMinute = 8 * 60,
  int defaultEndMinute = 9 * 60,
}) {
  final header = findImportHeader(rows);
  if (header == null) {
    return ImportParseResult(rows: [], hasStartColumn: false);
  }
  final cols = header.columns;
  final out = <ImportRow>[];

  for (var i = header.rowIndex + 1; i < rows.length; i++) {
    final r = rows[i];
    Object? at(ImportField f) {
      final c = cols[f];
      return (c == null || c >= r.length) ? null : r[c];
    }

    final name = cellText(at(ImportField.name));
    final dateRaw = at(ImportField.date);
    final startRaw = at(ImportField.start);
    final endRaw = at(ImportField.end);
    final organizer = cellText(at(ImportField.organizer));
    final location = cellText(at(ImportField.location));
    final note = cellText(at(ImportField.note));
    final labelName = cellText(at(ImportField.label));

    // Bỏ qua dòng trống (cột STT không tính)
    final hasContent = [
      name,
      cellText(dateRaw),
      cellText(startRaw),
      cellText(endRaw),
      organizer,
      location,
      note,
      labelName,
    ].any((s) => s.isNotEmpty);
    if (!hasContent) continue;

    final errors = <String>[];
    if (name.isEmpty) errors.add('Thiếu tên sự kiện');

    DateTime? date;
    if (isBlankCell(dateRaw)) {
      errors.add('Thiếu ngày');
    } else {
      date = parseDateCell(dateRaw);
      if (date == null) {
        errors.add('Ngày không hợp lệ ("${cellText(dateRaw)}")');
      }
    }

    int? startMin;
    int? endMin;
    var usedDefault = false;
    final hasStart = !isBlankCell(startRaw);
    final hasEnd = !isBlankCell(endRaw);

    if (hasStart) {
      final d = parseTimeCell(startRaw);
      if (d == null) {
        errors.add('Giờ bắt đầu không hợp lệ ("${cellText(startRaw)}")');
      } else {
        startMin = d.inMinutes;
      }
    }
    if (hasEnd) {
      final d = parseTimeCell(endRaw);
      if (d == null) {
        errors.add('Giờ kết thúc không hợp lệ ("${cellText(endRaw)}")');
      } else {
        endMin = d.inMinutes;
      }
    }

    if (!hasStart && !hasEnd) {
      startMin = defaultStartMinute;
      endMin = defaultEndMinute;
      usedDefault = true;
    } else if (hasStart && !hasEnd) {
      // Chỉ có giờ bắt đầu: mặc định kéo dài 1 tiếng
      if (startMin != null) {
        endMin = startMin + 60;
        if (endMin > 23 * 60 + 59) endMin = 23 * 60 + 59;
      }
    } else if (!hasStart && hasEnd) {
      errors.add('Có giờ kết thúc nhưng thiếu giờ bắt đầu');
    }
    if (startMin != null && endMin != null && endMin <= startMin) {
      errors.add('Giờ kết thúc phải sau giờ bắt đầu');
    }

    final error = errors.isEmpty ? null : errors.join('; ');
    DateTime? start;
    DateTime? end;
    if (error == null) {
      start = DateTime(date!.year, date.month, date.day, 0, startMin!);
      end = DateTime(date.year, date.month, date.day, 0, endMin!);
    }

    out.add(
      ImportRow(
        rowNumber: i + 1,
        name: name,
        error: error,
        start: start,
        end: end,
        organizer: organizer,
        location: location,
        note: note,
        labelName: labelName,
        usedDefaultTime: usedDefault,
      ),
    );
  }

  return ImportParseResult(
    rows: out,
    hasStartColumn: cols.containsKey(ImportField.start),
  );
}

// Các sự kiện đang trùng giờ với dòng [index], tính cả sự kiện có sẵn trong lịch
// ([existing]) và các dòng khác trong file chưa bị bỏ qua.
List<Event> conflictsForRow(
  int index,
  List<ImportRow> rows,
  Set<int> skipped,
  Iterable<Event> existing,
) {
  final row = rows[index];
  if (!row.isValid) return const [];
  final others = <Event>[
    ...existing,
    for (var j = 0; j < rows.length; j++)
      if (j != index && rows[j].isValid && !skipped.contains(j))
        rows[j].toEvent(),
  ];
  return findConflicts(row.toEvent(), others);
}

// Dòng này đã có sẵn trong lịch chưa (cùng tên, cùng giờ bắt đầu và kết thúc)
bool isDuplicateOfExisting(ImportRow row, Iterable<Event> existing) {
  if (!row.isValid) return false;
  final n = normalizeText(row.name);
  return existing.any(
    (e) =>
        normalizeText(e.name) == n && e.start == row.start && e.end == row.end,
  );
}
