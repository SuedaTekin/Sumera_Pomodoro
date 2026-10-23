// Renders Play Store screenshots with real fonts and demo data.
//
//   $env:STORE_SHOTS=1; flutter test test/store_screenshots_test.dart
//
// Output: build/store_raw/<lang>_<n>.png (then run tool/frame_screenshots.py).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/app.dart';
import 'package:pomodoro_app/src/controller.dart';
import 'package:pomodoro_app/src/models.dart';
import 'package:pomodoro_app/src/screens/fullscreen_timer.dart';
import 'package:pomodoro_app/src/screens/sound_sheet.dart';
import 'package:pomodoro_app/src/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _enabled = Platform.environment.containsKey('STORE_SHOTS');
const _fonts = 'C:/src/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String f) async =>
      ByteData.sublistView(await File('$_fonts/$f').readAsBytes());
  // 'FlutterTest' is the test default for styles without a family; on a
  // phone those use the system font, which is Roboto on Android.
  for (final family in ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family);
    for (final f in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
      'roboto-italic.ttf',
    ]) {
      loader.addFont(read(f));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}

Map<String, Object> _demoData(String lang) {
  final rnd = Random(11);
  final now = DateTime.now();
  final names = lang == 'tr'
      ? ['Tez yazımı', 'Sunum hazırlığı', 'Kod incelemesi', 'İngilizce kelime']
      : ['Write thesis', 'Prepare slides', 'Code review', 'Read chapter 4'];
  final tasks = [
    for (final (i, n) in names.indexed)
      {'id': 't$i', 'title': n, 'done': i == 3, 'estimate': i == 0 ? 6 : 0},
  ];
  final history = <Map<String, dynamic>>[];
  for (var d = 40; d >= 1; d--) {
    final day = DateTime(now.year, now.month, now.day - d);
    final count = d % 9 == 0 ? 0 : 2 + rnd.nextInt(6);
    for (var i = 0; i < count; i++) {
      history.add(
        SessionRecord(
          mode: FocusMode.work,
          completedAt: day.add(Duration(hours: 9 + i, minutes: rnd.nextInt(30))),
          minutes: 25,
          taskId: 't${rnd.nextInt(3)}',
        ).toJson(),
      );
    }
  }
  for (var i = 0; i < 4; i++) {
    history.add(
      SessionRecord(
        mode: FocusMode.work,
        completedAt: DateTime(now.year, now.month, now.day, 8 + i, 40),
        minutes: 25,
        taskId: 't0',
      ).toJson(),
    );
  }
  return {
    'onboarded': true,
    'daily_goal': 6,
    'work_minutes': 25,
    'tasks': jsonEncode(tasks),
    'active_task': 't0',
    'session_history': jsonEncode(history),
    'remote_config_cache': jsonEncode({
      'quotes': {
        'tr': ['İlerleme, mükemmellikten iyidir.'],
        'en': ['Progress beats perfection.'],
      },
    }),
  };
}

void main() {
  for (final lang in ['tr', 'en']) {
    testWidgets('store screenshots $lang', skip: !_enabled, (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(_demoData(lang));
      final c = PomodoroController(await AppStorage.open(), forcedLanguage: lang);
      addTearDown(c.dispose);
      await tester.pumpWidget(SumeraApp(controller: c));
      await tester.pumpAndSettle();
      // Decode the emblem before the first shot so the app bar shows it.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/emblem.png'),
          tester.element(find.byType(HomeShell)),
        ),
      );
      await tester.pump();
      Directory('build/store_raw').createSync(recursive: true);

      var n = 0;
      Future<void> shot() async {
        await tester.pump(const Duration(milliseconds: 600));
        n++;
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../build/store_raw/${lang}_$n.png'),
        );
      }

      String tab(String tr, String en) => lang == 'tr' ? tr : en;

      // 1 Timer, running.
      c.remainingSeconds = 17 * 60 + 42;
      c.start();
      await shot();

      // 2 Sky.
      await tester.tap(find.text(tab('Gökyüzü', 'Sky')));
      await shot();

      // 3 Stats.
      await tester.tap(find.text(tab('İstatistik', 'Stats')));
      await tester.pumpAndSettle();
      await shot();

      // 4 Badges (sky scrolled down).
      await tester.tap(find.text(tab('Gökyüzü', 'Sky')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await shot();

      // 5 Full screen.
      await tester.tap(find.text(tab('Zamanlayıcı', 'Timer')));
      await tester.pump(const Duration(milliseconds: 300));
      openFullscreenTimer(
        tester.element(find.byType(HomeShell)),
        c,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await shot();
      Navigator.of(tester.element(find.byType(FullscreenTimerPage))).pop();
      await tester.pump(const Duration(milliseconds: 600));

      // 6 Focus sounds.
      c.updateSettings(c.settings.copyWith(ambientSound: 'rain'));
      showSoundSheet(tester.element(find.byType(HomeShell)), c);
      await tester.pump(const Duration(milliseconds: 600));
      await shot();

      c.pause();
    });
  }
}
