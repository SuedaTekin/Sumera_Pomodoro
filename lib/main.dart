import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await NotificationService.initialize();
  }

  runApp(const GeminiPomodoroApp());
}

enum FocusMode { work, shortBreak, longBreak }

class AppStrings {
  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];

  static const Map<String, Map<String, String>> _values = {
    'tr': {
      'appTitle': 'Sumera Pomodoro',
      'focusMode': 'Odak Modu',
      'shortBreakMode': 'Kısa Mola',
      'longBreakMode': 'Uzun Mola',
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
      'appTitle': 'Gemini Pomodoro',
      'focusMode': 'Focus Mode',
      'shortBreakMode': 'Short Break',
      'longBreakMode': 'Long Break',
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
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.enableNotifications = true,
    this.enableAutoAdvance = true,
    this.languageCode = 'tr',
  });

  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final bool enableNotifications;
  final bool enableAutoAdvance;
  final String languageCode;

  AppSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    bool? enableNotifications,
    bool? enableAutoAdvance,
    String? languageCode,
  }) {
    return AppSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableAutoAdvance: enableAutoAdvance ?? this.enableAutoAdvance,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      workMinutes: prefs.getInt('work_minutes') ?? 25,
      shortBreakMinutes: prefs.getInt('short_break_minutes') ?? 5,
      longBreakMinutes: prefs.getInt('long_break_minutes') ?? 15,
      enableNotifications: prefs.getBool('notifications_enabled') ?? true,
      enableAutoAdvance: prefs.getBool('auto_advance') ?? true,
      languageCode: prefs.getString('language_code') ?? 'tr',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('work_minutes', workMinutes);
    await prefs.setInt('short_break_minutes', shortBreakMinutes);
    await prefs.setInt('long_break_minutes', longBreakMinutes);
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
      title: 'Gemini Pomodoro',
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
  Timer? _timer;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  final TextEditingController _taskController = TextEditingController();
  List<TaskItem> _tasks = [];
  final List<SessionRecord> _sessionHistory = [];

  List<TaskItem> _defaultTasks() {
    final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
    return isTurkish
        ? [
            TaskItem(title: 'Yazılım planını hazırla'),
            TaskItem(title: 'Öncelikli görevi bitir'),
          ]
        : [
            TaskItem(title: 'Plan the software'),
            TaskItem(title: 'Finish the priority task'),
          ];
  }

  int get _currentDuration {
    switch (_selectedMode) {
      case FocusMode.work:
        return _settings.workMinutes * 60;
      case FocusMode.shortBreak:
        return _settings.shortBreakMinutes * 60;
      case FocusMode.longBreak:
        return _settings.longBreakMinutes * 60;
    }
  }

  double get _progress {
    final total = _currentDuration.toDouble();
    final elapsed = total - _secondsRemaining;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _modeTitle {
    switch (_selectedMode) {
      case FocusMode.work:
        return AppStrings.of(context, 'focusMode');
      case FocusMode.shortBreak:
        return AppStrings.of(context, 'shortBreakMode');
      case FocusMode.longBreak:
        return AppStrings.of(context, 'longBreakMode');
    }
  }

  String get _modeDescription {
    switch (_selectedMode) {
      case FocusMode.work:
        return AppStrings.of(context, 'focusDescription');
      case FocusMode.shortBreak:
        return AppStrings.of(context, 'shortBreakDescription');
      case FocusMode.longBreak:
        return AppStrings.of(context, 'longBreakDescription');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await AppSettings.load();
    if (!mounted) return;

    setState(() {
      _settings = loaded;
      _secondsRemaining = _settings.workMinutes * 60;
      _tasks = _defaultTasks();
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
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
    setState(() => _secondsRemaining = _currentDuration);
  }

  void _selectMode(FocusMode mode) {
    _pauseTimer();
    setState(() {
      _selectedMode = mode;
      _secondsRemaining = _currentDuration;
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

    setState(() {
      _isRunning = false;
      _selectedMode = nextMode;
      _secondsRemaining = _currentDuration;
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

  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(TaskItem(title: text));
      _taskController.clear();
    });
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isDone = !_tasks[index].isDone;
    });
  }

  void _setWorkMinutes(int value) {
    if (value < 15 || value > 60) return;
    setState(() {
      _settings = _settings.copyWith(workMinutes: value);
      if (_selectedMode == FocusMode.work) {
        _secondsRemaining = value * 60;
      }
    });
    _saveSettings();
  }

  void _setBreakMinutes(int value) {
    if (value < 3 || value > 30) return;
    setState(() {
      _settings = _settings.copyWith(shortBreakMinutes: value);
      if (_selectedMode == FocusMode.shortBreak) {
        _secondsRemaining = value * 60;
      }
    });
    _saveSettings();
  }

  void _setLongBreakMinutes(int value) {
    if (value < 10 || value > 45) return;
    setState(() {
      _settings = _settings.copyWith(longBreakMinutes: value);
      if (_selectedMode == FocusMode.longBreak) {
        _secondsRemaining = value * 60;
      }
    });
    _saveSettings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    super.dispose();
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4CC9F0)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Text(
                      _modeDescription,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: FocusMode.values.map((mode) {
                        final isSelected = mode == _selectedMode;
                        final label = switch (mode) {
                          FocusMode.work => AppStrings.of(context, 'workMode'),
                          FocusMode.shortBreak => AppStrings.of(context, 'shortBreakMode'),
                          FocusMode.longBreak => AppStrings.of(context, 'longBreakMode'),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DurationChip(
                            label: '${AppStrings.of(context, 'workMode')} ${_settings.workMinutes} ${AppStrings.of(context, 'minutes')}',
                            selected: _selectedMode == FocusMode.work,
                            onTap: () => _setWorkMinutes(25),
                          ),
                          _DurationChip(
                            label: '${AppStrings.of(context, 'shortBreakMode')} ${_settings.shortBreakMinutes} ${AppStrings.of(context, 'minutes')}',
                            selected: _selectedMode == FocusMode.shortBreak,
                            onTap: () => _setBreakMinutes(5),
                          ),
                          _DurationChip(
                            label: '${AppStrings.of(context, 'longBreakMode')} ${_settings.longBreakMinutes} ${AppStrings.of(context, 'minutes')}',
                            selected: _selectedMode == FocusMode.longBreak,
                            onTap: () => _setLongBreakMinutes(15),
                          ),
                        ],
                      ),
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

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF6C63FF),
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
