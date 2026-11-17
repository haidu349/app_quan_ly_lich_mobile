import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/event_actions.dart';
import 'package:quan_ly_lich/widgets/day_header.dart';
import 'package:quan_ly_lich/widgets/event_tile.dart';

const int _filterAll = -1;
const int _filterNone = -2;

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  static const Key _centerKey = Key('ledger_upcoming');

  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  int _labelFilter = _filterAll; // _filterAll, _filterNone hoặc id của nhãn
  int? _yearFilter; // null = tất cả các năm
  bool _hidePast = false; // ẩn lịch đã qua

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
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

  void _goToToday() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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

  Widget _buildItem(Object item) {
    if (item is DateTime) return DayHeader(day: item);
    return EventTile(event: item as Event);
  }

  Widget _chipPadding(Widget chip) =>
      Padding(padding: const EdgeInsets.only(right: 8), child: chip);

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

    // Tách thành "đã qua" (trước hôm nay) và "sắp tới" (từ hôm nay trở đi)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final split = items.indexWhere((x) => x is DateTime && !x.isBefore(today));
    final splitAt = split == -1 ? items.length : split;
    final past = items.sublist(0, splitAt);
    final upcoming = items.sublist(splitAt);
    // Phần trên điểm giữa được bày ngược: phần tử đầu nằm sát điểm giữa nhất
    final pastReversed = past.reversed.toList();

    final shownCount = _hidePast
        ? upcoming.whereType<Event>().length
        : filtered.length;
    final hasFilter =
        _query.trim().isNotEmpty ||
        yearValue != null ||
        labelFilter != _filterAll;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ cái'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Về hôm nay',
            onPressed: _goToToday,
          ),
        ],
      ),
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

                // Chip: ẩn lịch đã qua + lọc theo nhãn
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chipPadding(
                        FilterChip(
                          avatar: const Icon(Icons.history, size: 18),
                          label: const Text('Ẩn lịch đã qua'),
                          selected: _hidePast,
                          onSelected: (v) => setState(() => _hidePast = v),
                        ),
                      ),
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
                      '$shownCount sự kiện',
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
                      : CustomScrollView(
                          controller: _scroll,
                          center: _centerKey,
                          slivers: [
                            // Lịch đã qua: nằm phía trên điểm 0, kéo xuống để xem
                            if (!_hidePast && pastReversed.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _buildItem(pastReversed[i]),
                                  childCount: pastReversed.length,
                                ),
                              ),
                            // Lịch từ hôm nay trở đi: màn hình mở ra ở đây
                            if (upcoming.isEmpty)
                              const SliverToBoxAdapter(
                                key: _centerKey,
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text('Không có lịch sắp tới'),
                                  ),
                                ),
                              )
                            else
                              SliverList(
                                key: _centerKey,
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _buildItem(upcoming[i]),
                                  childCount: upcoming.length,
                                ),
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 88),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ledger_fab',
        onPressed: () => openEventForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
