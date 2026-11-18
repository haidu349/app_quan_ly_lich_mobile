import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thông báo được khởi tạo trong AppData.load(), sau khi đã hiện giao diện.

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
      theme: _theme(),
      home: const MainShell(),
    );
  }
}

// Nút chọn đoạn: không viền, nền đậm hơn nền app một chút, có đổ bóng nhẹ
ThemeData _theme() {
  final base = ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);
  final s = base.colorScheme;
  return base.copyWith(
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.35),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? s.secondaryContainer
              : s.surfaceContainerHigh,
        ),
      ),
    ),
  );
}
