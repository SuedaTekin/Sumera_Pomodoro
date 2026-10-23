import 'package:flutter/material.dart';

import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../remote_config.dart';
import '../sounds.dart';
import '../strings.dart';
import '../sync.dart';
import '../widgets.dart';
import 'sound_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final PomodoroController controller;

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.tr('resetStats')),
            content: Text(context.tr('resetStatsConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('delete')),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    controller.resetStats();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('statsReset'))));
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.tr('privacyPolicy')),
            content: Text(context.tr('privacyText')),
            actions: [
              TextButton(
                onPressed:
                    () =>
                        openExternal(controller.remoteConfig.privacyPolicyUrl),
                child: Text(context.tr('learnMore')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('close')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        final min = context.tr('minutesShort');
        void update(AppSettings next) => controller.updateSettings(next);

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SectionHeader(context.tr('durations')),
              Card(
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    NumberStepper(
                      label: context.tr('workMode'),
                      valueLabel: '${s.workMinutes} $min',
                      value: s.workMinutes,
                      range: AppSettings.workRange,
                      step: 5,
                      color: FocusMode.work.accent,
                      onChanged: (v) => update(s.copyWith(workMinutes: v)),
                    ),
                    NumberStepper(
                      label: context.tr('shortBreakMode'),
                      valueLabel: '${s.shortBreakMinutes} $min',
                      value: s.shortBreakMinutes,
                      range: AppSettings.shortBreakRange,
                      color: FocusMode.shortBreak.accent,
                      onChanged:
                          (v) => update(s.copyWith(shortBreakMinutes: v)),
                    ),
                    NumberStepper(
                      label: context.tr('longBreakMode'),
                      valueLabel: '${s.longBreakMinutes} $min',
                      value: s.longBreakMinutes,
                      range: AppSettings.longBreakRange,
                      step: 5,
                      color: FocusMode.longBreak.accent,
                      onChanged: (v) => update(s.copyWith(longBreakMinutes: v)),
                    ),
                    const Divider(indent: 16, endIndent: 16, height: 16),
                    NumberStepper(
                      label: context.tr('longBreakEvery'),
                      valueLabel: '${s.longBreakInterval}',
                      value: s.longBreakInterval,
                      range: AppSettings.longBreakIntervalRange,
                      onChanged:
                          (v) => update(s.copyWith(longBreakInterval: v)),
                    ),
                    NumberStepper(
                      label: context.tr('dailyGoal'),
                      valueLabel: '${s.dailyGoal}',
                      value: s.dailyGoal,
                      range: AppSettings.dailyGoalRange,
                      onChanged: (v) => update(s.copyWith(dailyGoal: v)),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (controller.remoteConfig.feature('sounds')) ...[
                SectionHeader(context.tr('focusSound')),
                Card(
                  child: ListTile(
                    leading: Icon(
                      AmbientSoundInfo.parse(s.ambientSound).icon,
                      color: Brand.cyan,
                    ),
                    title: Text(
                      context.tr(
                        AmbientSoundInfo.parse(s.ambientSound).labelKey,
                      ),
                    ),
                    subtitle: Text(context.tr('focusSoundSubtitle')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showSoundSheet(context, controller),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SectionHeader(context.tr('behavior')),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(context.tr('autoAdvance')),
                      subtitle: Text(context.tr('autoAdvanceSubtitle')),
                      value: s.enableAutoAdvance,
                      onChanged:
                          (v) => update(s.copyWith(enableAutoAdvance: v)),
                    ),
                    SwitchListTile(
                      title: Text(context.tr('autoStart')),
                      subtitle: Text(context.tr('autoStartSubtitle')),
                      value: s.enableAutoStart,
                      onChanged:
                          s.enableAutoAdvance
                              ? (v) => update(s.copyWith(enableAutoStart: v))
                              : null,
                    ),
                    SwitchListTile(
                      title: Text(context.tr('notifications')),
                      subtitle: Text(context.tr('notificationsSubtitle')),
                      value: s.enableNotifications,
                      onChanged:
                          (v) => update(s.copyWith(enableNotifications: v)),
                    ),
                    SwitchListTile(
                      title: Text(context.tr('showOngoing')),
                      subtitle: Text(context.tr('showOngoingSubtitle')),
                      value: s.showOngoing,
                      onChanged: (v) => update(s.copyWith(showOngoing: v)),
                    ),
                    SwitchListTile(
                      title: Text(context.tr('keepScreenOn')),
                      subtitle: Text(context.tr('keepScreenOnSubtitle')),
                      value: s.keepScreenOn,
                      onChanged: (v) => update(s.copyWith(keepScreenOn: v)),
                    ),
                    SwitchListTile(
                      title: Text(context.tr('haptics')),
                      subtitle: Text(context.tr('hapticsSubtitle')),
                      value: s.enableHaptics,
                      onChanged: (v) => update(s.copyWith(enableHaptics: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(context.tr('language')),
              Card(
                child: Column(
                  children: [
                    for (final (code, label) in [
                      (
                        AppSettings.systemLanguage,
                        context.tr('systemLanguage'),
                      ),
                      for (final l in AppStrings.supportedLocales)
                        (
                          l.languageCode,
                          AppStrings.languageNames[l.languageCode]!,
                        ),
                    ])
                      ListTile(
                        title: Text(label),
                        trailing:
                            s.languageCode == code
                                ? const Icon(
                                  Icons.check_rounded,
                                  color: Brand.cyan,
                                )
                                : null,
                        onTap: () => update(s.copyWith(languageCode: code)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (controller.sync case final sync? when sync.isAvailable) ...[
                SectionHeader(context.tr('cloud')),
                ListenableBuilder(
                  listenable: sync,
                  builder:
                      (context, _) =>
                          _CloudCard(controller: controller, sync: sync),
                ),
                const SizedBox(height: 16),
              ],
              SectionHeader(context.tr('data')),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(context.tr('resetStats')),
                  onTap: () => _confirmReset(context),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(context.tr('about')),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/emblem.png',
                          width: 36,
                          height: 36,
                        ),
                      ),
                      title: const Text(kAppName),
                      subtitle: Text('${context.tr('version')} $kAppVersion'),
                    ),
                    if (controller.remoteConfig.updateAvailable)
                      ListTile(
                        leading: const Icon(
                          Icons.system_update_rounded,
                          color: Brand.success,
                        ),
                        title: Text(context.tr('updateAvailable')),
                        onTap:
                            () =>
                                openExternal(controller.remoteConfig.storeUrl),
                      ),
                    ListTile(
                      leading: const Icon(Icons.star_outline_rounded),
                      title: Text(context.tr('rateApp')),
                      onTap:
                          () => openExternal(controller.remoteConfig.storeUrl),
                    ),
                    if (controller.remoteConfig.feedbackEmail case final email?)
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: Text(context.tr('sendFeedback')),
                        subtitle: Text(email),
                        onTap:
                            () => openExternal(
                              Uri(
                                scheme: 'mailto',
                                path: email,
                                query: 'subject=$kAppName $kAppVersion',
                              ).toString(),
                            ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(context.tr('privacyPolicy')),
                      onTap: () => _showPrivacy(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(context.tr('licenses')),
                      onTap:
                          () => showLicensePage(
                            context: context,
                            applicationName: kAppName,
                            applicationVersion: kAppVersion,
                            applicationIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/branding/emblem.png',
                                width: 64,
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.controller, required this.sync});

  final PomodoroController controller;
  final SyncService sync;

  String _status(BuildContext context) {
    switch (sync.status) {
      case SyncStatus.syncing:
        return context.tr('syncing');
      case SyncStatus.failed:
        return context.tr('syncFailed');
      case SyncStatus.idle:
      case SyncStatus.synced:
        final at = sync.lastSyncedAt;
        if (at == null) return context.tr('syncNever');
        final loc = MaterialLocalizations.of(context);
        return '${context.tr('syncedAt')}: ${loc.formatShortMonthDay(at)} '
            '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true)}';
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.tr('deleteCloud')),
            content: Text(context.tr('deleteCloudConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('delete')),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await controller.deleteCloudData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(ok ? 'cloudDeleted' : 'cloudDeleteFailed')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = controller.settings.cloudSync;
    final failed = sync.status == SyncStatus.failed;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(context.tr('cloudSync')),
            subtitle: Text(context.tr('cloudSyncSubtitle')),
            value: enabled,
            onChanged:
                (v) => controller.updateSettings(
                  controller.settings.copyWith(cloudSync: v),
                ),
          ),
          if (enabled)
            ListTile(
              leading:
                  sync.status == SyncStatus.syncing
                      ? const SizedBox.square(
                        dimension: 24,
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : Icon(
                        failed
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_rounded,
                        color: failed ? Colors.orangeAccent : Brand.success,
                      ),
              title: Text(context.tr('syncNow')),
              subtitle: Text(_status(context)),
              onTap:
                  sync.status == SyncStatus.syncing ? null : controller.syncNow,
            ),
          ListTile(
            leading: const Icon(
              Icons.cloud_off_outlined,
              color: Colors.redAccent,
            ),
            title: Text(context.tr('deleteCloud')),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }
}
