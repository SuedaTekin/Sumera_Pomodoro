import 'package:flutter/material.dart';

import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../services.dart';
import '../strings.dart';
import '../widgets.dart';

typedef _Preset = ({String key, int work, int short, int long, IconData icon});

const List<_Preset> _presets = [
  (
    key: 'presetClassic',
    work: 25,
    short: 5,
    long: 15,
    icon: Icons.timer_rounded,
  ),
  (
    key: 'presetDeep',
    work: 50,
    short: 10,
    long: 20,
    icon: Icons.psychology_rounded,
  ),
  (key: 'presetQuick', work: 15, short: 3, long: 10, icon: Icons.bolt_rounded),
];

/// First-run introduction: what the app does, the user's rhythm, and the
/// notification permission with an explanation of why it is needed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  int _preset = 0;
  late int _goal = widget.controller.settings.dailyGoal;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    final p = _presets[_preset];
    widget.controller.completeOnboarding(
      widget.controller.settings.copyWith(
        workMinutes: p.work,
        shortBreakMinutes: p.short,
        longBreakMinutes: p.long,
        dailyGoal: _goal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.tr('skipIntro')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcome(context),
                  _rhythm(context),
                  _notifications(context),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? Brand.cyan : Brand.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    textStyle: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: Text(context.tr(_page < 2 ? 'next' : 'getStarted')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layout({
    required Widget hero,
    required String title,
    required String body,
    Widget? extra,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 24),
        Center(child: hero),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Brand.textSecondary,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 24), extra],
      ],
    );
  }

  Widget _welcome(BuildContext context) {
    return _layout(
      hero: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Image.asset('assets/branding/emblem.png', width: 150),
      ),
      title: context.tr('obWelcomeTitle'),
      body: context.tr('obWelcomeBody'),
    );
  }

  Widget _rhythm(BuildContext context) {
    final min = context.tr('minutesShort');
    return _layout(
      hero: const Icon(Icons.tune_rounded, size: 72, color: Brand.cyan),
      title: context.tr('obRhythmTitle'),
      body: context.tr('obRhythmBody'),
      extra: Column(
        children: [
          for (final (i, p) in _presets.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: i == _preset ? Brand.cyan : Brand.outline,
                    width: i == _preset ? 1.5 : 0.5,
                  ),
                ),
                child: ListTile(
                  onTap: () => setState(() => _preset = i),
                  leading: Icon(p.icon, color: Brand.chartBar),
                  title: Text(
                    context.tr(p.key),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${p.work} $min · ${p.short} $min · ${p.long} $min',
                  ),
                  trailing: Icon(
                    i == _preset
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: i == _preset ? Brand.cyan : Brand.textMuted,
                  ),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: NumberStepper(
                label: context.tr('dailyGoal'),
                valueLabel: '$_goal',
                value: _goal,
                range: AppSettings.dailyGoalRange,
                onChanged: (v) => setState(() => _goal = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifications(BuildContext context) {
    return _layout(
      hero: const Icon(
        Icons.notifications_active_rounded,
        size: 72,
        color: Brand.cyan,
      ),
      title: context.tr('obNotifyTitle'),
      body: context.tr('obNotifyBody'),
      extra: Center(
        child: OutlinedButton.icon(
          onPressed: NotificationService.requestPermission,
          icon: const Icon(Icons.notifications_rounded),
          label: Text(context.tr('allowNotifications')),
        ),
      ),
    );
  }
}
