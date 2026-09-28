import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await NotificationService.initialize();
  }

  await SupabaseService.initialize();
  await SupabaseService.ensureAuthenticated();

  runApp(const GeminiPomodoroApp());
}

enum FocusMode { work, shortBreak, longBreak }

class AppStrings {
  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];

  static const Map<String, Map<String, String>> _values = {
    'tr': {
      'appTitle': 'Sumera Pomodoro',
      'focusMode': 'Odak Modu',
      'shortBreakMode': 'Mola',
      'longBreakMode': 'Mola',
      'breakMode': 'Mola',
      'focusDescription': 'Konsantrasyonu koru',
      'shortBreakDescription': 'Kısa nefes al',
      'longBreakDescription': 'Daha uzun dinlen',
      'start': 'Başlat',
      'pause': 'Duraklat',
      'reset': 'Sıfırla',
      'completed': 'Tamamlanan',
      'tasks': 'Görevler',
      'settings': 'Ayarlar',
      'notifications': 'Bildirimler',
      'notificationsSubtitle': 'Süre bittiğinde uyarı göster',
      'autoAdvance': 'Otomatik geçiş',
      'autoAdvanceSubtitle': 'Çalışma bitince sonraki mod otomatik açılsın',
      'workDuration': 'Çalışma süresi',
      'breakDuration': 'Mola süresi',
      'dailyFocus': 'Günlük çalışma',
      'weeklyFocus': 'Son 7 gün',
      'minutes': 'dk',
      'taskList': 'Görev listesi',
      'newTaskHint': 'Yeni görev ekle',
      'noTasks': 'Henüz görev eklenmedi.',
      'today': 'Bugün',
      'noHistory': 'Henüz bir odak süresi tamamlanmadı.',
      'workMode': 'Çalışma',
      'sessionFinishWork': 'Çalışma süresi bitti. Mola zamanı!',
      'sessionFinishBreak': 'Mola bitti. Odak moduna dön!',
      'notificationTitleWork': 'Pomodoro tamamlandı',
      'notificationTitleBreak': 'Mola bitti',
      'notificationBodyWork': 'Şimdi mola veya yeni odak süresine geçebilirsiniz.',
      'notificationBodyBreak': 'Tekrar odaklanma moduna geçebilirsiniz.',
      'addTask': 'Görev ekle',
    },
    'en': {
      'appTitle': 'Sumera Pomodoro',
      'focusMode': 'Focus Mode',
      'shortBreakMode': 'Break',
      'longBreakMode': 'Break',
      'breakMode': 'Break',
      'focusDescription': 'Stay focused',
      'shortBreakDescription': 'Take a quick breath',
      'longBreakDescription': 'Rest a bit longer',
      'start': 'Start',
      'pause': 'Pause',
      'reset': 'Reset',
      'completed': 'Completed',
      'tasks': 'Tasks',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'notificationsSubtitle': 'Show alert when time is up',
      'autoAdvance': 'Auto advance',
      'autoAdvanceSubtitle': 'Move to the next mode automatically',
      'workDuration': 'Work duration',
      'breakDuration': 'Break duration',
      'dailyFocus': 'Daily focus',
      'weeklyFocus': 'Last 7 days',
      'minutes': 'min',
      'taskList': 'Task list',
      'newTaskHint': 'Add a new task',
      'noTasks': 'No tasks added yet.',
      'today': 'Today',
      'noHistory': 'No focus session has been completed yet.',
      'workMode': 'Work',
      'sessionFinishWork': 'Work session finished. Time for a break!',
      'sessionFinishBreak': 'Break finished. Back to focus mode!',
      'notificationTitleWork': 'Pomodoro complete',
      'notificationTitleBreak': 'Break finished',
      'notificationBodyWork': 'You can take a break or start a new focus session.',
      'notificationBodyBreak': 'You can return to focus mode.',
      'addTask': 'Add task',
    },
  };

  static String of(BuildContext context, String key) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return _values[languageCode]?[key] ?? _values['tr']?[key] ?? key;
  }
}

class AppSettings {
  AppSettings({
    this.workMinutes = 25,
    this.breakMinutes = 10,
    this.enableNotifications = true,
    this.enableAutoAdvance = true,
    this.languageCode = 'tr',
  });

  final int workMinutes;
  final int breakMinutes;
  final bool enableNotifications;
  final bool enableAutoAdvance;
  final String languageCode;

  AppSettings copyWith({
    int? workMinutes,
    int? breakMinutes,
    bool? enableNotifications,
    bool? enableAutoAdvance,
    String? languageCode,
  }) {
    return AppSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableAutoAdvance: enableAutoAdvance ?? this.enableAutoAdvance,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final legacyShort = prefs.getInt('short_break_minutes');
    final legacyLong = prefs.getInt('long_break_minutes');
    final legacyBreak = prefs.getInt('break_minutes');
    final resolvedBreak = legacyBreak ?? legacyShort ?? legacyLong ?? 10;

    return AppSettings(
      workMinutes: prefs.getInt('work_minutes') ?? 25,
      breakMinutes: resolvedBreak,
      enableNotifications: prefs.getBool('notifications_enabled') ?? true,
      enableAutoAdvance: prefs.getBool('auto_advance') ?? true,
      languageCode: prefs.getString('language_code') ?? 'tr',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('work_minutes', workMinutes);
    await prefs.setInt('break_minutes', breakMinutes);
    await prefs.setBool('notifications_enabled', enableNotifications);
    await prefs.setBool('auto_advance', enableAutoAdvance);
    await prefs.setString('language_code', languageCode);
  }
}

class TaskItem {
  TaskItem({required this.title, this.isDone = false});

  final String title;
  bool isDone;
}

class SessionRecord {
  SessionRecord({required this.mode, required this.completedAt});

  final FocusMode mode;
  final DateTime completedAt;
}

class DailyFocusRecord {
  DailyFocusRecord({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
      };

  factory DailyFocusRecord.fromJson(Map<String, dynamic> json) {
    return DailyFocusRecord(
      date: DateTime.parse(json['date'] as String),
      minutes: (json['minutes'] as num).toInt(),
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showSessionFinished(
    FocusMode finishedMode, {
    String languageCode = 'tr',
  }) async {
    final isEnglish = languageCode == 'en';
    final title = finishedMode == FocusMode.work
        ? (isEnglish ? 'Pomodoro complete' : 'Pomodoro tamamlandı')
        : (isEnglish ? 'Break finished' : 'Mola bitti');
    final body = finishedMode == FocusMode.work
        ? (isEnglish
            ? 'You can take a break or start a new focus session.'
            : 'Şimdi mola veya yeni odak süresine geçebilirsiniz.')
        : (isEnglish
            ? 'You can return to focus mode.'
            : 'Tekrar odaklanma moduna geçebilirsiniz.');

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro',
      channelDescription: 'Pomodoro zamanlayıcı bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: finishedMode.name,
    );
  }
}

class GeminiPomodoroApp extends StatefulWidget {
  const GeminiPomodoroApp({super.key, this.locale});

  final Locale? locale;

  @override
  State<GeminiPomodoroApp> createState() => _GeminiPomodoroAppState();
}

class _GeminiPomodoroAppState extends State<GeminiPomodoroApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale ?? const Locale('tr');
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    if (widget.locale != null) return;

    final settings = await AppSettings.load();
    if (!mounted) return;

    setState(() {
      _locale = Locale(settings.languageCode);
    });
  }

  Future<void> _updateLocale(Locale locale) async {
    final settings = await AppSettings.load();
    await settings.copyWith(languageCode: locale.languageCode).save();
    if (!mounted) return;

    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sumera Pomodoro',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('tr');

        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }

        return const Locale('tr');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF10111A),
        cardColor: const Color(0xFF171A27),
      ),
      home: PomodoroHomePage(
        onLanguageChanged: _updateLocale,
      ),
    );
  }
}

class PomodoroHomePage extends StatefulWidget {
  const PomodoroHomePage({super.key, this.onLanguageChanged});

  final ValueChanged<Locale>? onLanguageChanged;

  @override
  State<PomodoroHomePage> createState() => _PomodoroHomePageState();
}

class _PomodoroHomePageState extends State<PomodoroHomePage> {
  AppSettings _settings = AppSettings();
  FocusMode _selectedMode = FocusMode.work;
  int _secondsRemaining = 25 * 60;
  final ValueNotifier<int> _timeNotifier = ValueNotifier<int>(25 * 60);
  Timer? _timer;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  final TextEditingController _taskController = TextEditingController();
  List<TaskItem> _tasks = [];
  final List<SessionRecord> _sessionHistory = [];
  List<DailyFocusRecord> _dailyFocus = [];

  static String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _syncTimerValue(int value) {
    _secondsRemaining = value;
    _timeNotifier.value = value;
  }

  int get _currentDuration {
    switch (_selectedMode) {
      case FocusMode.work:
        return _settings.workMinutes * 60;
      case FocusMode.shortBreak:
      case FocusMode.longBreak:
        return _settings.breakMinutes * 60;
    }
  }

  double get _progress {
    final total = _currentDuration.toDouble();
    final elapsed = total - _secondsRemaining;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
  }

  String get _formattedTime => _formatDuration(_secondsRemaining);

  String get _modeTitle {
    switch (_selectedMode) {
      case FocusMode.work:
        return AppStrings.of(context, 'focusMode');
      case FocusMode.shortBreak:
      case FocusMode.longBreak:
        return AppStrings.of(context, 'breakMode');
    }
  }

  String get _modeDescription {
    switch (_selectedMode) {
      case FocusMode.work:
        return AppStrings.of(context, 'focusDescription');
      case FocusMode.shortBreak:
      case FocusMode.longBreak:
        return AppStrings.of(context, 'shortBreakDescription');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDailyFocus();
  }

  Future<void> _loadSettings() async {
    final loaded = await AppSettings.load();
    if (!mounted) return;

    setState(() {
      _settings = loaded;
      _syncTimerValue(_settings.workMinutes * 60);
      _tasks = [];
    });
  }

  Future<void> _loadDailyFocus() async {
    try {
      await SupabaseService.ensureAuthenticated();
      final cloudRecords = await SupabaseService.getFocusSessions();
      if (!mounted) return;

      final records = cloudRecords
          .map((item) => DailyFocusRecord(
                date: DateTime.parse(item['date'] as String),
                minutes: (item['minutes'] as num).toInt(),
              ))
          .toList();

      setState(() => _dailyFocus = records);
      return;
    } catch (_) {
      // Fallback to local storage when Supabase is unavailable.
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('daily_focus_records');
    if (!mounted) return;

    if (raw == null || raw.isEmpty) {
      setState(() => _dailyFocus = []);
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final records = decoded
        .map((item) => DailyFocusRecord.fromJson(item as Map<String, dynamic>))
        .toList();

    setState(() => _dailyFocus = records);
  }

  Future<void> _saveDailyFocus() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(
      _dailyFocus.map((record) => record.toJson()).toList(),
    );
    await prefs.setString('daily_focus_records', data);
  }

  Future<void> _saveSettings() async {
    await _settings.save();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _syncTimerValue(_secondsRemaining - 1);
        });
      } else {
        _timer?.cancel();
        _timer = null;
        _handleSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() => _syncTimerValue(_currentDuration));
  }

  void _selectMode(FocusMode mode) {
    _pauseTimer();
    setState(() {
      _selectedMode = mode;
      _syncTimerValue(_currentDuration);
    });
  }

  void _handleSessionComplete() {
    final finishedMode = _selectedMode;
    final nextMode = _settings.enableAutoAdvance
        ? () {
            if (finishedMode == FocusMode.work) {
              _completedPomodoros += 1;
              return _completedPomodoros % 4 == 0
                  ? FocusMode.longBreak
                  : FocusMode.shortBreak;
            }
            return FocusMode.work;
          }()
        : _selectedMode;

    if (finishedMode == FocusMode.work) {
      _addFocusMinutesToToday(_settings.workMinutes);
    }

    setState(() {
      _isRunning = false;
      _selectedMode = nextMode;
      _syncTimerValue(_currentDuration);
      _sessionHistory.add(
        SessionRecord(mode: finishedMode, completedAt: DateTime.now()),
      );
    });

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        _settings.enableNotifications) {
      NotificationService.showSessionFinished(
        finishedMode,
        languageCode: _settings.languageCode,
      );
    }

    final message = finishedMode == FocusMode.work
        ? AppStrings.of(context, 'sessionFinishWork')
        : AppStrings.of(context, 'sessionFinishBreak');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
      ),
    );
  }

  Future<void> _addTask() async {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    final task = TaskItem(title: text);
    setState(() {
      _tasks.add(task);
      _taskController.clear();
    });

    try {
      await SupabaseService.saveTask(text, isDone: false);
    } catch (_) {
      // Local-only fallback continues silently.
    }
  }

  Future<void> _toggleTask(int index) async {
    final task = _tasks[index];
    final nextValue = !task.isDone;
    setState(() {
      task.isDone = nextValue;
    });

    try {
      final cloudTask = await SupabaseService.getTasks();
      final match = cloudTask.firstWhere(
        (item) => item['title'] == task.title,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && match['id'] != null) {
        await SupabaseService.updateTask(match['id'] as String, isDone: nextValue);
      }
    } catch (_) {
      // Local-only fallback continues silently.
    }
  }

  void _setWorkMinutes(int value) {
    final safeValue = value.clamp(1, 180);
    setState(() {
      _settings = _settings.copyWith(workMinutes: safeValue);
      if (_selectedMode == FocusMode.work) {
        _syncTimerValue(safeValue * 60);
      }
    });
    _saveSettings();
  }

  void _setBreakMinutes(int value) {
    final safeValue = value.clamp(1, 60);
    setState(() {
      _settings = _settings.copyWith(breakMinutes: safeValue);
      if (_selectedMode == FocusMode.shortBreak || _selectedMode == FocusMode.longBreak) {
        _syncTimerValue(safeValue * 60);
      }
    });
    _saveSettings();
  }

  Future<void> _addFocusMinutesToToday(int minutes) async {
    final today = DateTime.now();
    final normalizedDate = DateTime(today.year, today.month, today.day);

    final existingIndex = _dailyFocus.indexWhere(
      (record) => record.date.year == normalizedDate.year &&
          record.date.month == normalizedDate.month &&
          record.date.day == normalizedDate.day,
    );

    if (existingIndex >= 0) {
      final existing = _dailyFocus[existingIndex];
      _dailyFocus[existingIndex] = DailyFocusRecord(
        date: existing.date,
        minutes: existing.minutes + minutes,
      );
    } else {
      _dailyFocus.add(DailyFocusRecord(date: normalizedDate, minutes: minutes));
    }

    _dailyFocus.sort((a, b) => a.date.compareTo(b.date));
    _saveDailyFocus();

    try {
      final dateKey = normalizedDate.toIso8601String().split('T').first;
      final current = _dailyFocus.firstWhere(
        (record) => record.date.year == normalizedDate.year &&
            record.date.month == normalizedDate.month &&
            record.date.day == normalizedDate.day,
        orElse: () => DailyFocusRecord(date: normalizedDate, minutes: minutes),
      );
      await SupabaseService.saveFocusSession(
        date: dateKey,
        minutes: current.minutes,
      );
    } catch (_) {
      // Local fallback is already persisted above.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeNotifier.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _showModeOverlay() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF10111A).withAlpha(200),
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF10111A),
          child: ValueListenableBuilder<int>(
            valueListenable: _timeNotifier,
            builder: (context, remaining, _) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10111A), Color(0xFF111827)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            iconSize: 28,
                            splashRadius: 22,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 22,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF4CC9F0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatDuration(remaining),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 150,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneTasks = _tasks.where((task) => task.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context, 'appTitle')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language_rounded),
            onSelected: (locale) {
              widget.onLanguageChanged?.call(locale);
            },
            itemBuilder: (_) => AppStrings.supportedLocales.map((locale) {
              final label = locale.languageCode == 'tr' ? 'Türkçe' : 'English';
              return PopupMenuItem<Locale>(
                value: locale,
                child: Text(label),
              );
            }).toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                key: const ValueKey('mode-description'),
                behavior: HitTestBehavior.opaque,
                onTap: _showModeOverlay,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4CC9F0)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: _showModeOverlay,
                          icon: const Icon(Icons.fullscreen_rounded),
                          splashRadius: 20,
                          color: Colors.white70,
                          tooltip: 'Tam ekran',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _modeDescription,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [FocusMode.work, FocusMode.shortBreak].map((mode) {
                          final isSelected = mode == _selectedMode ||
                              (mode == FocusMode.shortBreak &&
                                  (_selectedMode == FocusMode.shortBreak ||
                                   _selectedMode == FocusMode.longBreak));
                          final label = switch (mode) {
                            FocusMode.work => AppStrings.of(context, 'workMode'),
                            FocusMode.shortBreak => AppStrings.of(context, 'breakMode'),
                            FocusMode.longBreak => AppStrings.of(context, 'breakMode'),
                          };

                          return ChoiceChip(
                            selected: isSelected,
                            label: Text(label),
                            onSelected: (_) => _selectMode(mode),
                            selectedColor: Colors.white.withAlpha(60),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Colors.white24),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 14,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                _modeTitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formattedTime,
                                style: const TextStyle(
                                  fontSize: 52,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _isRunning ? null : _startTimer,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(AppStrings.of(context, 'start')),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _pauseTimer,
                            icon: const Icon(Icons.pause_rounded),
                            label: Text(AppStrings.of(context, 'pause')),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: _resetTimer,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(AppStrings.of(context, 'reset')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: AppStrings.of(context, 'completed'),
                      value: '$_completedPomodoros',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: AppStrings.of(context, 'tasks'),
                      value: '$doneTasks/${_tasks.length}',
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context, 'settings'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppStrings.of(context, 'notifications')),
                        subtitle: Text(AppStrings.of(context, 'notificationsSubtitle')),
                        value: _settings.enableNotifications,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(enableNotifications: value);
                          });
                          _saveSettings();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppStrings.of(context, 'autoAdvance')),
                        subtitle: Text(AppStrings.of(context, 'autoAdvanceSubtitle')),
                        value: _settings.enableAutoAdvance,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(enableAutoAdvance: value);
                          });
                          _saveSettings();
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingsCard(
                        child: Column(
                          children: [
                            _DurationSettingRow(
                              label: AppStrings.of(context, 'workDuration'),
                              value: _settings.workMinutes,
                              min: 1,
                              max: 180,
                              onChanged: _setWorkMinutes,
                              active: _selectedMode == FocusMode.work,
                            ),
                            const SizedBox(height: 8),
                            Divider(color: Colors.white12),
                            const SizedBox(height: 8),
                            _DurationSettingRow(
                              label: AppStrings.of(context, 'breakDuration'),
                              value: _settings.breakMinutes,
                              min: 1,
                              max: 60,
                              onChanged: _setBreakMinutes,
                              active: _selectedMode == FocusMode.shortBreak ||
                                  _selectedMode == FocusMode.longBreak,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.of(context, 'dailyFocus'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppStrings.of(context, 'weeklyFocus'),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DailyFocusChart(records: _dailyFocus),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context, 'taskList'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _taskController,
                              decoration: InputDecoration(
                                hintText: AppStrings.of(context, 'newTaskHint'),
                                border: const OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _addTask(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_tasks.isEmpty)
                        Text(AppStrings.of(context, 'noTasks'))
                      else
                        ..._tasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _toggleTask(index),
                              child: Row(
                                children: [
                                  Icon(
                                    task.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: task.isDone
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        decoration: task.isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: task.isDone
                                            ? Colors.white60
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context, 'today'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_sessionHistory.isEmpty)
                        Text(AppStrings.of(context, 'noHistory'))
                      else
                        ..._sessionHistory.reversed.take(5).map((record) {
                          final label = switch (record.mode) {
                            FocusMode.work => AppStrings.of(context, 'workMode'),
                            FocusMode.shortBreak => AppStrings.of(context, 'shortBreakMode'),
                            FocusMode.longBreak => AppStrings.of(context, 'longBreakMode'),
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• ${record.completedAt.hour.toString().padLeft(2, '0')}:${record.completedAt.minute.toString().padLeft(2, '0')} — $label',
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A27),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DurationSettingRow extends StatelessWidget {
  const _DurationSettingRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.active,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6C63FF).withAlpha(35) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF6C63FF) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$value ${AppStrings.of(context, 'minutes')}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider.adaptive(
            min: min.toDouble(),
            max: max.toDouble(),
            value: value.toDouble(),
            divisions: (max - min).clamp(1, 59),
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }
}

class _DailyFocusChart extends StatelessWidget {
  const _DailyFocusChart({required this.records});

  final List<DailyFocusRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastSevenDays = List.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day - (6 - index));
      final existing = records.firstWhere(
        (record) =>
            record.date.year == date.year &&
            record.date.month == date.month &&
            record.date.day == date.day,
        orElse: () => DailyFocusRecord(date: date, minutes: 0),
      );
      return existing;
    });

    final maxMinutes = lastSevenDays.fold<int>(
      1,
      (previousValue, element) => element.minutes > previousValue ? element.minutes : previousValue,
    );

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: lastSevenDays.map((record) {
          final height = maxMinutes <= 0 ? 0.0 : (record.minutes / maxMinutes) * 100;
          final label = '${record.date.day}/${record.date.month}';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${record.minutes}',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: height.clamp(8.0, 110.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CC9F0), Color(0xFF6C63FF)],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF6C63FF)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
