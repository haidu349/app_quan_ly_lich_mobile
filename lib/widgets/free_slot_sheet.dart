import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/free_slot_service.dart';
import 'package:quan_ly_lich/utils/format.dart';

enum _Range { week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _hm(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay % 60).toString().padLeft(2, '0')}';

// Mở bảng gợi ý. Trả về khoảng trống người dùng chọn (hoặc null nếu đóng bảng).
Future<FreeSlot?> showFreeSlotSheet(
  BuildContext context, {
  required DateTime initialDay,
  required int durationMinutes,
  int? ignoreEventId,
}) {
  return showModalBottomSheet<FreeSlot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _FreeSlotSheet(
        initialDay: initialDay,
        durationMinutes: durationMinutes,
        ignoreEventId: ignoreEventId,
      ),
    ),
  );
}

class _FreeSlotSheet extends StatefulWidget {
  final DateTime initialDay;
  final int durationMinutes;
  final int? ignoreEventId;

  const _FreeSlotSheet({
    required this.initialDay,
    required this.durationMinutes,
    this.ignoreEventId,
  });

  @override
  State<_FreeSlotSheet> createState() => _FreeSlotSheetState();
}

class _FreeSlotSheetState extends State<_FreeSlotSheet> {
  _Range _range = _Range.week;
  late DateTime _anchor; // ngày dùng để xác định tuần/tháng đang xem
  bool _onlyFreeDays = false;

  DateTime get _today => _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    final d = _dateOnly(widget.initialDay);
    _anchor = d.isBefore(_today) ? _today : d;
  }

  DateTime get _from => _range == _Range.week
      ? _weekStart(_anchor)
      : DateTime(_anchor.year, _anchor.month, 1);

  DateTime get _to => _range == _Range.week
      ? DateTime(_from.year, _from.month, _from.day + 6)
      : DateTime(_anchor.year, _anchor.month + 1, 0);

  // Chỉ cho lùi khi kỳ trước còn có ngày chưa qua
  bool get _canGoPrev => _from.isAfter(_today);

  void _shift(int dir) {
    setState(() {
      _anchor = _range == _Range.week
          ? DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir)
          : DateTime(_anchor.year, _anchor.month + dir, 1);
    });
  }

  String get _rangeLabel => _range == _Range.week
      ? 'Tuần ${_dm(_from)} - ${_dm(_to)}/${_to.year}'
      : 'Tháng ${_anchor.month}/${_anchor.year}';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final textTheme = Theme.of(context).textTheme;

    final all = availabilityForRange(
      _from,
      _to,
      data.events,
      durationMinutes: widget.durationMinutes,
      ignoreEventId: widget.ignoreEventId,
    );
    final withSlots = all.where((a) => a.slots.isNotEmpty).toList();
    final shown = _onlyFreeDays
        ? withSlots.where((a) => a.entirelyFree).toList()
        : withSlots;
    final fullDays = all.length - withSlots.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi ý thời gian trống',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cần ${formatDuration(widget.durationMinutes)} • giờ làm việc ${_hm(kWorkStartMinute)} - ${_hm(kWorkEndMinute)}',
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Range>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Range.week, label: Text('Tuần')),
                ButtonSegment(value: _Range.month, label: Text('Tháng')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Kỳ trước',
              onPressed: _canGoPrev ? () => _shift(-1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _rangeLabel,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Kỳ sau',
              onPressed: () => _shift(1),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Chỉ ngày trống hoàn toàn'),
              selected: _onlyFreeDays,
              onSelected: (v) => setState(() => _onlyFreeDays = v),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _onlyFreeDays
                          ? 'Không có ngày nào trống hoàn toàn trong kỳ này.\nThử tắt bộ lọc hoặc chuyển sang kỳ khác.'
                          : 'Không còn khoảng trống đủ ${formatDuration(widget.durationMinutes)} trong kỳ này.\nThử chuyển sang tuần hoặc tháng khác.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final a = shown[index];
                    return _DayCard(
                      availability: a,
                      isToday: a.day == _today,
                      onPick: (slot) => Navigator.pop(context, slot),
                    );
                  },
                ),
        ),
        if (fullDays > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '$fullDays ngày đã kín lịch hoặc không đủ chỗ trống nên không hiển thị',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}

// Thẻ một ngày: tên ngày, tình trạng, các khoảng trống bấm được
class _DayCard extends StatelessWidget {
  final DayAvailability availability;
  final bool isToday;
  final ValueChanged<FreeSlot> onPick;

  const _DayCard({
    required this.availability,
    required this.isToday,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final a = availability;
    final textTheme = Theme.of(context).textTheme;
    const green = Color(0xFF2E7D32);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isToday
                        ? '${formatDayHeader(a.day)} • Hôm nay'
                        : formatDayHeader(a.day),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  a.entirelyFree
                      ? 'Trống cả ngày'
                      : 'Đã có ${a.eventCount} việc',
                  style: textTheme.labelMedium?.copyWith(
                    color: a.entirelyFree ? green : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in a.slots)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      '${formatTime(slot.start)} - ${formatTime(slot.end)}',
                    ),
                    onPressed: () => onPick(slot),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
