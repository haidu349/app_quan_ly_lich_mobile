import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quan_ly_lich/services/reminder_planner.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Hẹn, hủy và thử thông báo. Chỉ có một đối tượng dùng chung cho cả app.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const String _channelId = 'daily_agenda';
  static const String _channelName = 'Nhắc lịch hằng ngày';
  static const String _channelDesc =
      'Thông báo buổi sáng liệt kê các lịch trong ngày';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  String? lastError; // lỗi gần nhất, để hiển thị khi cần

  bool get isReady => _ready;

  // Gọi một lần khi mở app. Lỗi thì app vẫn chạy, chỉ là không có thông báo.
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );
      _ready = true;
    } catch (e) {
      lastError = '$e';
      debugPrint('Không khởi tạo được thông báo: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // ---------- Quyền ----------

  Future<bool> notificationsAllowed() async {
    if (!_ready) return false;
    try {
      return (await _android?.areNotificationsEnabled()) ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!_ready) return false;
    try {
      return (await _android?.requestNotificationsPermission()) ?? false;
    } catch (_) {
      return false;
    }
  }

  // Đã có quyền thì thôi, chưa có thì xin
  Future<bool> ensurePermission() async {
    if (await notificationsAllowed()) return true;
    return requestNotificationPermission();
  }

  Future<bool> _canScheduleExact() async {
    try {
      return (await _android?.canScheduleExactNotifications()) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------- Hẹn thông báo ----------

  NotificationDetails _details(String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true, // có âm thanh
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body), // bấm vào để xem đủ
      ),
    );
  }

  // Mỗi thông báo là một thời điểm cụ thể nên dùng múi giờ UTC cho đơn giản:
  // cùng một thời điểm dù máy ở múi giờ nào.
  tz.TZDateTime _at(DateTime when) =>
      tz.TZDateTime.from(when, tz.getLocation('UTC'));

  // Hủy hết thông báo đang chờ rồi hẹn lại theo [plan]. Trả về số thông báo đã hẹn.
  Future<int> reschedule(List<PlannedReminder> plan) async {
    if (!_ready) return 0;
    try {
      await _plugin.cancelAllPendingNotifications();
      if (plan.isEmpty) return 0;

      final mode = (await _canScheduleExact())
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.summary,
          scheduledDate: _at(r.when),
          notificationDetails: _details(r.body),
          androidScheduleMode: mode,
        );
      }
      lastError = null;
      return plan.length;
    } catch (e) {
      lastError = '$e';
      debugPrint('Không hẹn được thông báo: $e');
      return 0;
    }
  }

  Future<void> cancelAllPending() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (e) {
      lastError = '$e';
    }
  }

  // ---------- Thử ----------
  // Hai hàm dưới trả về null nếu ổn, hoặc nội dung lỗi.

  Future<String?> showTest() async {
    if (!_ready) return 'Chưa khởi tạo được thông báo: ${lastError ?? ''}';
    try {
      const body = '08:00 - 09:00  Họp thử\n13:00 - 15:00  Học thử';
      await _plugin.show(
        id: 1,
        title: 'Thông báo thử',
        body: 'Nếu bạn thấy và nghe được thông báo này là ổn rồi',
        notificationDetails: _details(body),
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> scheduleTest({
    Duration after = const Duration(minutes: 1),
  }) async {
    if (!_ready) return 'Chưa khởi tạo được thông báo: ${lastError ?? ''}';
    try {
      final mode = (await _canScheduleExact())
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      await _plugin.zonedSchedule(
        id: 2,
        title: 'Thông báo hẹn giờ',
        body: 'Thông báo này được hẹn từ trước, app không cần đang mở',
        scheduledDate: _at(DateTime.now().add(after)),
        notificationDetails: _details('Thông báo hẹn giờ thử'),
        androidScheduleMode: mode,
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
