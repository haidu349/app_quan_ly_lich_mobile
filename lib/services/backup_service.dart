import 'dart:convert';

import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';

const int kBackupVersion = 1;

class BackupData {
  final List<EventLabel> labels;
  final List<Event> events;

  const BackupData(this.labels, this.events);
}

// Gói nhãn và sự kiện thành một chuỗi JSON để lưu ra file
String encodeBackup(List<EventLabel> labels, List<Event> events) {
  return jsonEncode({
    'app': 'quan_ly_lich',
    'version': kBackupVersion,
    'labels': [for (final l in labels) l.toMap()],
    'events': [for (final e in events) e.toMap()],
  });
}

// Đọc lại file sao lưu. File sai định dạng thì ném FormatException,
// không trả dữ liệu dở dang để tránh ghi đè mất lịch hiện có.
BackupData decodeBackup(String text) {
  try {
    final root = jsonDecode(text);
    if (root is! Map || root['app'] != 'quan_ly_lich') {
      throw const FormatException('Không phải file sao lưu của app');
    }
    final version = root['version'];
    if (version is! int || version > kBackupVersion) {
      throw const FormatException('File sao lưu từ bản app mới hơn');
    }
    final labels = [
      for (final m in root['labels'] as List)
        EventLabel.fromMap(Map<String, Object?>.from(m as Map)),
    ];
    final labelIds = {for (final l in labels) l.id};
    final events = <Event>[];
    for (final m in root['events'] as List) {
      final map = Map<String, Object?>.from(m as Map);
      // Nhãn không còn trong file thì để "không nhãn", tránh vi phạm khóa ngoại
      if (!labelIds.contains(map['label_id'])) map['label_id'] = null;
      events.add(Event.fromMap(map));
    }
    return BackupData(labels, events);
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('File sao lưu bị hỏng ($e)');
  }
}
