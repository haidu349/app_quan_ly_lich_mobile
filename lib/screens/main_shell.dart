import 'package:flutter/material.dart';
import 'package:quan_ly_lich/screens/ledger_screen.dart';
import 'package:quan_ly_lich/screens/placeholder_screen.dart';
import 'package:quan_ly_lich/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1; // mở app vào tab Sổ cái

  final List<Widget> _pages = const [
    PlaceholderScreen(
      title: 'Lịch',
      icon: Icons.calendar_month,
      message: 'Tab Lịch sẽ làm ở bước sau',
    ),
    LedgerScreen(),
    PlaceholderScreen(
      title: 'Thống kê',
      icon: Icons.bar_chart,
      message: 'Tab Thống kê sẽ làm ở bước sau',
    ),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giữ nguyên trạng thái từng tab khi chuyển qua lại
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Sổ cái',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
