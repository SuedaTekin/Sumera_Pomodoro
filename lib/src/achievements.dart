import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

/// Totals the badges are judged on, computed from the session history.
class AchievementStats {
  const AchievementStats({
    this.pomodoros = 0,
    this.minutes = 0,
    this.bestStreak = 0,
    this.bestDay = 0,
    this.goalDays = 0,
    this.earlyBird = false,
    this.nightOwl = false,
    this.weekendBest = 0,
    this.taskSessions = 0,
  });

  factory AchievementStats.from(List<SessionRecord> history, int dailyGoal) {
    final focus = history.where((r) => r.isFocus).toList();
    final perDay = <DateTime, int>{};
    var minutes = 0;
    var early = false;
    var late = false;
    var tasks = 0;
    for (final r in focus) {
      final day = dateOnly(r.completedAt);
      perDay[day] = (perDay[day] ?? 0) + 1;
      minutes += r.minutes;
      final start = r.completedAt.subtract(Duration(minutes: r.minutes));
      if (start.hour < 7) early = true;
      if (r.completedAt.hour >= 23 || r.completedAt.hour < 3) late = true;
      if (r.taskId != null) tasks++;
    }

    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in perDay.keys.toList()..sort()) {
      final consecutive =
          previous != null &&
          DateTime(previous.year, previous.month, previous.day + 1) == day;
      run = consecutive ? run + 1 : 1;
      best = math.max(best, run);
      previous = day;
    }

    return AchievementStats(
      pomodoros: focus.length,
      minutes: minutes,
      bestStreak: best,
      bestDay: perDay.values.fold(0, math.max),
      goalDays: perDay.values.where((c) => c >= dailyGoal).length,
      earlyBird: early,
      nightOwl: late,
      weekendBest: perDay.entries
          .where((e) => e.key.weekday >= DateTime.saturday)
          .fold(0, (m, e) => math.max(m, e.value)),
      taskSessions: tasks,
    );
  }

  final int pomodoros;
  final int minutes;
  final int bestStreak;
  final int bestDay;
  final int goalDays;
  final bool earlyBird;
  final bool nightOwl;
  final int weekendBest;
  final int taskSessions;
}

class Achievement {
  const Achievement(this.id, this.icon, this.test);

  final String id;
  final IconData icon;
  final bool Function(AchievementStats s) test;

  String get titleKey => 'ach_${id}_title';
  String get descriptionKey => 'ach_${id}_desc';
}

/// Order is the display order on the sky screen.
final achievements = <Achievement>[
  Achievement('first', Icons.flag_rounded, (s) => s.pomodoros >= 1),
  Achievement('ten', Icons.looks_one_rounded, (s) => s.pomodoros >= 10),
  Achievement('goal', Icons.emoji_events_rounded, (s) => s.goalDays >= 1),
  Achievement(
    'streak3',
    Icons.local_fire_department_rounded,
    (s) => s.bestStreak >= 3,
  ),
  Achievement('streak7', Icons.whatshot_rounded, (s) => s.bestStreak >= 7),
  Achievement('marathon', Icons.directions_run_rounded, (s) => s.bestDay >= 8),
  Achievement('early', Icons.wb_twilight_rounded, (s) => s.earlyBird),
  Achievement('night', Icons.nights_stay_rounded, (s) => s.nightOwl),
  Achievement('weekend', Icons.weekend_rounded, (s) => s.weekendBest >= 4),
  Achievement('planner', Icons.checklist_rounded, (s) => s.taskSessions >= 10),
  Achievement('deep', Icons.psychology_rounded, (s) => s.minutes >= 600),
  Achievement(
    'hundred',
    Icons.military_tech_rounded,
    (s) => s.pomodoros >= 100,
  ),
  Achievement(
    'streak30',
    Icons.auto_awesome_rounded,
    (s) => s.bestStreak >= 30,
  ),
  Achievement('galaxy', Icons.blur_circular_rounded, (s) => s.pomodoros >= 500),
];

/// Week-over-week comparison and productive-time patterns.
class Insights {
  const Insights({
    required this.thisWeek,
    required this.lastWeek,
    this.bestHour,
    this.bestWeekday,
  });

  factory Insights.from(List<SessionRecord> history, DateTime now) {
    final today = dateOnly(now);
    final weekStart = DateTime(today.year, today.month, today.day - 6);
    final lastStart = DateTime(today.year, today.month, today.day - 13);
    final monthStart = DateTime(today.year, today.month, today.day - 29);

    var thisWeek = 0;
    var lastWeek = 0;
    final byHour = <int, int>{};
    final byWeekday = <int, int>{};
    for (final r in history.where((r) => r.isFocus)) {
      final day = dateOnly(r.completedAt);
      if (!day.isBefore(weekStart)) {
        thisWeek += r.minutes;
      } else if (!day.isBefore(lastStart)) {
        lastWeek += r.minutes;
      }
      if (!day.isBefore(monthStart)) {
        final start = r.completedAt.subtract(Duration(minutes: r.minutes));
        byHour[start.hour] = (byHour[start.hour] ?? 0) + r.minutes;
        byWeekday[day.weekday] = (byWeekday[day.weekday] ?? 0) + r.minutes;
      }
    }

    int? top(Map<int, int> m) =>
        m.isEmpty
            ? null
            : m.entries.reduce((a, b) => b.value > a.value ? b : a).key;

    return Insights(
      thisWeek: thisWeek,
      lastWeek: lastWeek,
      bestHour: top(byHour),
      bestWeekday: byWeekday.length >= 2 ? top(byWeekday) : null,
    );
  }

  final int thisWeek;
  final int lastWeek;

  /// Hour of day (0..23) with the most focus in the last 30 days.
  final int? bestHour;

  /// [DateTime.monday]..[DateTime.sunday].
  final int? bestWeekday;

  /// Percent change against the previous 7 days, null without a baseline.
  int? get change =>
      lastWeek == 0 ? null : ((thisWeek - lastWeek) * 100 / lastWeek).round();
}
