import 'package:flutter/material.dart';
import 'package:quan_ly_lich/database/database_helper.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/screens/add_event_screen.dart';
import 'package:quan_ly_lich/utils/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Event> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final db = DatabaseHelper.instance;
    await db.deleteOlderThanOneYear(); // tự xóa dữ liệu quá 1 năm
    final events = await db.getAllEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  // Dùng chung cho thêm (event = null) và sửa (event != null)
  Future<void> _openForm({Event? event}) async {
    final result = await Navigator.push<Event>(
      context,
      MaterialPageRoute(builder: (_) => AddEventScreen(event: event)),
    );
    if (result == null) return;

    if (event == null) {
      await DatabaseHelper.instance.insertEvent(result);
    } else {
      await DatabaseHelper.instance.updateEvent(result);
    }
    await _loadEvents();
  }

  Future<bool> _confirmDelete(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text('Bạn có chắc muốn xóa "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch của tôi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(child: Text('Chưa có sự kiện nào'))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Dismissible(
                    key: ValueKey(event.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => _confirmDelete(event),
                    onDismissed: (_) async {
                      // Bỏ khỏi danh sách ngay để tránh lỗi giao diện
                      setState(
                        () => _events.removeWhere((e) => e.id == event.id),
                      );
                      await DatabaseHelper.instance.deleteEvent(event.id!);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã xóa "${event.name}"')),
                      );
                    },
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${event.date.day}')),
                        title: Text(event.name),
                        subtitle: Text(
                          '${event.organizer} • ${formatDate(event.date)}',
                        ),
                        onTap: () => _openForm(event: event),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
