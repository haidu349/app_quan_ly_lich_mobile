import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/screens/move_event_screen.dart';
import 'package:quan_ly_lich/services/bulk_reschedule_service.dart';
import 'package:quan_ly_lich/utils/format.dart';

const int _filterAll = -2;
const int _filterNone = -1;
const Color _orange = Color(0xFFE65100);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Màn hình dời nhiều buổi cùng lúc (ví dụ nghỉ lễ dài ngày)
class BulkRescheduleScreen extends StatefulWidget {
  const BulkRescheduleScreen({super.key});

  @override
  State<BulkRescheduleScreen> createState() => _BulkRescheduleScreenState();
}

class _BulkRescheduleScreenState extends State<BulkRescheduleScreen> {
  late DateTimeRange _range;
  int _labelFilter = _filterAll;
  BulkMode _mode = BulkMode.shift;

  // Chế độ "dời cả chuỗi"
  int _amount = 1;
  bool _weeks = true; // true = tuần, false = ngày
  int _direction = 1; // 1 = lùi về sau, -1 = dời sớm lên

  final Set<int> _skipped = {}; // buổi bỏ tick: giữ nguyên chỗ cũ
  final Map<int, ({DateTime start, DateTime end})> _manual = {};
  bool _saving = false;

  int get _days => _direction * _amount * (_weeks ? 7 : 1);

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _range = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 6)),
    );
  }

  // Đổi bất kỳ lựa chọn nào thì kết quả cũ không còn đúng nữa
  void _change(VoidCallback fn) {
    setState(() {
      fn();
      _skipped.clear();
      _manual.clear();
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: 'Chọn khoảng ngày cần dời',
    );
    if (picked == null || !mounted) return;
    _change(() => _range = picked);
  }

  // Các buổi nằm trong khoảng ngày và bộ lọc nhãn (chưa tính bỏ tick)
  List<Event> _selection(List<Event> events) {
    bool Function(Event)? where;
    if (_labelFilter == _filterNone) {
      where = (e) => e.labelId == null;
    } else if (_labelFilter != _filterAll) {
      where = (e) => e.labelId == _labelFilter;
    }
    return selectInRange(
      events,
      _range.start,
      _range.end,
      where: where,
      now: DateTime.now(),
    );
  }

  List<BulkMove> _buildPlan(List<Event> active, List<Event> all) {
    var plan = _mode == BulkMode.shift
        ? planShift(active, all, days: _days)
        : planMakeUp(active, all);
    if (_manual.isNotEmpty) plan = overrideMoves(plan, _manual, all);
    return plan;
  }

  Future<void> _edit(BulkMove m, List<BulkMove> plan, AppData data) async {
    final id = m.original.id!;
    final result = await showMoveEventScreen(
      context,
      title: m.original.name,
      color: data.labelOf(m.original)?.colorValue ?? Colors.grey,
      start: m.moved.start,
      end: m.moved.end,
      ignoreEventIds: {for (final x in plan) x.original.id!},
      extraEvents: [
        for (final x in plan)
          if (x.original.id != id) x.moved,
      ],
    );
    if (result == null || !mounted) return;
    setState(() => _manual[id] = (start: result.start, end: result.end));
  }

  Future<void> _apply(List<BulkMove> plan) async {
    final conflicts = plan.where((m) => m.hasConflict).length;
    if (conflicts > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber, color: _orange, size: 32),
          title: const Text('Còn buổi bị trùng lịch'),
          content: Text('$conflicts buổi sẽ trùng giờ với lịch khác. Vẫn dời?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Xem lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vẫn dời'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final data = context.read<AppData>();
    final messenger = ScaffoldMessenger.of(context);
    final originals = [for (final m in plan) m.original];
    setState(() => _saving = true);
    await data.updateEvents([for (final m in plan) m.moved]);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Đã dời ${plan.length} buổi'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => data.updateEvents(originals),
          ),
        ),
      );
    if (mounted) Navigator.pop(context);
  }

  Widget _controls(AppData data) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khoảng ngày cần dời', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${formatDate(_range.start)}  -  ${formatDate(_range.end)}',
            ),
          ),
          const SizedBox(height: 12),
          Text('Chỉ dời lịch thuộc nhãn', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _labelFilter == _filterAll,
                onSelected: (_) => _change(() => _labelFilter = _filterAll),
              ),
              ChoiceChip(
                label: const Text('Không nhãn'),
                selected: _labelFilter == _filterNone,
                onSelected: (_) => _change(() => _labelFilter = _filterNone),
              ),
              for (final l in data.labels)
                ChoiceChip(
                  label: Text(l.name),
                  selectedColor: l.colorValue.withValues(alpha: 0.25),
                  selected: _labelFilter == l.id,
                  onSelected: (_) => _change(() => _labelFilter = l.id!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Cách dời', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<BulkMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BulkMode.shift, label: Text('Dời cả chuỗi')),
              ButtonSegment(
                value: BulkMode.makeUp,
                label: Text('Dạy bù cuối chuỗi'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _change(() => _mode = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _mode == BulkMode.shift
                ? 'Mọi buổi trong khoảng ngày được dời cùng một khoảng, giữ nguyên thứ và giờ.'
                : 'Các buổi trong khoảng ngày được xếp vào sau buổi cuối của cùng một lớp (cùng tên, cùng nhãn), đúng thứ và giờ cũ.',
            style: textTheme.bodySmall,
          ),
          if (_mode == BulkMode.shift) ...[
            const SizedBox(height: 12),
            _shiftControls(),
          ],
        ],
      ),
    );
  }

  Widget _shiftControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 1, label: Text('Lùi sau')),
            ButtonSegment(value: -1, label: Text('Sớm lên')),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => _change(() => _direction = s.first),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.remove),
              tooltip: 'Giảm',
              onPressed: _amount > 1 ? () => _change(() => _amount--) : null,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$_amount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.outlined(
              icon: const Icon(Icons.add),
              tooltip: 'Tăng',
              onPressed: _amount < 99 ? () => _change(() => _amount++) : null,
            ),
          ],
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: true, label: Text('Tuần')),
            ButtonSegment(value: false, label: Text('Ngày')),
          ],
          selected: {_weeks},
          onSelectionChanged: (s) => _change(() => _weeks = s.first),
        ),
      ],
    );
  }

  Widget _row(Event e, BulkMove? move, List<BulkMove> plan, AppData data) {
    final id = e.id!;
    final skipped = move == null;
    final textTheme = Theme.of(context).textTheme;
    final color = data.labelOf(e)?.colorValue ?? Colors.grey;

    String when(DateTime s, DateTime en) =>
        '${formatDayHeader(s)}  ${formatTimeRange(s, en)}';

    return ListTile(
      leading: Checkbox(
        value: !skipped,
        onChanged: (v) => setState(() {
          if (v == true) {
            _skipped.remove(id);
          } else {
            _skipped.add(id);
            _manual.remove(id);
          }
        }),
      ),
      title: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            color: color,
          ),
          Expanded(
            child: Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skipped
                  ? textTheme.bodyLarge?.copyWith(color: Colors.grey)
                  : null,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            when(e.start, e.end),
            style: TextStyle(
              decoration: skipped ? null : TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
          if (skipped)
            const Text('Giữ nguyên', style: TextStyle(color: Colors.grey))
          else ...[
            Text(
              '→ ${when(move.moved.start, move.moved.end)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: move.hasConflict ? _orange : null,
              ),
            ),
            if (move.hasConflict)
              Text(
                'Trùng: ${move.conflicts.map((c) => c.name).take(2).join(', ')}'
                '${move.conflicts.length > 2 ? '...' : ''}',
                style: const TextStyle(color: _orange),
              ),
          ],
        ],
      ),
      trailing: skipped
          ? null
          : IconButton(
              icon: const Icon(Icons.edit_calendar),
              tooltip: 'Chọn giờ khác cho buổi này',
              onPressed: () => _edit(move, plan, data),
            ),
      onTap: skipped ? null : () => _edit(move, plan, data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final selection = _selection(data.events);
    final active = [
      for (final e in selection)
        if (!_skipped.contains(e.id)) e,
    ];
    final plan = _buildPlan(active, data.events);
    final byId = {for (final m in plan) m.original.id!: m};
    final conflicts = plan.where((m) => m.hasConflict).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dời lịch hàng loạt')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _controls(data)),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                selection.isEmpty
                    ? 'Không có buổi nào trong khoảng này'
                    : '${plan.length}/${selection.length} buổi sẽ được dời'
                          '${conflicts > 0 ? ' - $conflicts buổi trùng lịch' : ''}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: conflicts > 0 ? _orange : null),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: selection.length,
            itemBuilder: (context, i) {
              final e = selection[i];
              return _row(e, byId[e.id], plan, data);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: plan.isEmpty || _saving ? null : () => _apply(plan),
            icon: const Icon(Icons.event_repeat),
            label: Text(plan.isEmpty ? 'Dời lịch' : 'Dời ${plan.length} buổi'),
          ),
        ),
      ),
    );
  }
}
