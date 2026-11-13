import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/event_card.dart';

const int _filterAll = -1;
const int _filterNone = -2;

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int _labelFilter = _filterAll; // _filterAll, _filterNone hoặc id của nhãn
  int? _yearFilter; // null = tất cả các năm

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _labelFilter = _filterAll;
      _yearFilter = null;
    });
  }

  List<Event> _applyFilters(List<Event> all, int? year, int labelFilter) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (year != null && e.start.year != year) return false;
      if (labelFilter == _filterNone && e.labelId != null) return false;
      if (labelFilter > 0 && e.labelId != labelFilter) return false;
      if (q.isNotEmpty) {
        final text = '${e.name} ${e.location} ${e.organizer} ${e.note}'
            .toLowerCase();
        if (!text.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // Chèn tiêu đề ngày (DateTime) vào trước nhóm sự kiện của ngày đó
  List<Object> _buildItems(List<Event> events) {
    final items = <Object>[];
    DateTime? currentDay;
    for (final e in events) {
      final day = DateTime(e.start.year, e.start.month, e.start.day);
      if (currentDay != day) {
        items.add(day);
        currentDay = day;
      }
      items.add(e);
    }
    return items;
  }

  void _delete(Event event) {
    final data = context.read<AppData>();
    data.deleteEvent(event.id!);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${event.name}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => data.addEvent(event),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    final years = data.events.map((e) => e.start.year).toSet().toList()..sort();
    final yearValue = years.contains(_yearFilter) ? _yearFilter : null;
    final labelFilter =
        (_labelFilter > 0 && data.labels.every((l) => l.id != _labelFilter))
        ? _filterAll // nhãn đang lọc đã bị xóa
        : _labelFilter;

    final filtered = _applyFilters(data.events, yearValue, labelFilter);
    final items = _buildItems(filtered);
    final hasFilter =
        _query.trim().isNotEmpty ||
        yearValue != null ||
        labelFilter != _filterAll;

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ cái')),
      body: data.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Ô tìm kiếm + chọn năm
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tên, địa điểm, người tổ chức',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: yearValue,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tất cả năm'),
                          ),
                          for (final y in years)
                            DropdownMenuItem<int?>(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) => setState(() => _yearFilter = v),
                      ),
                    ],
                  ),
                ),

                // Chip lọc theo nhãn
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chipPadding(
                        ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: labelFilter == _filterAll,
                          onSelected: (_) =>
                              setState(() => _labelFilter = _filterAll),
                        ),
                      ),
                      for (final l in data.labels)
                        _chipPadding(
                          ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 6,
                              backgroundColor: l.colorValue,
                            ),
                            label: Text(l.name),
                            showCheckmark: false,
                            selectedColor: l.colorValue.withValues(alpha: 0.25),
                            selected: labelFilter == l.id,
                            onSelected: (_) =>
                                setState(() => _labelFilter = l.id!),
                          ),
                        ),
                      _chipPadding(
                        ChoiceChip(
                          label: const Text('Không nhãn'),
                          selected: labelFilter == _filterNone,
                          onSelected: (_) =>
                              setState(() => _labelFilter = _filterNone),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filtered.length} sự kiện',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
                ),

                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hasFilter
                                    ? 'Không tìm thấy sự kiện phù hợp'
                                    : 'Chưa có sự kiện nào\nBấm + để thêm',
                                textAlign: TextAlign.center,
                              ),
                              if (hasFilter)
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Xóa bộ lọc'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is DateTime) {
                              return _DayHeader(day: item);
                            }
                            final event = item as Event;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
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
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                onDismissed: (_) => _delete(event),
                                child: EventCard(
                                  event: event,
                                  label: data.labelOf(event),
                                  onTap: () =>
                                      openEventForm(context, event: event),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEventForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _chipPadding(Widget chip) =>
      Padding(padding: const EdgeInsets.only(right: 8), child: chip);
}

// Tiêu đề ngày kiểu "Th 2, 02/11/2026" như app của trường
class _DayHeader extends StatelessWidget {
  final DateTime day;

  const _DayHeader({required this.day});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isToday
                  ? '${formatDayHeader(day)} • Hôm nay'
                  : formatDayHeader(day),
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 8)),
        ],
      ),
    );
  }
}
