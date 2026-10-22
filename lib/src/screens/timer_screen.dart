import 'package:flutter/material.dart';

import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../remote_config.dart';
import '../strings.dart';
import '../widgets.dart';
import 'fullscreen_timer.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key, required this.controller});

  final PomodoroController controller;

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _pickTask(BuildContext context) {
    final c = controller;
    final open = c.tasks.where((t) => !t.isDone).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Brand.surface,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    context.tr('chooseTask'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: Text(context.tr('none')),
                  selected: c.activeTaskId == null,
                  onTap: () {
                    c.setActiveTask(null);
                    Navigator.pop(sheetContext);
                  },
                ),
                for (final task in open)
                  ListTile(
                    leading: const Icon(Icons.radio_button_unchecked_rounded),
                    title: Text(task.title),
                    trailing: Text(
                      '${c.pomodorosForTask(task.id)}',
                      style: const TextStyle(color: Brand.textMuted),
                    ),
                    selected: c.activeTaskId == task.id,
                    onTap: () {
                      c.setActiveTask(task.id);
                      Navigator.pop(sheetContext);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  String? _quote(BuildContext context) {
    final config = controller.remoteConfig;
    if (!config.feature('quotes')) return null;
    return config.quoteOfTheDay(
      Localizations.localeOf(context).languageCode,
      DateTime.now(),
    );
  }

  List<Widget> _remoteBanners(BuildContext context) {
    final remote = controller.remote;
    if (remote == null) return const [];
    final config = remote.config;
    final lang = Localizations.localeOf(context).languageCode;
    final banners = <Widget>[];

    if (remote.showUpdateNotice) {
      banners.add(
        AnnouncementCard(
          title: context.tr('updateAvailable'),
          message:
              config.updateMessage?.resolve(lang) ??
              context.tr('updateAvailableBody'),
          buttonText: context.tr('update'),
          onButton: () => openExternal(config.storeUrl),
          onDismiss: () => remote.dismissAnnouncement(remote.updateNoticeId),
          dismissTooltip: context.tr('dismiss'),
          style: 'success',
        ),
      );
    }

    final a = remote.visibleAnnouncement;
    if (a != null) {
      banners.add(
        AnnouncementCard(
          title: a.title?.resolve(lang),
          message: a.message.resolve(lang),
          buttonText:
              a.url == null
                  ? null
                  : a.buttonText?.resolve(lang) ?? context.tr('learnMore'),
          onButton: a.url == null ? null : () => openExternal(a.url!),
          onDismiss:
              a.dismissible ? () => remote.dismissAnnouncement(a.id) : null,
          dismissTooltip: context.tr('dismiss'),
          style: a.style,
        ),
      );
    }

    return [
      for (final b in banners) ...[b, const SizedBox(height: 12)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/branding/emblem.png',
                    width: 30,
                    height: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(kAppName, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              ..._remoteBanners(context),
              _ModeSelector(controller: c),
              const SizedBox(height: 16),
              _TimerCard(controller: c, format: _format),
              const SizedBox(height: 16),
              _GoalCard(controller: c),
              const SizedBox(height: 12),
              if (_quote(context) case final quote?) ...[
                _QuoteCard(text: quote),
                const SizedBox(height: 12),
              ],
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(Icons.flag_rounded, color: Brand.cyan),
                  title: Text(
                    context.tr('activeTask'),
                    style: const TextStyle(
                      color: Brand.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    c.activeTask?.title ?? context.tr('noActiveTask'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Brand.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.expand_more_rounded),
                  onTap: () => _pickTask(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FocusMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: controller.mode.accent.withAlpha(110),
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: Brand.outline),
      ),
      segments: [
        for (final mode in FocusMode.values)
          ButtonSegment(
            value: mode,
            label: Text(
              context.tr(mode.labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selected: {controller.mode},
      onSelectionChanged: (s) => controller.selectMode(s.first),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.controller, required this.format});

  final PomodoroController controller;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final interval = c.settings.longBreakInterval;
    final buttonKey =
        c.isRunning
            ? 'pause'
            : c.isPristine
            ? 'start'
            : 'resume';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.mode.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Semantics(
                  label:
                      '${context.tr(c.mode.labelKey)} ${format(c.remainingSeconds)}',
                  child: TimerRing(
                    progress: c.progress,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(c.mode.labelKey).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          format(c.remainingSeconds),
                          style: const TextStyle(
                            fontSize: 60,
                            height: 1.1,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(c.mode.descriptionKey),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (c.remoteConfig.feature('fullscreen'))
                  Positioned(
                    top: -14,
                    right: -6,
                    child: IconButton(
                      onPressed: () => openFullscreenTimer(context, c),
                      tooltip: context.tr('fullscreen'),
                      color: Colors.white,
                      iconSize: 28,
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: context.tr('cycle'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(interval, (index) {
                final filled = index < c.cyclePosition;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: filled ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: filled ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: c.isPristine ? null : c.reset,
                tooltip: context.tr('reset'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(40),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withAlpha(15),
                  disabledForegroundColor: Colors.white38,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: c.toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: c.mode.gradient.last,
                  minimumSize: const Size(150, 56),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: Icon(
                  c.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 26,
                ),
                label: Text(context.tr(buttonKey)),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: c.skip,
                tooltip: context.tr('skip'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(40),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    final done = controller.todayPomodoros;
    final goal = controller.settings.dailyGoal;
    final reached = done >= goal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  reached ? Icons.emoji_events_rounded : Icons.today_rounded,
                  color: reached ? Brand.success : Brand.cyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reached
                        ? context.tr('goalReached')
                        : context.tr('dailyGoal'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$done / $goal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (done / goal).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Brand.surfaceHigh,
                color: reached ? Brand.success : Brand.chartBar,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.tr('focusTime')}: '
              '${AppStrings.duration(context, controller.todayFocusMinutes)}',
              style: const TextStyle(color: Brand.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote_rounded, color: Brand.chartBar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('quoteOfDay'),
                    style: const TextStyle(
                      color: Brand.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
