import 'dart:math' as math;

import 'package:flutter/material.dart';

// Một đoạn màu trong cột (ứng với một nhãn)
class BarSegment {
  final double value;
  final Color color;

  const BarSegment(this.value, this.color);
}

// Một cột của biểu đồ (ứng với một ngày)
class BarItem {
  final String label; // chữ dưới chân cột (có thể rỗng)
  final List<BarSegment> segments; // xếp từ dưới lên
  final bool isToday;
  final String tooltip; // dòng chi tiết hiện khi chạm vào cột

  const BarItem({
    required this.label,
    required this.segments,
    required this.tooltip,
    this.isToday = false,
  });

  double get total => segments.fold(0.0, (s, e) => s + e.value);
}

// Biểu đồ cột chồng tự vẽ bằng widget cơ bản của Flutter
class StackedBarChart extends StatefulWidget {
  final List<BarItem> items;
  final double maxY; // giá trị lớn nhất của trục Y
  final double interval; // khoảng cách giữa các vạch kẻ ngang
  final double height; // chiều cao vùng vẽ (không tính dòng chi tiết)
  final double barWidthFactor; // độ rộng cột so với phần chia của nó (0 đến 1)

  const StackedBarChart({
    super.key,
    required this.items,
    required this.maxY,
    required this.interval,
    this.height = 240,
    this.barWidthFactor = 0.6,
  });

  @override
  State<StackedBarChart> createState() => _StackedBarChartState();
}

class _StackedBarChartState extends State<StackedBarChart> {
  static const double _yAxisWidth = 30;
  static const double _labelHeight = 36;

  int? _selected; // cột đang được chạm

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gridColor = Colors.grey.withValues(alpha: 0.25);

    // Các vạch trên trục Y: 0, interval, 2*interval, ... đến maxY
    final ticks = <double>[];
    for (var v = 0.0; v <= widget.maxY + 0.0001; v += widget.interval) {
      ticks.add(v);
    }

    final sel = _selected;
    final info = (sel == null || sel >= widget.items.length)
        ? 'Chạm vào một cột để xem chi tiết'
        : widget.items[sel].tooltip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dòng chi tiết của cột đang chọn
        Container(
          height: 32,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            info,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: sel == null ? FontWeight.normal : FontWeight.w600,
              color: sel == null ? Colors.grey[600] : null,
            ),
          ),
        ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Chiều cao vùng chứa các cột (trừ dải chữ phía dưới)
              final plotH = constraints.maxHeight - _labelHeight;

              return Stack(
                children: [
                  // Vạch kẻ ngang và số trên trục Y
                  for (final v in ticks) ...[
                    Positioned(
                      left: _yAxisWidth,
                      right: 0,
                      bottom: _labelHeight + plotH * (v / widget.maxY),
                      child: Container(height: 1, color: gridColor),
                    ),
                    Positioned(
                      left: 0,
                      width: _yAxisWidth - 6,
                      height: 16,
                      bottom: _labelHeight + plotH * (v / widget.maxY) - 8,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          v.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Các cột
                  Positioned(
                    left: _yAxisWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.items.length; i++)
                          Expanded(child: _buildColumn(i, plotH, scheme)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(int i, double plotH, ColorScheme scheme) {
    final item = widget.items[i];
    final selected = _selected == i;
    final barH = widget.maxY <= 0 ? 0.0 : plotH * (item.total / widget.maxY);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = selected ? null : i),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            // Vùng vẽ cột, cột dính đáy
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: barH <= 0
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        widthFactor: widget.barWidthFactor,
                        child: SizedBox(
                          height: barH,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            // Column xếp từ trên xuống nên đảo ngược để đoạn
                            // đầu tiên nằm dưới đáy cột
                            child: Column(
                              children: [
                                for (final seg in item.segments.reversed)
                                  Expanded(
                                    flex: math.max(
                                      1,
                                      (seg.value * 1000).round(),
                                    ),
                                    child: ColoredBox(color: seg.color),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            // Chữ dưới chân cột
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.isToday ? scheme.primary : Colors.grey[700],
                    fontWeight: item.isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
