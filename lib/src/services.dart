import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'brand.dart';
import 'models.dart';
import 'strings.dart';

/// Persists tasks, history and the running timer so nothing is lost when the
/// OS kills the app in the background.
class AppStorage {
  AppStorage(this._prefs);

  static Future<AppStorage> open() async =>
      AppStorage(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  static const _tasksKey = 'tasks';
  static const _historyKey = 'session_history';
  static const _activeTaskKey = 'active_task';
  static const _timerEndKey = 'timer_end';
  static const _timerModeKey = 'timer_mode';
  static const _timerTotalKey = 'timer_total_seconds';

  /// About three years of daily use.
  static const _maxHistory = 10000;

  AppSettings loadSettings({Map<String, int> defaults = const {}}) =>
      AppSettings.fromPrefs(_prefs, defaults: defaults);

  Future<void> saveSettings(AppSettings settings) => settings.save(_prefs);

  List<TaskItem>? loadTasks() {
    final raw = _prefs.getString(_tasksKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final (i, e) in list.indexed)
          TaskItem.fromJson(e as Map<String, dynamic>, i),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTasks(List<TaskItem> tasks) => _prefs.setString(
    _tasksKey,
    jsonEncode(tasks.map((t) => t.toJson()).toList()),
  );

  String? loadActiveTaskId() => _prefs.getString(_activeTaskKey);

  Future<void> saveActiveTaskId(String? id) =>
      id == null
          ? _prefs.remove(_activeTaskKey)
          : _prefs.setString(_activeTaskKey, id);

  List<SessionRecord> loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<SessionRecord> history) {
    final trimmed =
        history.length > _maxHistory
            ? history.sublist(history.length - _maxHistory)
            : history;
    return _prefs.setString(
      _historyKey,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }

  ({DateTime end, FocusMode mode, int totalSeconds})? loadRunningTimer() {
    final end = _prefs.getInt(_timerEndKey);
    final mode = _prefs.getString(_timerModeKey);
    final total = _prefs.getInt(_timerTotalKey);
    if (end == null || mode == null || total == null) return null;
    return (
      end: DateTime.fromMillisecondsSinceEpoch(end),
      mode: FocusMode.values.byName(mode),
      totalSeconds: total,
    );
  }

  Future<void> saveRunningTimer(DateTime end, FocusMode mode, int total) async {
    await _prefs.setInt(_timerEndKey, end.millisecondsSinceEpoch);
    await _prefs.setString(_timerModeKey, mode.name);
    await _prefs.setInt(_timerTotalKey, total);
  }

  Future<void> clearRunningTimer() async {
    await _prefs.remove(_timerEndKey);
    await _prefs.remove(_timerModeKey);
    await _prefs.remove(_timerTotalKey);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const _sessionNotificationId = 1001;
  static const _ongoingNotificationId = 1002;
  static bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_pomodoro'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initSettings);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static NotificationDetails _details(String languageCode) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro',
        channelDescription: AppStrings.forLanguage(
          languageCode,
          'notificationChannel',
        ),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: Brand.indigo,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// Schedules the "session finished" alert so it fires even when the app is
  /// in the background or has been closed.
  static Future<void> scheduleSessionFinished(
    FocusMode mode,
    DateTime at, {
    required String languageCode,
  }) async {
    if (!_initialized) return;
    final isWork = mode == FocusMode.work;
    String t(String key) => AppStrings.forLanguage(languageCode, key);

    try {
      final android =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final canUseExact =
          await android?.canScheduleExactNotifications() ?? true;

      await _notifications.zonedSchedule(
        _sessionNotificationId,
        t(isWork ? 'notificationTitleWork' : 'notificationTitleBreak'),
        t(isWork ? 'notificationBodyWork' : 'notificationBodyBreak'),
        tz.TZDateTime.from(at, tz.UTC),
        _details(languageCode),
        androidScheduleMode:
            canUseExact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: mode.name,
      );
    } catch (error) {
      debugPrint('Could not schedule notification: $error');
    }
  }

  static Future<void> cancelSessionFinished() =>
      _cancel(_sessionNotificationId);

  /// Silent, sticky notification whose chronometer counts down to [end]
  /// (Android only; iOS has no live countdown in notifications).
  static Future<void> showOngoing({
    required DateTime end,
    required String title,
    required String body,
    required String languageCode,
  }) async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _notifications.show(
        _ongoingNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'pomodoro_ongoing',
            AppStrings.forLanguage(languageCode, 'ongoingChannel'),
            channelDescription: AppStrings.forLanguage(
              languageCode,
              'ongoingChannelDescription',
            ),
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showWhen: true,
            when: end.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            color: Brand.indigo,
            category: AndroidNotificationCategory.stopwatch,
            visibility: NotificationVisibility.public,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Could not show ongoing notification: $error');
    }
  }

  static Future<void> cancelOngoing() => _cancel(_ongoingNotificationId);

  static Future<void> _cancel(int id) async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(id);
    } catch (error) {
      debugPrint('Could not cancel notification: $error');
    }
  }
}
