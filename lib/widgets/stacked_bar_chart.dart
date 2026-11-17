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

// Biểu đồ cột chồng. Mọi thành phần đặt bằng vị trí tính sẵn trong một Stack.
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
  static const double _labelHeight = 36; // dải chữ dưới chân cột
  static const double _topPad = 10; // chừa chỗ cho số trên cùng của trục Y

  int? _selected; // cột đang được chạm

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gridColor = Colors.grey.withValues(alpha: 0.25);

    // Các vạch trên trục Y: 0, interval, 2*interval, ... đến maxY
    final ticks = <double>[];
    if (widget.interval > 0) {
      for (var v = 0.0; v <= widget.maxY + 0.0001; v += widget.interval) {
        ticks.add(v);
      }
    } else {
      ticks.add(0);
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
          width: double.infinity,
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, c) {
              final plotH = math.max(0.0, c.maxHeight - _labelHeight - _topPad);
              final plotW = math.max(0.0, c.maxWidth - _yAxisWidth);
              final n = widget.items.length;
              final slotW = n == 0 ? 0.0 : plotW / n;
              final barW = slotW * widget.barWidthFactor;

              // Chiều cao (pixel) ứng với giá trị v
              double h(double v) =>
                  widget.maxY <= 0 ? 0.0 : plotH * (v / widget.maxY);

              return Stack(
                children: [
                  // Vạch kẻ ngang và số trên trục Y
                  for (final v in ticks) ...[
                    Positioned(
                      left: _yAxisWidth,
                      right: 0,
                      bottom: _labelHeight + h(v),
                      height: 1,
                      child: ColoredBox(color: gridColor),
                    ),
                    Positioned(
                      left: 0,
                      width: _yAxisWidth - 6,
                      bottom: _labelHeight + h(v) - 8,
                      height: 16,
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
                  for (var i = 0; i < n; i++)
                    ..._bar(i, slotW, barW, h, scheme),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _bar(
    int i,
    double slotW,
    double barW,
    double Function(double) h,
    ColorScheme scheme,
  ) {
    final item = widget.items[i];
    final selected = _selected == i;
    final slotLeft = _yAxisWidth + i * slotW;
    final barLeft = slotLeft + (slotW - barW) / 2;
    final parts = <Widget>[];

    // Nền sáng nhẹ khi cột được chọn
    parts.add(
      Positioned(
        left: slotLeft,
        width: slotW,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );

    // Các đoạn màu xếp chồng từ đáy lên
    var acc = 0.0;
    for (var k = 0; k < item.segments.length; k++) {
      final seg = item.segments[k];
      final isTop = k == item.segments.length - 1;
      final segH = h(seg.value);
      if (segH > 0) {
        parts.add(
          Positioned(
            left: barLeft,
            width: barW,
            bottom: _labelHeight + h(acc),
            height: segH,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: isTop
                    ? const BorderRadius.vertical(top: Radius.circular(4))
                    : BorderRadius.zero,
                child: ColoredBox(color: seg.color),
              ),
            ),
          ),
        );
      }
      acc += seg.value;
    }

    // Chữ dưới chân cột
    parts.add(
      Positioned(
        left: slotLeft,
        width: slotW,
        bottom: 0,
        height: _labelHeight,
        child: IgnorePointer(
          child: Center(
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: item.isToday ? scheme.primary : Colors.grey[700],
                fontWeight: item.isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );

    // Vùng chạm phủ cả khe của cột (đặt trên cùng)
    parts.add(
      Positioned(
        left: slotLeft,
        width: slotW,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = selected ? null : i),
        ),
      ),
    );
    return parts;
  }
}
