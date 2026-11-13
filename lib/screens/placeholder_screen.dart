import 'package:flutter/material.dart';

// Màn hình tạm cho các tab chưa làm
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
