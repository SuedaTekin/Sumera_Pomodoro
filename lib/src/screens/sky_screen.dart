import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../achievements.dart';
import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'share_card.dart';

/// "My sky": every completed focus session becomes a star; the sessions of
/// one day form that day's constellation.
class SkyScreen extends StatefulWidget {
  const SkyScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _month;
  int? _selectedDay;
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = now.day;
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  /// Shimmer only while today's stars are on screen; it costs frames.
  void _syncTwinkle(bool hasTodayStars) {
    if (hasTodayStars && !_twinkle.isAnimating) {
      _twinkle.repeat();
    } else if (!hasTodayStars && _twinkle.isAnimating) {
      _twinkle.stop();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final now = DateTime.now();
        final isCurrentMonth =
            _month.year == now.year && _month.month == now.month;
        final sessions = c.focusSessionsInMonth(_month);
        _syncTwinkle(
          isCurrentMonth && sessions.any((r) => r.completedAt.day == now.day),
        );
        final minutes = sessions.fold(0, (s, r) => s + r.minutes);
        final loc = MaterialLocalizations.of(context);

        final selected =
            _selectedDay == null
                ? const <SessionRecord>[]
                : sessions
                    .where((r) => r.completedAt.day == _selectedDay)
                    .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('skyTitle')),
            actions: [
              if (c.remoteConfig.feature('share'))
                IconButton(
                  onPressed: () => showShareCard(context, c),
                  tooltip: context.tr('shareProgress'),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    tooltip: loc.previousMonthTooltip,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      loc.formatMonthYear(_month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                    tooltip: loc.nextMonthTooltip,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final rows = _rowsFor(_month);
                    final size = Size(
                      box.maxWidth,
                      box.maxWidth / 7 * rows * 1.1,
                    );
                    return GestureDetector(
                      onTapDown: (d) {
                        final day = _dayAt(d.localPosition, size, _month);
                        if (day != null) setState(() => _selectedDay = day);
                      },
                      child: Semantics(
                        label:
                            '${loc.formatMonthYear(_month)}: '
                            '${sessions.length} ${context.tr('stars')}',
                        child: AnimatedBuilder(
                          animation: _twinkle,
                          builder:
                              (context, _) => CustomPaint(
                                size: size,
                                painter: SkyPainter(
                                  month: _month,
                                  sessions: sessions,
                                  selectedDay: _selectedDay,
                                  today: isCurrentMonth ? now.day : null,
                                  twinkle: _twinkle.value,
                                  labelStyle:
                                      Theme.of(context).textTheme.labelSmall!,
                                ),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _Readout(
                title:
                    _selectedDay == null
                        ? loc.formatMonthYear(_month)
                        : loc.formatMediumDate(
                          DateTime(_month.year, _month.month, _selectedDay!),
                        ),
                stars: _selectedDay == null ? sessions.length : selected.length,
                minutes:
                    _selectedDay == null
                        ? minutes
                        : selected.fold(0, (s, r) => s + r.minutes),
              ),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    context.tr('skyEmpty'),
                    style: const TextStyle(color: Brand.textSecondary),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: context.tr('totalStars'),
                      value: '${c.totalPomodoros}',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: context.tr('achievements'),
                      value:
                          '${achievements.where(c.isUnlocked).length}'
                          ' / ${achievements.length}',
                      icon: Icons.military_tech_rounded,
                    ),
                  ),
                ],
              ),
              if (c.remoteConfig.feature('achievements')) ...[
                const SizedBox(height: 20),
                SectionHeader(context.tr('achievements')),
                _AchievementGrid(controller: c),
              ],
            ],
          ),
        );
      },
    );
  }
}

int _rowsFor(DateTime month) {
  final offset = DateTime(month.year, month.month, 1).weekday - 1;
  final days = DateTime(month.year, month.month + 1, 0).day;
  return ((offset + days) / 7).ceil();
}

int? _dayAt(Offset p, Size size, DateTime month) {
  final rows = _rowsFor(month);
  final col = (p.dx / (size.width / 7)).floor();
  final row = (p.dy / (size.height / rows)).floor();
  final offset = DateTime(month.year, month.month, 1).weekday - 1;
  final day = row * 7 + col - offset + 1;
  final days = DateTime(month.year, month.month + 1, 0).day;
  return day >= 1 && day <= days ? day : null;
}

/// FNV-1a; stable across runs and platforms (unlike String.hashCode).
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h;
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.month,
    required this.sessions,
    required this.twinkle,
    required this.labelStyle,
    this.selectedDay,
    this.today,
  });

  final DateTime month;
  final List<SessionRecord> sessions;
  final int? selectedDay;
  final int? today;

  /// 0..1, drives the shimmer of today's stars.
  final double twinkle;
  final TextStyle labelStyle;

  static const _starColors = [Colors.white, Brand.cyan, Color(0xFFB9B4FF)];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0B1D), Color(0xFF1B1446), Color(0xFF2A1C5C)],
        ).createShader(rect),
    );

    // Faint background field, fixed per month.
    final rnd = math.Random(month.year * 12 + month.month);
    final dust = Paint()..color = Colors.white.withAlpha(50);
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.9 + 0.2,
        dust,
      );
    }

    final rows = _rowsFor(month);
    final cw = size.width / 7;
    final ch = size.height / rows;
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;

    Rect cellOf(int day) {
      final i = day - 1 + offset;
      return Rect.fromLTWH((i % 7) * cw, (i ~/ 7) * ch, cw, ch);
    }

    final selected = selectedDay;
    if (selected != null && selected <= days) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          cellOf(selected).deflate(3),
          const Radius.circular(10),
        ),
        Paint()..color = Colors.white.withAlpha(18),
      );
    }

    for (var day = 1; day <= days; day++) {
      final cell = cellOf(day);
      final isToday = day == today;
      final label = TextPainter(
        text: TextSpan(
          text: '$day',
          style: labelStyle.copyWith(
            fontSize: 9,
            color: Colors.white.withAlpha(isToday ? 200 : 60),
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, cell.topLeft + const Offset(5, 4));
    }

    final byDay = <int, List<SessionRecord>>{};
    for (final r in sessions) {
      (byDay[r.completedAt.day] ??= []).add(r);
    }

    for (final entry in byDay.entries) {
      final cell = cellOf(entry.key);
      final stars = [
        for (final r in entry.value)
          () {
            final h = _hash(r.syncId);
            final u = (h & 0xffff) / 0xffff;
            final v = ((h >> 16) & 0xffff) / 0xffff;
            return (
              pos: Offset(
                cell.left + cell.width * (0.2 + 0.64 * u),
                cell.top + cell.height * (0.3 + 0.55 * v),
              ),
              radius: 1.4 + math.min(r.minutes, 60) / 25 * 1.1,
              color: _starColors[h % _starColors.length],
              phase: (h % 100) / 100,
            );
          }(),
      ];

      // Constellation lines in completion order.
      final line =
          Paint()
            ..color = Colors.white.withAlpha(70)
            ..strokeWidth = 0.8;
      for (var i = 1; i < stars.length; i++) {
        canvas.drawLine(stars[i - 1].pos, stars[i].pos, line);
      }

      final isToday = entry.key == today;
      for (final s in stars) {
        final shimmer =
            isToday
                ? 0.65 + 0.35 * math.sin((twinkle + s.phase) * 2 * math.pi)
                : 1.0;
        canvas.drawCircle(
          s.pos,
          s.radius * 3.2,
          Paint()
            ..color = s.color.withAlpha((70 * shimmer).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          s.pos,
          s.radius,
          Paint()..color = s.color.withAlpha((255 * shimmer).round()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.twinkle != twinkle ||
      old.selectedDay != selectedDay ||
      old.month != month ||
      old.sessions.length != sessions.length;
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.title,
    required this.stars,
    required this.minutes,
  });

  final String title;
  final int stars;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Brand.textSecondary),
            ),
          ),
          const Icon(Icons.star_rounded, size: 18, color: Brand.cyan),
          const SizedBox(width: 4),
          Text(
            '$stars ${context.tr('stars')}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Text(
            AppStrings.duration(context, minutes),
            style: const TextStyle(color: Brand.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.controller});

  final PomodoroController controller;

  void _show(BuildContext context, Achievement a, bool unlocked) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: Icon(
              unlocked ? a.icon : Icons.lock_outline_rounded,
              size: 44,
              color: unlocked ? Brand.cyan : Brand.textMuted,
            ),
            title: Text(context.tr(a.titleKey)),
            content: Text(
              context.tr(a.descriptionKey),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('close')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.78,
      children: [
        for (final a in achievements)
          () {
            final unlocked = controller.isUnlocked(a);
            return Semantics(
              button: true,
              label:
                  '${context.tr(a.titleKey)}, '
                  '${context.tr(unlocked ? 'unlocked' : 'locked')}',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _show(context, a, unlocked),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            unlocked
                                ? const LinearGradient(
                                  colors: [Brand.violet, Brand.deep],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                : null,
                        color: unlocked ? null : Brand.surfaceHigh,
                        border: Border.all(
                          color:
                              unlocked
                                  ? Brand.cyan.withAlpha(150)
                                  : Brand.outline,
                        ),
                      ),
                      child: Icon(
                        unlocked ? a.icon : Icons.lock_outline_rounded,
                        color: unlocked ? Colors.white : Brand.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(a.titleKey),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: unlocked ? Brand.textPrimary : Brand.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}
