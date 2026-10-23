import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../brand.dart';
import '../achievements.dart';
import '../controller.dart';
import '../strings.dart';
import '../widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _range = 7;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('stats'))),
          body: c.hasHistory ? _buildBody(context, c) : _buildEmpty(context),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_rounded, size: 64, color: Brand.chartBar),
            const SizedBox(height: 16),
            Text(
              context.tr('noStats'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.textSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PomodoroController c) {
    final lang = Localizations.localeOf(context).languageCode;
    final days = c.dayStats(_range);
    final selected = (_selected ?? days.length - 1).clamp(0, days.length - 1);
    final sel = days[selected];

    final totalMinutes = days.fold(0, (s, d) => s + d.minutes);
    final totalPomodoros = days.fold(0, (s, d) => s + d.pomodoros);
    final best = days.reduce((a, b) => b.minutes > a.minutes ? b : a);
    final goalMinutes = c.settings.dailyGoal * c.settings.workMinutes;
    final tasks = c.taskBreakdown(_range);
    final loc = MaterialLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 7, label: Text(context.tr('week'))),
            ButtonSegment(value: 30, label: Text(context.tr('month'))),
          ],
          selected: {_range},
          onSelectionChanged:
              (s) => setState(() {
                _range = s.first;
                _selected = null;
              }),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            StatTile(
              label: context.tr('totalFocus'),
              value: AppStrings.duration(context, totalMinutes),
              icon: Icons.timer_rounded,
            ),
            StatTile(
              label: context.tr('dailyAverage'),
              value: AppStrings.duration(
                context,
                (totalMinutes / _range).round(),
              ),
              icon: Icons.show_chart_rounded,
            ),
            StatTile(
              label: context.tr('pomodoros'),
              value: '$totalPomodoros',
              icon: Icons.check_circle_rounded,
            ),
            StatTile(
              label: context.tr('streak'),
              value: '${c.streak} ${context.tr('days')}',
              icon: Icons.local_fire_department_rounded,
            ),
          ],
        ),
        if (c.remoteConfig.feature('insights')) ...[
          const SizedBox(height: 20),
          SectionHeader(context.tr('insights')),
          _InsightsCard(insights: c.insights, lang: lang),
        ],
        const SizedBox(height: 20),
        SectionHeader(context.tr('focusByDay')),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Readout for the selected bar (the chart's tooltip).
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.formatMediumDate(sel.day),
                              style: const TextStyle(
                                color: Brand.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.duration(context, sel.minutes),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${sel.pomodoros} ${context.tr('pomodoroCount')}',
                        style: const TextStyle(color: Brand.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label:
                      '${context.tr('focusByDay')}: '
                      '${AppStrings.duration(context, totalMinutes)}',
                  child: FocusBarChart(
                    data: days,
                    selectedIndex: selected,
                    onSelect: (i) => setState(() => _selected = i),
                    goalMinutes: goalMinutes,
                    goalLabel: context.tr('goal'),
                    yLabel:
                        (m) =>
                            m >= 60 && m % 60 == 0
                                ? '${m ~/ 60}${context.tr('hoursShort')}'
                                : '$m${context.tr('minutesShort')}',
                    xLabel:
                        (i, d) =>
                            _range == 7
                                ? weekdayShort(lang, d.day.weekday)
                                : '${d.day.day}',
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    context.tr('tapBarHint'),
                    style: const TextStyle(
                      color: Brand.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (best.minutes > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              '${context.tr('bestDay')}: ${loc.formatMediumDate(best.day)} · '
              '${AppStrings.duration(context, best.minutes)}',
              style: const TextStyle(color: Brand.textSecondary, fontSize: 13),
            ),
          ),
        if (c.remoteConfig.feature('heatmap')) ...[
          const SizedBox(height: 20),
          SectionHeader(context.tr('activity')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: () {
                final today = DateTime.now();
                // Start on the Monday 15 weeks before this week's Monday.
                final span = 15 * 7 + today.weekday;
                final heat = c.dayStats(span);
                return ActivityHeatmap(
                  days: heat,
                  goalMinutes: goalMinutes,
                  rowLabels: [
                    for (var w = 1; w <= 7; w++) weekdayShort(lang, w),
                  ],
                  lessLabel: context.tr('less'),
                  moreLabel: context.tr('more'),
                  tooltip:
                      (d) =>
                          '${loc.formatMediumDate(d.day)} · '
                          '${AppStrings.duration(context, d.minutes)}',
                );
              }(),
            ),
          ),
        ],
        if (c.remoteConfig.feature('taskBreakdown')) ...[
          const SizedBox(height: 20),
          SectionHeader(context.tr('focusByTask')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  tasks.isEmpty
                      ? Text(
                        context.tr('noTaskData'),
                        style: const TextStyle(color: Brand.textSecondary),
                      )
                      : Column(
                        children: [
                          for (final t in tasks.take(6))
                            _TaskBar(
                              title: t.title,
                              minutes: t.minutes,
                              fraction: t.minutes / tasks.first.minutes,
                            ),
                        ],
                      ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskBar extends StatelessWidget {
  const _TaskBar({
    required this.title,
    required this.minutes,
    required this.fraction,
  });

  final String title;
  final int minutes;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                AppStrings.duration(context, minutes),
                style: const TextStyle(
                  color: Brand.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder:
                (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 8,
                    width: (constraints.maxWidth * fraction).clamp(
                      4.0,
                      constraints.maxWidth,
                    ),
                    decoration: BoxDecoration(
                      color: Brand.chartBar,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Short weekday name (Mon..Sun) in [lang]; 1 = Monday.
String weekdayShort(String lang, int weekday) =>
    DateFormat.E(lang).format(DateTime(2024, 1, weekday));

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights, required this.lang});

  final Insights insights;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final change = insights.change;
    final hour = insights.bestHour;
    final weekday = insights.bestWeekday;

    final rows = <(IconData, Color, String, String)>[
      if (change == null)
        (
          Icons.flag_rounded,
          Brand.cyan,
          context.tr('vsLastWeek'),
          context.tr('firstWeek'),
        )
      else
        (
          change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          change >= 0 ? Brand.success : Colors.orangeAccent,
          context.tr('vsLastWeek'),
          '${change >= 0 ? '+' : ''}$change%',
        ),
      if (hour != null)
        (
          Icons.schedule_rounded,
          Brand.chartBar,
          context.tr('bestHour'),
          '${hour.toString().padLeft(2, '0')}:00 – '
              '${((hour + 1) % 24).toString().padLeft(2, '0')}:00',
        ),
      if (weekday != null)
        (
          Icons.calendar_today_rounded,
          Brand.chartBar,
          context.tr('bestWeekday'),
          // 2024-01-01 was a Monday.
          DateFormat.EEEE(lang).format(DateTime(2024, 1, weekday)),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final (icon, color, label, value) in rows)
              ListTile(
                leading: Icon(icon, color: color),
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Brand.textSecondary,
                    fontSize: 14,
                  ),
                ),
                trailing: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
