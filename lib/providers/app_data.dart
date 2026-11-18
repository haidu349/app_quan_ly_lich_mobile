import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:quan_ly_lich/database/database_helper.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/services/conflict_service.dart';
import 'package:quan_ly_lich/services/reminder_planner.dart';
import 'package:quan_ly_lich/services/reminder_service.dart';

// Nơi giữ dữ liệu chung cho cả app. Khi dữ liệu đổi, gọi notifyListeners()
// để mọi màn hình đang "nghe" tự vẽ lại.
class AppData extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ReminderService _reminders = ReminderService.instance;

  List<Event> _events = [];
  List<EventLabel> _labels = [];
  // Giữ một view duy nhất cho đến khi dữ liệu thực sự đổi. Trước đây mỗi lần
  // gọi getter tạo một UnmodifiableListView mới -> widget con rebuild vô ích.
  UnmodifiableListView<Event> _eventsView = UnmodifiableListView(<Event>[]);
  UnmodifiableListView<EventLabel> _labelsView = UnmodifiableListView(
    <EventLabel>[],
  );
  Map<int, EventLabel> _labelMap = {};
  Set<int> _conflictIds = {}; // id các sự kiện đang trùng giờ với sự kiện khác
  bool _loading = true;
  Timer? _clock;

  // Nhắc nhở
  bool _reminderEnabled = true;
  int _reminderMinute = kDefaultReminderMinute;
  int _scheduledReminderCount = 0;
  bool _syncing = false;
  bool _syncAgain = false;

  AppData() {
    // Mỗi phút báo giao diện vẽ lại một lần, để các thẻ tự chuyển sang
    // màu xám khi sự kiện vừa kết thúc.
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  bool get loading => _loading;
  UnmodifiableListView<Event> get events => _eventsView;
  UnmodifiableListView<EventLabel> get labels => _labelsView;

  bool get reminderEnabled => _reminderEnabled;
  int get reminderMinute => _reminderMinute;
  int get scheduledReminderCount => _scheduledReminderCount;

  EventLabel? labelOf(Event event) {
    final id = event.labelId;
    return id == null ? null : _labelMap[id];
  }

  // Sự kiện đã kết thúc (giờ kết thúc <= bây giờ)
  bool isPast(Event event) => !event.end.isAfter(DateTime.now());

  // Sự kiện đã bắt đầu nhưng chưa kết thúc
  bool isOngoing(Event event) {
    final now = DateTime.now();
    return !event.start.isAfter(now) && event.end.isAfter(now);
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
    _labelsView = UnmodifiableListView(_labels);
  }

  Future<void> _fetchEvents() async {
    _events = await _db.getAllEvents();
    _conflictIds = findConflictingIds(_events);
    _eventsView = UnmodifiableListView(_events);
  }

  Future<void> _loadReminderSettings() async {
    final enabled = await _db.getSetting('reminder_enabled');
    final minute = await _db.getSetting('reminder_minute');
    _reminderEnabled = enabled != '0';
    _reminderMinute = int.tryParse(minute ?? '') ?? kDefaultReminderMinute;
  }

  // Gọi một lần khi mở app
  Future<void> load() async {
    await _db.deleteOlderThanOneYear(); // tự xóa dữ liệu quá 1 năm
    await _fetchLabels();
    await _fetchEvents();
    await _loadReminderSettings();

    // runApp() đã chạy từ trước, nên chỗ này không chặn frame đầu tiên.
    await _reminders.init();
    _loading = false;
    notifyListeners();

    if (_reminderEnabled) await _reminders.ensurePermission();
    await _syncReminders();
  }

  // ---------- Nhắc nhở ----------

  // Hẹn lại toàn bộ thông báo theo dữ liệu hiện tại. Nếu đang hẹn dở mà có
  // thay đổi mới thì chạy thêm một vòng nữa, tránh hai lần hẹn đè nhau.
  Future<void> _syncReminders() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _applyReminders();
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _applyReminders() async {
    if (!_reminderEnabled) {
      await _reminders.cancelAllPending();
      _scheduledReminderCount = 0;
    } else {
      final plan = planReminders(
        _events,
        now: DateTime.now(),
        minuteOfDay: _reminderMinute,
      );
      _scheduledReminderCount = await _reminders.reschedule(plan);
    }
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool value) async {
    _reminderEnabled = value;
    notifyListeners();
    await _db.setSetting('reminder_enabled', value ? '1' : '0');
    await _syncReminders();
  }

  Future<void> setReminderMinute(int minute) async {
    _reminderMinute = minute;
    notifyListeners();
    await _db.setSetting('reminder_minute', '$minute');
    await _syncReminders();
  }

  // ---------- Sự kiện ----------

  Future<void> addEvent(Event event) async {
    await _db.insertEvent(event);
    await _fetchEvents();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> addEvents(List<Event> events) async {
    await _db.insertEvents(events);
    await _fetchEvents();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> updateEvent(Event event) async {
    await _db.updateEvent(event);
    await _fetchEvents();
    notifyListeners();
    await _syncReminders();
  }

  // Sửa nhiều sự kiện một lần (dời lịch hàng loạt, hoàn tác): một giao dịch,
  // chỉ tải lại và hẹn lại nhắc nhở đúng một lần cho cả đợt.
  Future<void> updateEvents(List<Event> events) async {
    if (events.isEmpty) return;
    await _db.updateEvents(events);
    await _fetchEvents();
    notifyListeners();
    await _syncReminders();
  }

  // Bỏ khỏi danh sách ngay rồi mới xóa trong database,
  // để thẻ biến mất tức thì khi vuốt.
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((e) => e.id == id);
    _conflictIds = findConflictingIds(_events);
    _eventsView = UnmodifiableListView(_events);
    notifyListeners();
    await _db.deleteEvent(id);
    await _syncReminders();
  }

  Future<void> deleteEvents(Set<int> ids) async {
    if (ids.isEmpty) return;
    _events.removeWhere((e) => ids.contains(e.id));
    _conflictIds = findConflictingIds(_events);
    _eventsView = UnmodifiableListView(_events);
    notifyListeners();
    await _db.deleteEvents(ids.toList());
    await _syncReminders();
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
