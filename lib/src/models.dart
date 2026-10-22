import 'package:shared_preferences/shared_preferences.dart';

enum FocusMode { work, shortBreak, longBreak }

typedef IntRange = ({int min, int max});

class AppSettings {
  const AppSettings({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakInterval = 4,
    this.dailyGoal = 8,
    this.enableNotifications = true,
    this.enableAutoAdvance = true,
    this.enableAutoStart = false,
    this.keepScreenOn = true,
    this.enableHaptics = true,
    this.showOngoing = true,
    this.languageCode = systemLanguage,
  });

  static const systemLanguage = 'system';

  static const IntRange workRange = (min: 5, max: 90);
  static const IntRange shortBreakRange = (min: 1, max: 30);
  static const IntRange longBreakRange = (min: 5, max: 60);
  static const IntRange longBreakIntervalRange = (min: 2, max: 8);
  static const IntRange dailyGoalRange = (min: 1, max: 20);
  static const IntRange estimateRange = (min: 0, max: 20);

  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval;
  final int dailyGoal;
  final bool enableNotifications;
  final bool enableAutoAdvance;
  final bool enableAutoStart;
  final bool keepScreenOn;
  final bool enableHaptics;

  /// Live countdown in the notification shade while the timer runs.
  final bool showOngoing;

  /// 'tr', 'en' or [systemLanguage].
  final String languageCode;

  int minutesFor(FocusMode mode) => switch (mode) {
    FocusMode.work => workMinutes,
    FocusMode.shortBreak => shortBreakMinutes,
    FocusMode.longBreak => longBreakMinutes,
  };

  AppSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakInterval,
    int? dailyGoal,
    bool? enableNotifications,
    bool? enableAutoAdvance,
    bool? enableAutoStart,
    bool? keepScreenOn,
    bool? enableHaptics,
    bool? showOngoing,
    String? languageCode,
  }) {
    return AppSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableAutoAdvance: enableAutoAdvance ?? this.enableAutoAdvance,
      enableAutoStart: enableAutoStart ?? this.enableAutoStart,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      showOngoing: showOngoing ?? this.showOngoing,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  static int _clamp(int? value, int fallback, IntRange range) {
    return (value ?? fallback).clamp(range.min, range.max);
  }

  /// [defaults] (from the remote config) replace the built-in fallbacks for
  /// settings the user has never saved.
  static AppSettings fromPrefs(
    SharedPreferences prefs, {
    Map<String, int> defaults = const {},
  }) {
    int read(String key, String remoteKey, int fallback, IntRange range) =>
        _clamp(prefs.getInt(key), defaults[remoteKey] ?? fallback, range);

    return AppSettings(
      workMinutes: read('work_minutes', 'workMinutes', 25, workRange),
      shortBreakMinutes: read(
        'short_break_minutes',
        'shortBreakMinutes',
        5,
        shortBreakRange,
      ),
      longBreakMinutes: read(
        'long_break_minutes',
        'longBreakMinutes',
        15,
        longBreakRange,
      ),
      longBreakInterval: read(
        'long_break_interval',
        'longBreakInterval',
        4,
        longBreakIntervalRange,
      ),
      dailyGoal: read('daily_goal', 'dailyGoal', 8, dailyGoalRange),
      enableNotifications: prefs.getBool('notifications_enabled') ?? true,
      enableAutoAdvance: prefs.getBool('auto_advance') ?? true,
      enableAutoStart: prefs.getBool('auto_start') ?? false,
      keepScreenOn: prefs.getBool('keep_screen_on') ?? true,
      enableHaptics: prefs.getBool('haptics') ?? true,
      showOngoing: prefs.getBool('show_ongoing') ?? true,
      languageCode: prefs.getString('language_code') ?? systemLanguage,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt('work_minutes', workMinutes);
    await prefs.setInt('short_break_minutes', shortBreakMinutes);
    await prefs.setInt('long_break_minutes', longBreakMinutes);
    await prefs.setInt('long_break_interval', longBreakInterval);
    await prefs.setInt('daily_goal', dailyGoal);
    await prefs.setBool('notifications_enabled', enableNotifications);
    await prefs.setBool('auto_advance', enableAutoAdvance);
    await prefs.setBool('auto_start', enableAutoStart);
    await prefs.setBool('keep_screen_on', keepScreenOn);
    await prefs.setBool('haptics', enableHaptics);
    await prefs.setBool('show_ongoing', showOngoing);
    await prefs.setString('language_code', languageCode);
  }
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.isDone = false,
    this.estimate = 0,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json, int index) => TaskItem(
    // Tasks saved by older versions have no id.
    id: json['id'] as String? ?? 'legacy-$index',
    title: json['title'] as String,
    isDone: json['done'] as bool? ?? false,
    estimate: json['estimate'] as int? ?? 0,
  );

  final String id;
  String title;
  bool isDone;

  /// Planned number of pomodoros; 0 means no estimate.
  int estimate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': isDone,
    if (estimate > 0) 'estimate': estimate,
  };
}

class SessionRecord {
  SessionRecord({
    required this.mode,
    required this.completedAt,
    required this.minutes,
    this.taskId,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    mode: FocusMode.values.byName(json['mode'] as String),
    completedAt: DateTime.parse(json['at'] as String),
    minutes: json['minutes'] as int? ?? 0,
    taskId: json['task'] as String?,
  );

  final FocusMode mode;
  final DateTime completedAt;
  final int minutes;
  final String? taskId;

  bool get isFocus => mode == FocusMode.work;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'at': completedAt.toIso8601String(),
    'minutes': minutes,
    if (taskId != null) 'task': taskId,
  };
}

/// Focus totals for one calendar day.
class DayStat {
  const DayStat({
    required this.day,
    required this.minutes,
    required this.pomodoros,
  });

  final DateTime day;
  final int minutes;
  final int pomodoros;
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
