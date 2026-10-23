import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pomodoro_app/src/app.dart';
import 'package:pomodoro_app/src/brand.dart';
import 'package:pomodoro_app/src/controller.dart';
import 'package:pomodoro_app/src/remote_config.dart';
import 'package:pomodoro_app/src/services.dart';
import 'package:pomodoro_app/src/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> repoConfig() =>
    jsonDecode(File('remote/config.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStrings.overrides = const {};
  });

  group('published config', () {
    test('remote/config.json parses and does not block this version', () {
      final config = RemoteConfig.parse(repoConfig());
      expect(config.updateRequired, isFalse);
      expect(config.feature('fullscreen'), isTrue);
      expect(config.quoteOfTheDay('tr', DateTime(2026, 1, 1)), isNotNull);
      expect(config.defaults['workMinutes'], 25);
    });

    test('kAppVersion matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version =
          RegExp(r'^version:\s*([\d.]+)', multiLine: true).firstMatch(pubspec)!;
      expect(kAppVersion, version.group(1));
    });
  });

  group('parsing', () {
    test('compares versions numerically', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.2', '1.10'), -1);
      expect(compareVersions('2.0.0', '1.9.9'), 1);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });

    test('ignores malformed fields and unsafe links', () {
      final config = RemoteConfig.parse({
        'announcement': {
          'enabled': true,
          'id': 'a',
          'message': {'tr': 'Merhaba'},
          'url': 'javascript:alert(1)',
        },
        'update': {'minVersion': 'latest', 'latestVersion': 5},
        'features': {'heatmap': 'no', 'quotes': false},
        'defaults': {'workMinutes': '30'},
        'links': {'store': 'ftp://x', 'feedbackEmail': 'nope'},
      });
      expect(config.announcement!.url, isNull);
      expect(config.updateRequired, isFalse);
      expect(config.updateAvailable, isFalse);
      expect(config.feature('heatmap'), isTrue);
      expect(config.feature('quotes'), isFalse);
      expect(config.defaults, isEmpty);
      expect(config.storeUrl, kStoreUrl);
      expect(config.feedbackEmail, isNull);
    });
  });

  group('service', () {
    test('caches a good download and keeps it when later ones fail', () async {
      var body = jsonEncode({
        'features': {'quotes': false},
      });
      var status = 200;
      final client = MockClient((_) async => http.Response(body, status));
      final prefs = await SharedPreferences.getInstance();
      final service = RemoteConfigService(prefs, client: client);

      await service.refresh(force: true);
      expect(service.config.feature('quotes'), isFalse);

      body = '{ not json';
      await service.refresh(force: true);
      expect(service.config.feature('quotes'), isFalse);

      status = 500;
      await service.refresh(force: true);
      expect(service.config.feature('quotes'), isFalse);

      // A fresh service starts from the cache, before any network call.
      final restarted = RemoteConfigService(prefs, client: client);
      expect(restarted.config.feature('quotes'), isFalse);
    });

    test('does not refetch within the refresh interval', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final service = RemoteConfigService(
        await SharedPreferences.getInstance(),
        client: client,
      );
      await service.refresh(force: true);
      await service.refresh();
      expect(calls, 1);
    });
  });

  group('app', () {
    Future<PomodoroController> pumpWithConfig(
      WidgetTester tester,
      Map<String, dynamic> config,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'remote_config_cache': jsonEncode(config),
      });
      final storage = await AppStorage.open();
      final remote = RemoteConfigService(
        storage.prefs,
        client: MockClient((_) async => http.Response('', 404)),
      );
      final controller = PomodoroController(
        storage,
        remote: remote,
        forcedLanguage: 'en',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(SumeraApp(controller: controller));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('remote texts, defaults and announcements apply',
        (tester) async {
      await pumpWithConfig(tester, {
        'strings': {
          'en': {'start': "Let's go"},
        },
        'defaults': {'workMinutes': 50},
        'announcement': {
          'enabled': true,
          'id': 'promo-1',
          'title': {'en': 'Big news'},
          'message': {'en': 'Something new'},
        },
        'quotes': {
          'en': ['Stay sharp'],
        },
      });

      expect(find.text("Let's go"), findsOneWidget);
      expect(find.text('50:00'), findsOneWidget);
      expect(find.text('Big news'), findsOneWidget);
      expect(find.text('Stay sharp'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Big news'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('dismissed_announcements'), ['promo-1']);
    });

    testWidgets('features can be switched off', (tester) async {
      await pumpWithConfig(tester, {
        'features': {'fullscreen': false},
      });
      expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    });

    testWidgets('an unsupported version is blocked', (tester) async {
      await pumpWithConfig(tester, {
        'update': {'minVersion': '99.0.0', 'latestVersion': '99.0.0'},
      });
      expect(find.text('Update required'), findsOneWidget);
    });
  });
}
