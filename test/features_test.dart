import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/achievements.dart';
import 'package:pomodoro_app/src/app.dart';
import 'package:pomodoro_app/src/controller.dart';
import 'package:pomodoro_app/src/models.dart';
import 'package:pomodoro_app/src/review.dart';
import 'package:pomodoro_app/src/services.dart';
import 'package:pomodoro_app/src/sounds.dart';
import 'package:pomodoro_app/src/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSound extends SoundPlayer {
  final calls = <String>[];

  @override
  Future<void> play(AmbientSound sound, int volume) async =>
      calls.add('play:${sound.name}');

  @override
  Future<void> preview(
    AmbientSound sound,
    int volume, {
    bool keep = false,
  }) async =>
      calls.add('preview:${sound.name}');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {}
}

SessionRecord focus(DateTime at, {int minutes = 25, String? task}) =>
    SessionRecord(
      mode: FocusMode.work,
      completedAt: at,
      minutes: minutes,
      taskId: task,
    );

Future<PomodoroController> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {'onboarded': true},
  SoundPlayer? sound,
}) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final controller = PomodoroController(
    await AppStorage.open(),
    forcedLanguage: 'en',
    sound: sound,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(SumeraApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  test('every language has every key', () {
    final en = AppStrings.table['en']!;
    for (final entry in AppStrings.table.entries) {
      expect(entry.value.keys.toSet(), en.keys.toSet(), reason: entry.key);
      for (final text in entry.value.entries) {
        expect(text.value.trim(), isNotEmpty, reason: '${entry.key}.${text.key}');
      }
      expect(entry.value['shareText'], contains('{duration}'));
    }
    for (final a in achievements) {
      expect(en.containsKey(a.titleKey), isTrue, reason: a.titleKey);
      expect(en.containsKey(a.descriptionKey), isTrue, reason: a.descriptionKey);
    }
    for (final s in AmbientSound.values) {
      expect(en.containsKey(s.labelKey), isTrue, reason: s.labelKey);
    }
  });

  test('achievement stats: streaks, marathon, early bird', () {
    final history = [
      for (var d = 1; d <= 3; d++) focus(DateTime(2026, 10, d, 10)),
      for (var i = 0; i < 8; i++) focus(DateTime(2026, 10, 10, 9 + i)),
      focus(DateTime(2026, 10, 12, 6, 50)), // started 06:25
    ];
    final s = AchievementStats.from(history, 8);
    expect(s.bestStreak, 3);
    expect(s.bestDay, 8);
    expect(s.goalDays, 1);
    expect(s.earlyBird, isTrue);
    expect(s.nightOwl, isFalse);
    final unlocked = {for (final a in achievements) if (a.test(s)) a.id};
    expect(unlocked, containsAll(['first', 'ten', 'goal', 'streak3', 'marathon', 'early']));
    expect(unlocked, isNot(contains('streak7')));
  });

  test('insights compare weeks and find the best hour', () {
    final now = DateTime(2026, 10, 22, 18);
    final history = [
      focus(DateTime(2026, 10, 21, 10, 25)),
      focus(DateTime(2026, 10, 20, 10, 30)),
      focus(DateTime(2026, 10, 12, 15, 25)),
    ];
    final insights = Insights.from(history, now);
    expect(insights.thisWeek, 50);
    expect(insights.lastWeek, 25);
    expect(insights.change, 100);
    expect(insights.bestHour, 10);
  });

  test('review is asked only at milestones and not too often', () async {
    SharedPreferences.setMockInitialValues({});
    final prompter = ReviewPrompter(await SharedPreferences.getInstance());
    expect(prompter.shouldAsk(totalPomodoros: 4, goalJustReached: false), isFalse);
    expect(prompter.shouldAsk(totalPomodoros: 5, goalJustReached: false), isTrue);
    expect(prompter.shouldAsk(totalPomodoros: 2, goalJustReached: true), isFalse);

    SharedPreferences.setMockInitialValues({
      'review_asked_at': DateTime.now().millisecondsSinceEpoch,
    });
    final recent = ReviewPrompter(await SharedPreferences.getInstance());
    expect(recent.shouldAsk(totalPomodoros: 25, goalJustReached: false), isFalse);
  });

  testWidgets('onboarding applies the chosen rhythm and goal', (tester) async {
    final c = await pumpApp(tester, prefs: const {});
    expect(find.text('Focus. Rest. Shine.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep work'));
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Allow notifications'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(c.onboarded, isTrue);
    expect(c.settings.workMinutes, 50);
    expect(c.settings.dailyGoal, 9);
    expect(find.text('50:00'), findsOneWidget);
  });

  testWidgets('finishing a session earns a badge and plays sound only while focusing',
      (tester) async {
    final sound = FakeSound();
    final c = await pumpApp(tester, sound: sound);
    c.chooseSound(AmbientSound.rain);
    expect(sound.calls, contains('preview:rain'));

    c.remainingSeconds = 1;
    c.start();
    expect(sound.calls.last, 'play:rain');

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 1300)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(c.totalPomodoros, 1);
    expect(sound.calls.last, 'stop');
    expect(find.text('New badge!'), findsOneWidget);
    expect(find.text('First step'), findsWidgets);
  });

  testWidgets('sky shows the stars of this month', (tester) async {
    final now = DateTime.now();
    await pumpApp(
      tester,
      prefs: {
        'onboarded': true,
        'session_history': jsonEncode([
          // Fixed times keep both stars on today regardless of the clock.
          focus(DateTime(now.year, now.month, now.day, 9)).toJson(),
          focus(DateTime(now.year, now.month, now.day, 10)).toJson(),
        ]),
      },
    );
    await tester.tap(find.text('Sky'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('My sky'), findsOneWidget);
    expect(find.text('2 stars'), findsOneWidget);
    expect(find.text('Badges'.toUpperCase()), findsOneWidget);
  });
}
