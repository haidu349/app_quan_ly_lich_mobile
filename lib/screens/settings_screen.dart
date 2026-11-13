import 'package:flutter/material.dart';
import 'package:quan_ly_lich/screens/label_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
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
          const ListTile(
            enabled: false,
            leading: Icon(Icons.upload_file),
            title: Text('Nhập từ file Excel'),
            subtitle: Text('Sắp có'),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Nhắc nhở 6:00 sáng'),
            subtitle: Text('Sắp có'),
          ),
        ],
      ),
    );
  }
}
