import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/app.dart';
import 'package:pomodoro_app/src/controller.dart';
import 'package:pomodoro_app/src/models.dart';
import 'package:pomodoro_app/src/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PomodoroController> pumpApp(
  WidgetTester tester, {
  String language = 'en',
}) async {
  // Tall surface so every card of the lazy lists is built.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = await AppStorage.open();
  final controller = PomodoroController(storage, forcedLanguage: language);
  addTearDown(controller.dispose);
  await tester.pumpWidget(SumeraApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarded': true});
  });

  testWidgets('renders Turkish strings', (tester) async {
    await pumpApp(tester, language: 'tr');

    expect(find.text('Sumera Pomodoro'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Başlat'), findsOneWidget);
    expect(find.text('İstatistik'), findsOneWidget);
  });

  testWidgets('start toggles to pause and back', (tester) async {
    final controller = await pumpApp(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Pause'), findsNothing);
    expect(controller.isRunning, isFalse);
  });

  testWidgets('duration stepper changes the focus length', (tester) async {
    final controller = await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(controller.settings.workMinutes, 30);
    expect(controller.remainingSeconds, 30 * 60);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('work_minutes'), 30);
  });

  testWidgets('tasks can be added and become the active task',
      (tester) async {
    final controller = await pumpApp(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write report');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Write report'), findsOneWidget);
    expect(controller.activeTask?.title, 'Write report');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tasks'), contains('Write report'));
  });

  testWidgets('stats screen shows history in the chart', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'session_history': jsonEncode([
        for (var i = 0; i < 3; i++)
          SessionRecord(
            mode: FocusMode.work,
            completedAt: now.subtract(Duration(minutes: i * 30)),
            minutes: 25,
          ).toJson(),
      ]),
    });
    final controller = await pumpApp(tester);

    expect(controller.todayPomodoros, 3);
    expect(controller.streak, 1);
    expect(controller.dayStats(7).last.minutes, 75);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Focus time by day'.toUpperCase()), findsOneWidget);
    expect(find.text('3 pomodoros'), findsOneWidget);
  });

  testWidgets('full screen mode opens, extends time and closes',
      (tester) async {
    final controller = await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('+5 min'));
    await tester.pump();
    expect(controller.totalSeconds, 30 * 60);
    expect(find.text('30:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
  });

  testWidgets('task estimate can be edited', (tester) async {
    final controller = await pumpApp(tester);
    controller.addTask('Read chapter');
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read chapter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).last);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.tasks.single.estimate, 2);
    expect(find.text('0 / 2 pomodoros'), findsOneWidget);
  });
}
