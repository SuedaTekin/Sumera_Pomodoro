import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomodoro_app/main.dart';

void main() {
  testWidgets('Sumera Pomodoro app loads in Turkish by default', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pump();

    expect(find.text('Sumera Pomodoro'), findsOneWidget);
    expect(find.text('Odak Modu'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('Task list starts empty so the user can add their own items', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pumpAndSettle();

    expect(find.text('Yazılım planını hazırla'), findsNothing);
    expect(find.text('Öncelikli görevi bitir'), findsNothing);
    expect(find.text('Henüz görev eklenmedi.'), findsOneWidget);
  });

  testWidgets('Users can customize work and break durations', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pumpAndSettle();

    expect(find.text('Çalışma süresi'), findsOneWidget);
    expect(find.text('Mola süresi'), findsOneWidget);
  });

  testWidgets('Tapping the focus description opens a full-screen view', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mode-description')));
    await tester.pumpAndSettle();

    expect(find.text('Konsantrasyonu koru'), findsOneWidget);
  });

  testWidgets('Full-screen timer keeps ticking while the dialog is open', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Başlat'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('mode-description')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('24:59'), findsWidgets);
  });

  testWidgets('Sumera Pomodoro app can render English strings', (WidgetTester tester) async {
    await tester.pumpWidget(const GeminiPomodoroApp(locale: Locale('en')));
    await tester.pump();

    expect(find.text('Focus Mode'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
