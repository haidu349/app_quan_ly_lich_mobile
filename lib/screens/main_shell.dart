import 'package:flutter/material.dart';
import 'package:quan_ly_lich/screens/calendar_screen.dart';
import 'package:quan_ly_lich/screens/ledger_screen.dart';
import 'package:quan_ly_lich/screens/settings_screen.dart';
import 'package:quan_ly_lich/screens/statistics_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0; // mở app vào tab Lịch
  final Set<int> _opened = {0}; // các tab đã từng được mở

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const CalendarScreen();
      case 1:
        return const LedgerScreen();
      case 2:
        return const StatisticsScreen();
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tab nào chưa mở thì chưa dựng; đã mở thì giữ nguyên trạng thái
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 4; i++)
            _opened.contains(i) ? _page(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _opened.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Danh sách',
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
