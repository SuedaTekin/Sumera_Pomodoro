import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'achievements.dart';
import 'brand.dart';
import 'models.dart';
import 'remote_config.dart';
import 'services.dart';
import 'sounds.dart';
import 'strings.dart';
import 'sync.dart';

/// Owns the timer, settings, tasks and history. Screens listen to it.
class PomodoroController extends ChangeNotifier with WidgetsBindingObserver {
  PomodoroController(
    this._storage, {
    this.remote,
    this.sync,
    this.sound,
    String? forcedLanguage,
  }) : _forcedLanguage = forcedLanguage {
    AppStrings.overrides = remoteConfig.strings;
    remote?.addListener(_onRemoteChanged);
    _connectCloud();
    settings = _storage.loadSettings(defaults: remoteConfig.defaults);
    tasks = _storage.loadTasks() ?? [];
    history = _storage.loadHistory();
    activeTaskId = _storage.loadActiveTaskId();
    if (activeTaskId != null && taskById(activeTaskId!) == null) {
      activeTaskId = null;
    }
    totalSeconds = settings.workMinutes * 60;
    remainingSeconds = totalSeconds;

    // Badges earned before this feature existed are not celebrated.
    if (!_storage.prefs.containsKey(_seenKey)) {
      _storage.prefs.setStringList(_seenKey, _unlockedIds.toList());
    }

    // Resume a session that was running when the app was closed.
    final running = _storage.loadRunningTimer();
    if (running != null) {
      mode = running.mode;
      totalSeconds = running.totalSeconds;
      _endTime = running.end;
      _startTicker();
      _tick();
      if (isRunning) _syncNotifications();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  final AppStorage _storage;
  final String? _forcedLanguage;

  SharedPreferences get prefs => _storage.prefs;

  /// Ambient focus sounds; null in tests.
  final SoundPlayer? sound;

  /// Live config downloaded from GitHub; null in tests.
  final RemoteConfigService? remote;

  RemoteConfig get remoteConfig => remote?.config ?? RemoteConfig.empty;

  /// Supabase backup; null when unavailable (tests, no configuration).
  final SyncService? sync;
  Timer? _syncDebounce;

  /// Pushes local changes after a short pause so bursts become one request.
  void _scheduleSync({Duration delay = const Duration(seconds: 3)}) {
    if (sync == null || !settings.cloudSync) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(delay, syncNow);
  }

  /// Attaches the Supabase project named in the remote config, if any.
  Future<void> _connectCloud() async {
    final s = sync;
    final url = remoteConfig.cloudUrl;
    final key = remoteConfig.cloudKey;
    if (s == null || s.isAvailable || url == null || key == null) return;
    if (await s.connect(url, key)) _scheduleSync(delay: Duration.zero);
  }

  Future<void> syncNow() async {
    final s = sync;
    if (s == null || !settings.cloudSync) return;
    await s.sync(
      tasks: List.of(tasks),
      history: List.of(history),
      onPulled: _mergeFromCloud,
    );
  }

  void _mergeFromCloud(List<TaskItem> newTasks, List<SessionRecord> sessions) {
    tasks.addAll(newTasks);
    history
      ..addAll(sessions)
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    _storage.saveTasks(tasks);
    _storage.saveHistory(history);
    _historyChanged();
    notifyListeners();
  }

  /// Deletes the cloud copy and turns sync off. Local data is kept.
  Future<bool> deleteCloudData() async {
    final ok = await sync?.deleteCloudData() ?? false;
    if (ok) updateSettings(settings.copyWith(cloudSync: false));
    return ok;
  }

  void _onRemoteChanged() {
    _connectCloud();
    AppStrings.overrides = remoteConfig.strings;
    // Remote defaults only affect settings the user has never saved.
    final reloaded = _storage.loadSettings(defaults: remoteConfig.defaults);
    if (isPristine && reloaded.minutesFor(mode) != settings.minutesFor(mode)) {
      totalSeconds = reloaded.minutesFor(mode) * 60;
      remainingSeconds = totalSeconds;
    }
    settings = reloaded;
    notifyListeners();
  }

  late AppSettings settings;
  late List<TaskItem> tasks;
  late List<SessionRecord> history;
  String? activeTaskId;

  FocusMode mode = FocusMode.work;
  int totalSeconds = 25 * 60;
  int remainingSeconds = 25 * 60;
  DateTime? _endTime;
  Timer? _ticker;

  final _completions = StreamController<FocusMode>.broadcast();
  final _unlocks = StreamController<List<Achievement>>.broadcast();

  /// Emits badges earned by the session that just finished.
  Stream<List<Achievement>> get unlocks => _unlocks.stream;

  /// Emits the mode that just finished.
  Stream<FocusMode> get completions => _completions.stream;

  bool get isRunning => _endTime != null;

  bool get isPristine => !isRunning && remainingSeconds == totalSeconds;

  double get progress {
    if (totalSeconds <= 0) return 0;
    return ((totalSeconds - remainingSeconds) / totalSeconds).clamp(0.0, 1.0);
  }

  /// The language actually used for UI and notifications.
  String get languageCode {
    if (_forcedLanguage != null) return _forcedLanguage;
    if (settings.languageCode != AppSettings.systemLanguage) {
      return settings.languageCode;
    }
    final device = PlatformDispatcher.instance.locale.languageCode;
    return AppStrings.supportedLocales.any((l) => l.languageCode == device)
        ? device
        : 'en';
  }

  // ----------------------------------------------------------- onboarding

  static const _onboardedKey = 'onboarded';

  /// Existing users (with saved settings or data) skip the introduction.
  bool get onboarded =>
      _storage.prefs.getBool(_onboardedKey) ??
      (_storage.prefs.containsKey('work_minutes') ||
          history.isNotEmpty ||
          tasks.isNotEmpty);

  void completeOnboarding(AppSettings chosen) {
    _storage.prefs.setBool(_onboardedKey, true);
    updateSettings(chosen);
    reset();
  }

  // ---------------------------------------------------------------- timer

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Timers are throttled in the background; resync with the wall clock.
    if (isRunning) _tick();
    remote?.refresh();
    _scheduleSync(delay: const Duration(seconds: 1));
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _applyWakelock();
  }

  void _tick() {
    final end = _endTime;
    if (end == null) return;

    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _completeSession();
      return;
    }

    // Round up so the display shows 25:00 right after starting.
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    if (seconds != remainingSeconds) {
      remainingSeconds = seconds;
      notifyListeners();
    }
  }

  void start() {
    if (isRunning || remainingSeconds <= 0) return;

    final end = DateTime.now().add(Duration(seconds: remainingSeconds));
    _endTime = end;
    _startTicker();
    notifyListeners();

    _storage.saveRunningTimer(end, mode, totalSeconds);
    _syncNotifications();
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    if (_endTime != null) {
      _endTime = null;
      _storage.clearRunningTimer();
      _syncNotifications();
    }
    _applyWakelock();
  }

  /// Adds time to the current session, running or not.
  void extend(int minutes) {
    final extra = Duration(minutes: minutes);
    totalSeconds += extra.inSeconds;
    final end = _endTime;
    if (end != null) {
      _endTime = end.add(extra);
      _storage.saveRunningTimer(_endTime!, mode, totalSeconds);
      _syncNotifications();
      _tick();
    } else {
      remainingSeconds += extra.inSeconds;
    }
    notifyListeners();
  }

  /// Brings the scheduled "finished" alert and the live countdown in line
  /// with the current timer state.
  void _syncNotifications() {
    final end = _endTime;
    if (end == null) {
      NotificationService.cancelSessionFinished();
      NotificationService.cancelOngoing();
      return;
    }

    final lang = languageCode;
    if (settings.enableNotifications) {
      NotificationService.scheduleSessionFinished(
        mode,
        end,
        languageCode: lang,
      );
    } else {
      NotificationService.cancelSessionFinished();
    }

    if (settings.showOngoing) {
      String t(String key) => AppStrings.forLanguage(lang, key);
      final task = mode == FocusMode.work ? activeTask?.title : null;
      final hh = end.hour.toString().padLeft(2, '0');
      final mm = end.minute.toString().padLeft(2, '0');
      NotificationService.showOngoing(
        end: end,
        title: task == null ? t(mode.labelKey) : '${t(mode.labelKey)} · $task',
        body: '${t('endsAt')} $hh:$mm',
        languageCode: lang,
      );
    } else {
      NotificationService.cancelOngoing();
    }
  }

  void pause() {
    if (!isRunning) return;
    _tick();
    _stop();
    notifyListeners();
  }

  void toggle() => isRunning ? pause() : start();

  void reset() {
    _stop();
    totalSeconds = settings.minutesFor(mode) * 60;
    remainingSeconds = totalSeconds;
    notifyListeners();
  }

  void selectMode(FocusMode newMode) {
    _stop();
    mode = newMode;
    totalSeconds = settings.minutesFor(newMode) * 60;
    remainingSeconds = totalSeconds;
    notifyListeners();
  }

  void skip() => selectMode(_nextModeAfter(mode));

  FocusMode _nextModeAfter(FocusMode finished) {
    if (finished != FocusMode.work) return FocusMode.work;
    final count = todayPomodoros;
    return count > 0 && count % settings.longBreakInterval == 0
        ? FocusMode.longBreak
        : FocusMode.shortBreak;
  }

  void _completeSession() {
    final finished = mode;
    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
    _storage.clearRunningTimer();
    // The "finished" alert has just fired; leave it visible.
    NotificationService.cancelOngoing();

    history.add(
      SessionRecord(
        mode: finished,
        completedAt: DateTime.now(),
        minutes: (totalSeconds / 60).round(),
        taskId: finished == FocusMode.work ? activeTaskId : null,
      ),
    );
    _storage.saveHistory(history);
    _historyChanged();
    _scheduleSync();
    final earned = _takeNewAchievements();

    mode = settings.enableAutoAdvance ? _nextModeAfter(finished) : finished;
    totalSeconds = settings.minutesFor(mode) * 60;
    remainingSeconds = totalSeconds;

    if (settings.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    if (settings.enableAutoAdvance && settings.enableAutoStart) {
      start();
    } else {
      _applyWakelock();
    }
    notifyListeners();
    _completions.add(finished);
    if (earned.isNotEmpty) _unlocks.add(earned);
  }

  void _applyWakelock() {
    final enable = isRunning && settings.keepScreenOn;
    WakelockPlus.toggle(enable: enable).catchError((Object error) {
      debugPrint('Wakelock unavailable: $error');
    });
    _applySound();
  }

  /// Saves the choice and lets the user hear it: it keeps playing during a
  /// running focus session, otherwise it plays a short preview.
  void chooseSound(AmbientSound choice) {
    updateSettings(settings.copyWith(ambientSound: choice.name));
    final focusing = isRunning && mode == FocusMode.work;
    sound?.preview(choice, settings.soundVolume, keep: focusing);
  }

  /// The chosen ambient sound plays only while a focus session runs.
  void _applySound() {
    final player = sound;
    if (player == null) return;
    final chosen = AmbientSoundInfo.parse(settings.ambientSound);
    if (isRunning && mode == FocusMode.work && chosen != AmbientSound.none) {
      player.play(chosen, settings.soundVolume);
    } else {
      player.stop();
    }
  }

  // ------------------------------------------------------------- settings

  void updateSettings(AppSettings updated) {
    final old = settings;
    settings = updated;
    _storage.saveSettings(updated);

    // A running session keeps its length; new durations apply next time.
    if (isPristine && old.minutesFor(mode) != updated.minutesFor(mode)) {
      totalSeconds = updated.minutesFor(mode) * 60;
      remainingSeconds = totalSeconds;
    }

    if (isRunning &&
        (old.enableNotifications != updated.enableNotifications ||
            old.showOngoing != updated.showOngoing ||
            old.languageCode != updated.languageCode)) {
      _syncNotifications();
    }
    if (old.keepScreenOn != updated.keepScreenOn) _applyWakelock();
    if (isRunning &&
        (old.ambientSound != updated.ambientSound ||
            old.soundVolume != updated.soundVolume)) {
      _applySound();
    }
    if (old.dailyGoal != updated.dailyGoal) _historyChanged();
    if (!old.cloudSync && updated.cloudSync) {
      _scheduleSync(delay: Duration.zero);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- tasks

  TaskItem? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  TaskItem? get activeTask =>
      activeTaskId == null ? null : taskById(activeTaskId!);

  void addTask(String title) {
    final text = title.trim();
    if (text.isEmpty) return;
    final task = TaskItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: text,
    );
    tasks.add(task);
    activeTaskId ??= task.id;
    _saveTasks();
  }

  void toggleTask(TaskItem task) {
    task.isDone = !task.isDone;
    if (task.isDone && activeTaskId == task.id) activeTaskId = null;
    _saveTasks();
  }

  void setActiveTask(String? id) {
    activeTaskId = id;
    _saveTasks();
    if (isRunning) _syncNotifications();
  }

  void updateTask(
    TaskItem task, {
    required String title,
    required int estimate,
  }) {
    final text = title.trim();
    if (text.isNotEmpty) task.title = text;
    task.estimate = estimate;
    _saveTasks();
    if (isRunning && task.id == activeTaskId) _syncNotifications();
  }

  /// Returns the index so the deletion can be undone.
  int deleteTask(TaskItem task) {
    final index = tasks.indexOf(task);
    tasks.removeAt(index);
    sync?.markTaskDeleted(task.id);
    if (activeTaskId == task.id) activeTaskId = null;
    _saveTasks();
    return index;
  }

  void restoreTask(TaskItem task, int index) {
    tasks.insert(index.clamp(0, tasks.length), task);
    sync?.unmarkTaskDeleted(task.id);
    _saveTasks();
  }

  void clearDoneTasks() {
    for (final t in tasks.where((t) => t.isDone)) {
      sync?.markTaskDeleted(t.id);
    }
    tasks.removeWhere((t) => t.isDone);
    _saveTasks();
  }

  void _saveTasks() {
    _storage.saveTasks(tasks);
    _storage.saveActiveTaskId(activeTaskId);
    _scheduleSync();
    notifyListeners();
  }

  int pomodorosForTask(String id) =>
      history.where((r) => r.isFocus && r.taskId == id).length;

  // ---------------------------------------------------------------- stats

  Iterable<SessionRecord> get _focusSessions => history.where((r) => r.isFocus);

  int get todayPomodoros {
    final today = dateOnly(DateTime.now());
    return _focusSessions.where((r) => dateOnly(r.completedAt) == today).length;
  }

  int get todayFocusMinutes {
    final today = dateOnly(DateTime.now());
    return _focusSessions
        .where((r) => dateOnly(r.completedAt) == today)
        .fold(0, (sum, r) => sum + r.minutes);
  }

  /// Position inside the current long-break cycle, 0..interval.
  int get cyclePosition {
    final interval = settings.longBreakInterval;
    final count = todayPomodoros;
    if (count > 0 && count % interval == 0 && mode != FocusMode.work) {
      return interval;
    }
    return count % interval;
  }

  bool get hasHistory => _focusSessions.isNotEmpty;

  /// One entry per day for the last [days] days, oldest first.
  List<DayStat> dayStats(int days) {
    final today = dateOnly(DateTime.now());
    final first = DateTime(today.year, today.month, today.day - days + 1);
    final minutes = <DateTime, int>{};
    final counts = <DateTime, int>{};
    for (final r in _focusSessions) {
      final d = dateOnly(r.completedAt);
      if (d.isBefore(first)) continue;
      minutes[d] = (minutes[d] ?? 0) + r.minutes;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < days; i++)
        () {
          final d = DateTime(first.year, first.month, first.day + i);
          return DayStat(
            day: d,
            minutes: minutes[d] ?? 0,
            pomodoros: counts[d] ?? 0,
          );
        }(),
    ];
  }

  /// Consecutive days with at least one pomodoro, ending today (or yesterday
  /// if nothing has been done yet today).
  int get streak {
    final days = _focusSessions.map((r) => dateOnly(r.completedAt)).toSet();
    var day = dateOnly(DateTime.now());
    if (!days.contains(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Focus minutes per task over the last [days] days, largest first.
  List<({String title, int minutes})> taskBreakdown(int days) {
    final today = dateOnly(DateTime.now());
    final first = DateTime(today.year, today.month, today.day - days + 1);
    final totals = <String, int>{};
    for (final r in _focusSessions) {
      if (r.taskId == null || dateOnly(r.completedAt).isBefore(first)) continue;
      totals[r.taskId!] = (totals[r.taskId!] ?? 0) + r.minutes;
    }
    final result = [
      for (final e in totals.entries)
        if (taskById(e.key) case final task?)
          (title: task.title, minutes: e.value),
    ]..sort((a, b) => b.minutes.compareTo(a.minutes));
    return result;
  }

  void resetStats() {
    history.clear();
    _storage.saveHistory(history);
    _historyChanged();
    if (settings.cloudSync) sync?.resetSessions();
    notifyListeners();
  }

  // --------------------------------------------------------- achievements

  static const _seenKey = 'achievements_seen';
  AchievementStats? _statsCache;

  void _historyChanged() => _statsCache = null;

  AchievementStats get achievementStats =>
      _statsCache ??= AchievementStats.from(history, settings.dailyGoal);

  Set<String> get _unlockedIds => {
    for (final a in achievements)
      if (a.test(achievementStats)) a.id,
  };

  bool isUnlocked(Achievement a) => a.test(achievementStats);

  List<Achievement> _takeNewAchievements() {
    final seen = (_storage.prefs.getStringList(_seenKey) ?? const []).toSet();
    final earned = [
      for (final a in achievements)
        if (!seen.contains(a.id) && a.test(achievementStats)) a,
    ];
    if (earned.isNotEmpty) {
      _storage.prefs.setStringList(
        _seenKey,
        {...seen, ...earned.map((a) => a.id)}.toList(),
      );
    }
    return earned;
  }

  Insights get insights => Insights.from(history, DateTime.now());

  int get totalPomodoros => achievementStats.pomodoros;

  /// Focus sessions of one calendar month, oldest first (stars of the sky).
  List<SessionRecord> focusSessionsInMonth(DateTime month) => [
    for (final r in _focusSessions)
      if (r.completedAt.year == month.year &&
          r.completedAt.month == month.month)
        r,
  ];

  @override
  void dispose() {
    sound?.dispose();
    _unlocks.close();
    WidgetsBinding.instance.removeObserver(this);
    remote?.removeListener(_onRemoteChanged);
    _syncDebounce?.cancel();
    _ticker?.cancel();
    _completions.close();
    super.dispose();
  }
}
