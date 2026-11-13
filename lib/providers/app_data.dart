import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:quan_ly_lich/database/database_helper.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';

// Nơi giữ dữ liệu chung cho cả app. Khi dữ liệu đổi, gọi notifyListeners()
// để mọi màn hình đang "nghe" tự vẽ lại.
class AppData extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Event> _events = [];
  List<EventLabel> _labels = [];
  Map<int, EventLabel> _labelMap = {};
  Set<int> _conflictIds = {}; // id các sự kiện đang trùng giờ với sự kiện khác
  bool _loading = true;

  bool get loading => _loading;
  UnmodifiableListView<Event> get events => UnmodifiableListView(_events);
  UnmodifiableListView<EventLabel> get labels => UnmodifiableListView(_labels);

  EventLabel? labelOf(Event event) {
    final id = event.labelId;
    return id == null ? null : _labelMap[id];
  }

  // Sự kiện này có đang trùng giờ với sự kiện khác không
  bool hasConflict(Event event) =>
      event.id != null && _conflictIds.contains(event.id);

  // Các sự kiện đang trùng với [candidate] (dùng cho cảnh báo trong form)
  List<Event> conflictsFor(Event candidate) =>
      findConflicts(candidate, _events);

  Future<void> _fetchLabels() async {
    _labels = await _db.getAllLabels();
    _labelMap = {for (final l in _labels) l.id!: l};
  }

  Future<void> _fetchEvents() async {
    _events = await _db.getAllEvents();
    _conflictIds = findConflictingIds(_events);
  }

  // Gọi một lần khi mở app
  Future<void> load() async {
    await _db.deleteOlderThanOneYear(); // tự xóa dữ liệu quá 1 năm
    await _fetchLabels();
    await _fetchEvents();
    _loading = false;
    notifyListeners();
  }

  // ---------- Sự kiện ----------

  Future<void> addEvent(Event event) async {
    await _db.insertEvent(event);
    await _fetchEvents();
    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    await _db.updateEvent(event);
    await _fetchEvents();
    notifyListeners();
  }

  // Bỏ khỏi danh sách ngay rồi mới xóa trong database,
  // để thẻ biến mất tức thì khi vuốt.
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((e) => e.id == id);
    _conflictIds = findConflictingIds(_events);
    notifyListeners();
    await _db.deleteEvent(id);
  }

  // ---------- Nhãn ----------

  Future<int> addLabel(EventLabel label) async {
    final id = await _db.insertLabel(label);
    await _fetchLabels();
    notifyListeners();
    return id;
  }

  Future<void> updateLabel(EventLabel label) async {
    await _db.updateLabel(label);
    await _fetchLabels();
    notifyListeners();
  }

  Future<void> deleteLabel(int id) async {
    await _db.deleteLabel(id);
    await _fetchLabels();
    await _fetchEvents(); // sự kiện dùng nhãn này đã chuyển thành "không nhãn"
    notifyListeners();
  }
}
