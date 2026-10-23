import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'achievements.dart';
import 'brand.dart';
import 'controller.dart';
import 'models.dart';
import 'remote_config.dart';
import 'review.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sky_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/timer_screen.dart';
import 'strings.dart';

class SumeraApp extends StatelessWidget {
  const SumeraApp({super.key, required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            locale: Locale(controller.languageCode),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildTheme(),
            home:
                controller.onboarded
                    ? HomeShell(controller: controller)
                    : OnboardingScreen(controller: controller),
          ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final StreamSubscription<FocusMode> _completions;
  late final StreamSubscription<List<Achievement>> _unlocks;
  late final ReviewPrompter _review;
  bool _blockingUpdateShown = false;

  PomodoroController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _review = ReviewPrompter(c.prefs);
    _completions = c.completions.listen(_onCompleted);
    _unlocks = c.unlocks.listen(_onUnlocked);
    c.addListener(_checkRequiredUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRequiredUpdate());
  }

  @override
  void dispose() {
    c.removeListener(_checkRequiredUpdate);
    _completions.cancel();
    _unlocks.cancel();
    super.dispose();
  }

  /// Blocks the app when the remote config marks this version unsupported.
  void _checkRequiredUpdate() {
    final config = c.remoteConfig;
    if (_blockingUpdateShown || !config.updateRequired || !mounted) return;
    _blockingUpdateShown = true;
    final lang = Localizations.localeOf(context).languageCode;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const Icon(Icons.system_update_rounded, size: 40),
              title: Text(context.tr('updateRequired')),
              content: Text(
                config.updateMessage?.resolve(lang) ??
                    context.tr('updateRequiredBody'),
              ),
              actions: [
                FilledButton(
                  onPressed: () => openExternal(config.storeUrl),
                  child: Text(context.tr('update')),
                ),
              ],
            ),
          ),
    );
  }

  void _onCompleted(FocusMode finished) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              finished == FocusMode.work
                  ? 'sessionFinishWork'
                  : 'sessionFinishBreak',
            ),
          ),
        ),
      );
    if (finished == FocusMode.work) {
      _review.maybeAsk(
        totalPomodoros: c.totalPomodoros,
        goalJustReached: c.todayPomodoros == c.settings.dailyGoal,
      );
    }
  }

  void _onUnlocked(List<Achievement> earned) {
    if (!mounted || !c.remoteConfig.feature('achievements')) return;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder:
                  (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Brand.violet, Brand.deep]),
                ),
                child: Icon(earned.first.icon, color: Colors.white, size: 44),
              ),
            ),
            title: Text(context.tr('newBadge')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in earned) ...[
                  Text(
                    context.tr(a.titleKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(a.descriptionKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Brand.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  setState(() => _index = 1);
                },
                child: Text(context.tr('skyTitle')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('close')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSky = c.remoteConfig.feature('sky');
    final pages = <(Widget, IconData, IconData, String)>[
      (
        TimerScreen(controller: c),
        Icons.timer_outlined,
        Icons.timer_rounded,
        'timer',
      ),
      if (showSky)
        (
          SkyScreen(controller: c),
          Icons.auto_awesome_outlined,
          Icons.auto_awesome,
          'sky',
        ),
      (
        StatsScreen(controller: c),
        Icons.insights_outlined,
        Icons.insights_rounded,
        'stats',
      ),
      (
        TasksScreen(controller: c),
        Icons.checklist_outlined,
        Icons.checklist_rounded,
        'tasks',
      ),
      (
        SettingsScreen(controller: c),
        Icons.settings_outlined,
        Icons.settings_rounded,
        'settings',
      ),
    ];
    final index = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          // Hidden tabs keep their state but stop their animations.
          for (final (i, p) in pages.indexed)
            TickerMode(enabled: i == index, child: p.$1),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final p in pages)
            NavigationDestination(
              icon: Icon(p.$2),
              selectedIcon: Icon(p.$3),
              label: context.tr(p.$4),
            ),
        ],
      ),
    );
  }
}
