import 'package:flutter/material.dart';
import 'package:quan_ly_lich/database/database_helper.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';
import 'package:quan_ly_lich/screens/add_event_screen.dart';
import 'package:quan_ly_lich/screens/label_screen.dart';
import 'package:quan_ly_lich/widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Event> _events = [];
  List<EventLabel> _labels = [];
  Map<int, EventLabel> _labelMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    await db.deleteOlderThanOneYear(); // tự xóa dữ liệu quá 1 năm
    final events = await db.getAllEvents();
    final labels = await db.getAllLabels();
    if (!mounted) return;
    setState(() {
      _events = events;
      _labels = labels;
      _labelMap = {for (final l in labels) l.id!: l};
      _loading = false;
    });
  }

  Future<void> _openForm({Event? event}) async {
    final result = await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(event: event, labels: _labels),
      ),
    );
    if (result != null) {
      if (event == null) {
        await DatabaseHelper.instance.insertEvent(result);
      } else {
        await DatabaseHelper.instance.updateEvent(result);
      }
    }
    await _loadData(); // luôn nạp lại, vì nhãn có thể vừa được thêm trong form
  }

  Future<void> _openLabels() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LabelScreen()),
    );
    await _loadData(); // nhãn có thể đã đổi tên/màu/bị xóa
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
      appBar: AppBar(
        title: const Text('Lịch của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Quản lý nhãn',
            onPressed: _openLabels,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(child: Text('Chưa có sự kiện nào'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
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
                      setState(
                        () => _events.removeWhere((e) => e.id == event.id),
                      );
                      await DatabaseHelper.instance.deleteEvent(event.id!);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã xóa "${event.name}"')),
                      );
                    },
                    child: EventCard(
                      event: event,
                      label: _labelMap[event.labelId],
                      onTap: () => _openForm(event: event),
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
