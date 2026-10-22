import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';
import 'models.dart';

/// Single-series bar chart of daily focus minutes with an optional dashed
/// goal line. Tap or drag across the bars to select a day.
class FocusBarChart extends StatelessWidget {
  const FocusBarChart({
    super.key,
    required this.data,
    required this.selectedIndex,
    required this.onSelect,
    required this.xLabel,
    required this.yLabel,
    this.goalMinutes,
    this.goalLabel,
    this.height = 220,
  });

  final List<DayStat> data;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final String Function(int index, DayStat stat) xLabel;
  final String Function(int minutes) yLabel;
  final int? goalMinutes;
  final String? goalLabel;
  final double height;

  static const _leftPad = 44.0;
  static const _bottomPad = 24.0;
  static const _topPad = 12.0;

  void _select(Offset local, double width) {
    if (data.isEmpty) return;
    final slot = (width - _leftPad) / data.length;
    final index = ((local.dx - _leftPad) / slot).floor();
    onSelect(index.clamp(0, data.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition, width),
            onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
            child: CustomPaint(
              size: Size(width, height),
              painter: _BarChartPainter(
                data: data,
                selectedIndex: selectedIndex,
                xLabel: xLabel,
                yLabel: yLabel,
                goalMinutes: goalMinutes,
                goalLabel: goalLabel,
                textStyle: Theme.of(context).textTheme.labelSmall!,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.xLabel,
    required this.yLabel,
    required this.goalMinutes,
    required this.goalLabel,
    required this.textStyle,
  });

  final List<DayStat> data;
  final int? selectedIndex;
  final String Function(int index, DayStat stat) xLabel;
  final String Function(int minutes) yLabel;
  final int? goalMinutes;
  final String? goalLabel;
  final TextStyle textStyle;

  static int _niceStep(int maxValue) {
    const steps = [5, 10, 15, 30, 60, 90, 120, 180, 240, 360, 480, 600];
    for (final s in steps) {
      if (maxValue / s <= 4) return s;
    }
    return 720;
  }

  TextPainter _text(String text, Color color, {FontWeight? weight}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = FocusBarChart._leftPad;
    const bottom = FocusBarChart._bottomPad;
    const top = FocusBarChart._topPad;
    final plotW = size.width - left;
    final plotH = size.height - bottom - top;
    final baseY = top + plotH;

    final dataMax = data.fold<int>(0, (m, d) => math.max(m, d.minutes));
    final peak = math.max(math.max(dataMax, goalMinutes ?? 0), 30);
    final step = _niceStep(peak);
    final yMax = ((peak / step).ceil() * step).toDouble();
    double yOf(num minutes) => baseY - (minutes / yMax) * plotH;

    // Recessive grid + y labels.
    final grid = Paint()
      ..color = Brand.chartGrid
      ..strokeWidth = 1;
    for (var v = 0; v <= yMax; v += step) {
      final y = yOf(v);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final label = _text(v == 0 ? '0' : yLabel(v), Brand.textMuted);
      label.paint(canvas, Offset(left - label.width - 8, y - label.height / 2));
    }

    if (data.isEmpty) return;

    // Bars: rounded data-end, square baseline, >= 2px gap between bars.
    final slot = plotW / data.length;
    final barW = math.min(slot - math.max(2, slot * 0.28), 28.0);
    final labelEvery = data.length <= 7 ? 1 : (data.length / 6).ceil();

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = left + slot * i + slot / 2;
      final selected = i == selectedIndex;

      if (d.minutes > 0) {
        final h = math.max(baseY - yOf(d.minutes), 3.0);
        final r = math.min(4.0, barW / 2);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, baseY - h, barW, h),
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = selected ? Brand.chartBarSelected : Brand.chartBar,
        );
      }

      if (selected) {
        canvas.drawLine(
          Offset(cx, top),
          Offset(cx, baseY),
          Paint()
            ..color = Brand.textMuted.withAlpha(60)
            ..strokeWidth = 1,
        );
      }

      final isLast = i == data.length - 1;
      if (i % labelEvery == 0 || isLast || selected) {
        // Skip a periodic label that would collide with the last one.
        if (!isLast && !selected && data.length - 1 - i < labelEvery / 2) {
          continue;
        }
        final label = _text(
          xLabel(i, d),
          selected ? Brand.textPrimary : Brand.textMuted,
          weight: selected ? FontWeight.w700 : null,
        );
        final x = (cx - label.width / 2)
            .clamp(left - 4, size.width - label.width)
            .toDouble();
        label.paint(canvas, Offset(x, baseY + 6));
      }
    }

    // Dashed goal line with a direct label.
    final goal = goalMinutes;
    if (goal != null && goal > 0) {
      final y = yOf(goal);
      final dash = Paint()
        ..color = Brand.textSecondary
        ..strokeWidth = 1.5;
      for (var x = left; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          dash,
        );
      }
      if (goalLabel != null) {
        final label = _text(goalLabel!, Brand.textSecondary);
        final bg = Rect.fromLTWH(
          size.width - label.width - 8,
          y - label.height - 4,
          label.width + 8,
          label.height + 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, const Radius.circular(4)),
          Paint()..color = Brand.surface,
        );
        label.paint(canvas, Offset(bg.left + 4, bg.top + 1));
      }
    }

    canvas.drawLine(
      Offset(left, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = Brand.textMuted.withAlpha(80)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data ||
      old.selectedIndex != selectedIndex ||
      old.goalMinutes != goalMinutes ||
      old.goalLabel != goalLabel;
}

/// The large progress ring on the timer screen.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 260,
  });

  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(value),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withAlpha(45),
    );

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );

    // Leading dot, echoing the emblem.
    final angle = -math.pi / 2 + sweep;
    final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(dot, stroke * 0.95, Paint()..color = Brand.cyan);
    canvas.drawCircle(dot, stroke * 0.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Brand.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Brand.cyan),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.range,
    required this.onChanged,
    this.step = 1,
    this.color,
  });

  final String label;
  final String valueLabel;
  final int value;
  final IntRange range;
  final int step;
  final Color? color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          IconButton(
            onPressed: value > range.min
                ? () => onChanged((value - step).clamp(range.min, range.max))
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 72,
            child: Text(
              valueLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: value < range.max
                ? () => onChanged((value + step).clamp(range.min, range.max))
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// GitHub-style calendar of focus minutes: one column per week (Monday on
/// top), one sequential hue whose intensity follows the daily goal.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.days,
    required this.goalMinutes,
    required this.rowLabels,
    required this.tooltip,
    required this.lessLabel,
    required this.moreLabel,
  });

  /// Consecutive days starting on a Monday and ending today.
  final List<DayStat> days;
  final int goalMinutes;

  /// Seven weekday labels, Monday first; only Mon/Wed/Fri are shown.
  final List<String> rowLabels;
  final String Function(DayStat stat) tooltip;
  final String lessLabel;
  final String moreLabel;

  static const _levels = [0.0, 0.3, 0.55, 0.8, 1.0];

  static Color colorFor(int level) => level == 0
      ? Brand.surfaceHigh
      : Color.lerp(Brand.surfaceHigh, Brand.chartBar, _levels[level])!;

  int _level(int minutes) {
    if (minutes <= 0) return 0;
    final ratio = goalMinutes <= 0 ? 1.0 : minutes / goalMinutes;
    if (ratio < 0.25) return 1;
    if (ratio < 0.5) return 2;
    if (ratio < 1) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = (days.length / 7).ceil();
    const gap = 3.0;
    const labelWidth = 30.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            ((constraints.maxWidth - labelWidth) / weeks - gap).clamp(6.0, 22.0);
        Widget square(Color color) => Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: [
                      for (var r = 0; r < 7; r++)
                        SizedBox(
                          height: cell + gap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              r.isEven && r < 6 ? rowLabels[r] : '',
                              style: const TextStyle(
                                color: Brand.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var w = 0; w < weeks; w++)
                  Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Column(
                      children: [
                        for (var r = 0; r < 7; r++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: () {
                              final i = w * 7 + r;
                              if (i >= days.length) {
                                return SizedBox.square(dimension: cell);
                              }
                              final d = days[i];
                              return Tooltip(
                                message: tooltip(d),
                                triggerMode: TooltipTriggerMode.tap,
                                child: square(colorFor(_level(d.minutes))),
                              );
                            }(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  lessLabel,
                  style: const TextStyle(color: Brand.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 6),
                for (var l = 0; l < _levels.length; l++)
                  Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: colorFor(l),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(width: 3),
                Text(
                  moreLabel,
                  style: const TextStyle(color: Brand.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
