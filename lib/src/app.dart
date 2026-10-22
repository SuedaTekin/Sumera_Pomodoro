import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'brand.dart';
import 'controller.dart';
import 'models.dart';
import 'screens/settings_screen.dart';
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
      builder: (context, _) => MaterialApp(
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
        home: HomeShell(controller: controller),
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

  @override
  void initState() {
    super.initState();
    _completions = widget.controller.completions.listen(_onCompleted);
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
  }

  @override
  void dispose() {
    _completions.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TimerScreen(controller: c),
          StatsScreen(controller: c),
          TasksScreen(controller: c),
          SettingsScreen(controller: c),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            selectedIcon: const Icon(Icons.timer_rounded),
            label: context.tr('timer'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: context.tr('stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist_rounded),
            label: context.tr('tasks'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('settings'),
          ),
        ],
      ),
    );
  }
}
