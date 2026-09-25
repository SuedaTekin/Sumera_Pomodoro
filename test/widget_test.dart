import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomodoro_app/main.dart';

void main() {
  testWidgets('Gemini Pomodoro app loads in Turkish by default', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pump();

    expect(find.text('Gemini Pomodoro'), findsOneWidget);
    expect(find.text('Odak Modu'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('Gemini Pomodoro app can render English strings', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp(locale: Locale('en')));
    await tester.pump();

    expect(find.text('Focus Mode'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
