import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/backup_service.dart';
import 'package:quan_ly_lich/screens/import_flow.dart';
import 'package:quan_ly_lich/screens/label_screen.dart';
import 'package:quan_ly_lich/services/reminder_planner.dart';
import 'package:quan_ly_lich/services/reminder_service.dart';

String _hm(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay % 60).toString().padLeft(2, '0')}';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final ReminderService _svc = ReminderService.instance;
  late Future<bool> _allowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _allowed = _svc.notificationsAllowed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quay lại app từ màn hình cài đặt của hệ thống thì kiểm tra lại quyền
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  void _refreshPermission() {
    setState(() => _allowed = _svc.notificationsAllowed());
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(bool value) async {
    final data = context.read<AppData>();
    // Bật công tắt ngay, không chờ hộp xin quyền để nút luôn phản hồi
    final saving = data.setReminderEnabled(value);
    if (value) {
      final ok = await _svc.ensurePermission();
      if (!mounted) return;
      _refreshPermission();
      if (!ok) {
        _snack(
          'Chưa được cấp quyền thông báo. Hãy cấp quyền để nhận nhắc nhở.',
        );
      } else {
        await saving;
        await data.setReminderMinute(data.reminderMinute);
      }
    }
    await saving;
  }

  Future<void> _backup() async {
    final d = DateTime.now();
    final stamp =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'sao_luu_lich_$stamp.json',
        bytes: utf8.encode(context.read<AppData>().exportBackup()),
        mimeType: 'application/json',
        dialogTitle: 'Lưu file sao lưu',
      );
      if (saved != null) _snack('Đã lưu file sao lưu');
    } catch (e) {
      _snack('Không lưu được: $e');
    }
  }

  Future<void> _restore() async {
    final data = context.read<AppData>();
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final backup = decodeBackup(utf8.decode(await file.readAsBytes()));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục từ sao lưu?'),
          content: Text(
            'File có ${backup.events.length} sự kiện và ${backup.labels.length} nhãn. '
            'Toàn bộ lịch và nhãn hiện tại sẽ bị thay bằng nội dung file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await data.restoreBackup(backup);
      _snack('Đã khôi phục ${backup.events.length} sự kiện');
    } on FormatException catch (e) {
      _snack('File không dùng được: ${e.message}');
    } catch (e) {
      _snack('Không khôi phục được: $e');
    }
  }

  Future<void> _pickTime() async {
    final data = context.read<AppData>();
    final current = data.reminderMinute;
    final picked = await showTimePicker(
      context: context,
      helpText: 'GIỜ NHẮC MỖI SÁNG',
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    await data.setReminderMinute(picked.hour * 60 + picked.minute);
  }

  Future<void> _requestPermission() async {
    final ok = await _svc.requestNotificationPermission();
    if (!mounted) return;
    _refreshPermission();
    if (!ok) {
      _snack(
        'Máy không hiện hộp cấp quyền. Vào Cài đặt máy → Ứng dụng → quan_ly_lich → Thông báo để bật.',
      );
    }
  }

  Future<void> _testNow() async {
    final error = await _svc.showTest();
    if (!mounted) return;
    _snack(
      error == null
          ? 'Đã gửi thông báo thử. Kéo thanh thông báo xuống để xem.'
          : 'Không gửi được: $error',
    );
  }

  Future<void> _testScheduled() async {
    final error = await _svc.scheduleTest();
    if (!mounted) return;
    _snack(
      error == null
          ? 'Đã hẹn sau 1 phút. Hãy bấm nút Home (thoát khỏi app) rồi chờ.'
          : 'Không hẹn được: $error',
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final textTheme = Theme.of(context).textTheme;

    String countText;
    if (!data.reminderEnabled) {
      countText = 'Đang tắt';
    } else if (!_svc.isReady) {
      countText = 'Chưa khởi tạo được thông báo: ${_svc.lastError ?? ''}';
    } else {
      countText =
          'Đã hẹn ${data.scheduledReminderCount} thông báo trong $kReminderDaysAhead ngày tới (chỉ ngày có lịch)';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          _SectionTitle('Dữ liệu'),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Quản lý nhãn'),
            subtitle: const Text('Thêm, đổi tên, đổi màu, xóa nhãn'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabelScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Nhập từ file Excel'),
            subtitle: const Text('Xem trước, báo lỗi và dời lịch bị trùng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => startExcelImport(context),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Sao lưu ra file'),
            subtitle: const Text('Lưu toàn bộ lịch và nhãn thành file .json'),
            onTap: _backup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Khôi phục từ file sao lưu'),
            subtitle: const Text('Thay toàn bộ lịch hiện tại bằng file đã lưu'),
            onTap: _restore,
          ),
          const Divider(),
          _SectionTitle('Nhắc nhở hằng ngày'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Nhắc lịch mỗi sáng'),
            subtitle: Text(
              'Lúc ${_hm(data.reminderMinute)} mỗi sáng, thông báo có âm thanh '
              'liệt kê các lịch trong ngày. Ngày không có lịch thì không báo.',
            ),
            value: data.reminderEnabled,
            onChanged: _toggle,
          ),
          ListTile(
            enabled: data.reminderEnabled,
            leading: const Icon(Icons.access_time),
            title: const Text('Giờ nhắc'),
            trailing: Text(
              _hm(data.reminderMinute),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _pickTime,
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Tình trạng'),
            subtitle: Text(countText),
          ),
          FutureBuilder<bool>(
            future: _allowed,
            builder: (context, snap) {
              if (snap.data != false) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: Colors.red,
                ),
                title: const Text('Chưa được cấp quyền thông báo'),
                subtitle: const Text(
                  'Không cấp quyền thì sẽ không có thông báo nào hiện ra',
                ),
                trailing: FilledButton(
                  onPressed: _requestPermission,
                  child: const Text('Cấp quyền'),
                ),
              );
            },
          ),
          const Divider(),
          _SectionTitle('Kiểm tra thông báo'),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Gửi thông báo thử ngay'),
            subtitle: const Text('Kiểm tra quyền và âm thanh'),
            onTap: _testNow,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Hẹn thông báo thử sau 1 phút'),
            subtitle: const Text(
              'Bấm Home rồi chờ, kiểm tra thông báo hẹn giờ',
            ),
            onTap: _testScheduled,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              'Lưu ý: một số hãng điện thoại (realme, Oppo, Xiaomi...) tự tắt app chạy '
              'nền để tiết kiệm pin nên thông báo có thể không hiện. Nếu gặp tình trạng '
              'này, vào Cài đặt máy → Pin → cho phép ứng dụng chạy nền và tự khởi động.',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
