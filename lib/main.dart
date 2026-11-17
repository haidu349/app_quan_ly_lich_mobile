import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/main_shell.dart';
import 'package:quan_ly_lich/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nếu thông báo khởi tạo lỗi thì app vẫn chạy bình thường
  await ReminderService.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppData()..load(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý lịch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const MainShell(),
    );
  }
}
