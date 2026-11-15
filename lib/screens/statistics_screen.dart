import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quan_ly_lich/providers/app_data.dart';
import 'package:quan_ly_lich/services/stats_service.dart';
import 'package:quan_ly_lich/utils/format.dart';
import 'package:quan_ly_lich/widgets/stacked_bar_chart.dart';

enum _Range { week, month }

enum _Metric { hours, count }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Thứ Hai đầu tuần chứa ngày d
DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _Range _range = _Range.week;
  _Metric _metric = _Metric.hours;
  DateTime _anchor = _dateOnly(
    DateTime.now(),
  ); // ngày xác định tuần/tháng đang xem

  DateTime get _from => _range == _Range.week
      ? _weekStart(_anchor)
      : DateTime(_anchor.year, _anchor.month, 1);

  DateTime get _to => _range == _Range.week
      ? DateTime(_from.year, _from.month, _from.day + 6)
      : DateTime(_anchor.year, _anchor.month + 1, 0);

  String get _rangeLabel => _range == _Range.week
      ? 'Tuần ${_dm(_from)} - ${_dm(_to)}/${_to.year}'
      : 'Tháng ${_anchor.month}/${_anchor.year}';

  void _shift(int dir) {
    setState(() {
      _anchor = _range == _Range.week
          ? DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir)
          : DateTime(_anchor.year, _anchor.month + dir, 1);
    });
  }

  // Dựng biểu đồ cột chồng từ số liệu đã tính
  Widget _buildChart(
    PeriodStats stats,
    List<int?> order,
    Color Function(int?) colorOf,
  ) {
    final isHours = _metric == _Metric.hours;
    final isWeek = _range == _Range.week;
    final today = _dateOnly(DateTime.now());

    // Tổng mỗi ngày (chiều cao cột) và trục Y gọn số nguyên
    final totals = [
      for (final d in stats.days)
        isHours ? d.minutes / 60.0 : d.count.toDouble(),
    ];
    final rawMax = totals.fold<double>(0, (a, b) => math.max(a, b));
    final interval = math.max(1, (rawMax / 4).ceil()).toDouble();
    final maxY = math.max(interval, (rawMax / interval).ceil() * interval);

    final items = <BarItem>[];
    for (final d in stats.days) {
      // Mỗi nhãn có mặt trong ngày là một đoạn màu
      final segments = <BarSegment>[];
      for (final id in order) {
        final v = isHours
            ? (d.minutesByLabel[id] ?? 0) / 60.0
            : (d.countByLabel[id] ?? 0).toDouble();
        if (v > 0) segments.add(BarSegment(v, colorOf(id)));
      }

      // Tuần: ghi thứ và ngày. Tháng: chỉ ghi ngày 1, 5, 10, 15...
      final String label;
      if (isWeek) {
        label = '${formatWeekday(d.day)}\n${d.day.day}';
      } else {
        label = (d.day.day == 1 || d.day.day % 5 == 0) ? '${d.day.day}' : '';
      }

      items.add(
        BarItem(
          label: label,
          segments: segments,
          isToday: d.day == today,
          tooltip:
              '${formatDayHeader(d.day)}: ${d.minutes == 0 ? '0 giờ' : formatDuration(d.minutes)} • ${d.count} việc',
        ),
      );
    }

    return StackedBarChart(
      // Đổi kỳ hoặc đơn vị thì tạo lại biểu đồ (bỏ chọn cột cũ)
      key: ValueKey(
        '${_range.name}-${_from.millisecondsSinceEpoch}-${_metric.name}',
      ),
      items: items,
      maxY: maxY,
      interval: interval,
      height: 240,
      barWidthFactor: isWeek ? 0.55 : 0.7,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    final colorById = <int?, Color>{
      for (final l in data.labels) l.id: l.colorValue,
    };
    Color colorOf(int? id) => colorById[id] ?? Colors.grey;
    // Thứ tự xếp chồng: theo thứ tự nhãn, "không nhãn" ở trên cùng
    final order = <int?>[for (final l in data.labels) l.id, null];

    final stats = computeStats(data.events, _from, _to);
    final periodWord = _range == _Range.week ? 'tuần' : 'tháng';
    final busiest = stats.busiestDay;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Về hôm nay',
            onPressed: () =>
                setState(() => _anchor = _dateOnly(DateTime.now())),
          ),
        ],
      ),
      body: data.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Tuần / Tháng
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_Range>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _Range.week, label: Text('Tuần')),
                        ButtonSegment(
                          value: _Range.month,
                          label: Text('Tháng'),
                        ),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) =>
                          setState(() => _range = s.first),
                    ),
                  ),
                ),

                // Mũi tên chuyển kỳ
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Kỳ trước',
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _rangeLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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

                // Số giờ / Số việc
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<_Metric>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _Metric.hours,
                          label: Text('Số giờ'),
                        ),
                        ButtonSegment(
                          value: _Metric.count,
                          label: Text('Số việc'),
                        ),
                      ],
                      selected: {_metric},
                      onSelectionChanged: (s) =>
                          setState(() => _metric = s.first),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tóm tắt
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.event_note,
                          title: 'Số việc',
                          value: '${stats.totalCount}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.schedule,
                          title: 'Tổng thời gian',
                          value: stats.totalMinutes == 0
                              ? '0'
                              : formatDuration(stats.totalMinutes),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.local_fire_department_outlined,
                          title: 'Bận nhất',
                          value: busiest == null
                              ? '-'
                              : '${formatWeekday(busiest.day)} ${_dm(busiest.day)}',
                        ),
                      ),
                    ],
                  ),
                ),

                if (stats.totalCount == 0)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có sự kiện nào trong $periodWord này',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Biểu đồ
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(
                              _metric == _Metric.hours
                                  ? 'Số giờ mỗi ngày'
                                  : 'Số việc mỗi ngày',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildChart(stats, order, colorOf),
                        ],
                      ),
                    ),
                  ),

                  // Phân bổ theo nhãn
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Theo nhãn',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final id in order)
                    if (stats.byLabel[id] != null)
                      _LabelRow(
                        name: id == null
                            ? 'Không nhãn'
                            : data.labels.firstWhere((l) => l.id == id).name,
                        color: colorOf(id),
                        total: stats.byLabel[id]!,
                        fraction: _metric == _Metric.hours
                            ? stats.byLabel[id]!.minutes /
                                  math.max(1, stats.totalMinutes)
                            : stats.byLabel[id]!.count /
                                  math.max(1, stats.totalCount),
                      ),
                ],
              ],
            ),
    );
  }
}

// Ô số liệu tóm tắt
class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Một dòng phân bổ theo nhãn: chấm màu, tên, phần trăm, thanh tỉ lệ
class _LabelRow extends StatelessWidget {
  final String name;
  final Color color;
  final LabelTotal total;
  final double fraction;

  const _LabelRow({
    required this.name,
    required this.color,
    required this.total,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDuration(total.minutes)} • ${total.count} việc',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
