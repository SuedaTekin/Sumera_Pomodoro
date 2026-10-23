import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pomodoro_app/src/app.dart';
import 'package:pomodoro_app/src/controller.dart';
import 'package:pomodoro_app/src/models.dart';
import 'package:pomodoro_app/src/remote_config.dart';
import 'package:pomodoro_app/src/services.dart';
import 'package:pomodoro_app/src/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Supabase.
class FakeBackend implements SyncBackend {
  final tasks = <String, Map<String, dynamic>>{};
  final sessions = <String, Map<String, dynamic>>{};
  bool offline = false;
  int signIns = 0;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<String?> signIn() async {
    _check();
    signIns++;
    return 'user-1';
  }

  @override
  Future<void> upsertTasks(String userId, List<Map<String, dynamic>> rows) async {
    _check();
    for (final r in rows) {
      tasks[r['client_id'] as String] = r;
    }
  }

  @override
  Future<void> deleteTasks(String userId, List<String> clientIds) async {
    _check();
    clientIds.forEach(tasks.remove);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTasks(String userId) async {
    _check();
    return tasks.values.toList();
  }

  @override
  Future<void> upsertSessions(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    _check();
    for (final r in rows) {
      sessions[r['client_id'] as String] = r;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSessions(String userId) async {
    _check();
    return sessions.values.toList();
  }

  @override
  Future<void> deleteSessions(String userId) async {
    _check();
    sessions.clear();
  }

  @override
  Future<void> deleteAccountData(String userId) async {
    _check();
    tasks.clear();
    sessions.clear();
  }
}

SessionRecord session(DateTime at) =>
    SessionRecord(mode: FocusMode.work, completedAt: at, minutes: 25);

Future<void> noPull(List<TaskItem> t, List<SessionRecord> s) async {}

void main() {
  late SharedPreferences prefs;
  late FakeBackend backend;
  late SyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
    sync = SyncService(prefs, backend: backend);
  });

  test('pushes tasks and only new sessions', () async {
    final t = DateTime(2026, 10, 1, 9);
    final tasks = [TaskItem(id: 'a', title: 'Write', estimate: 3)];
    final history = [session(t)];

    await sync.sync(tasks: tasks, history: history, onPulled: noPull);
    expect(backend.tasks['a']!['estimate'], 3);
    expect(backend.sessions, hasLength(1));
    expect(sync.status, SyncStatus.synced);

    // Only the new session is uploaded on the next sync.
    backend.sessions.clear();
    history.add(session(t.add(const Duration(hours: 1))));
    await sync.sync(tasks: tasks, history: history, onPulled: noPull);
    expect(backend.sessions, hasLength(1));
  });

  test('deletions survive being offline and can be undone', () async {
    backend.tasks['a'] = {'client_id': 'a', 'title': 'Old'};
    backend.tasks['b'] = {'client_id': 'b', 'title': 'Undone'};
    sync.markTaskDeleted('a');
    sync.markTaskDeleted('b');
    sync.unmarkTaskDeleted('b');

    backend.offline = true;
    await sync.sync(tasks: const [], history: const [], onPulled: noPull);
    expect(sync.status, SyncStatus.failed);
    expect(backend.tasks.keys, containsAll(['a', 'b']));

    backend.offline = false;
    await sync.sync(tasks: const [], history: const [], onPulled: noPull);
    expect(backend.tasks.keys, ['b']);
  });

  test('first sync pulls rows the device does not have', () async {
    backend.tasks['cloud'] = {
      'client_id': 'cloud',
      'title': 'From cloud',
      'is_done': false,
      'estimate': 2,
    };
    backend.sessions['work-x'] = {
      'client_id': 'work-x',
      'mode': 'work',
      'completed_at': '2026-10-01T07:00:00Z',
      'minutes': 50,
    };

    List<TaskItem>? pulledTasks;
    List<SessionRecord>? pulledSessions;
    await sync.sync(
      tasks: const [],
      history: const [],
      onPulled: (t, s) {
        pulledTasks = t;
        pulledSessions = s;
      },
    );
    expect(pulledTasks!.single.title, 'From cloud');
    expect(pulledTasks!.single.estimate, 2);
    expect(pulledSessions!.single.minutes, 50);

    // Pulling happens once per account.
    pulledTasks = null;
    await sync.sync(
      tasks: const [],
      history: const [],
      onPulled: (t, s) => pulledTasks = t,
    );
    expect(pulledTasks, isNull);
  });

  test('without a backend nothing happens', () async {
    final offlineSync = SyncService(prefs, connector: (_, __) async => null);
    expect(offlineSync.isAvailable, isFalse);
    await offlineSync.sync(tasks: const [], history: const [], onPulled: noPull);
    expect(offlineSync.status, SyncStatus.idle);
  });

  group('app', () {
    Future<PomodoroController> pumpApp(
      WidgetTester tester, {
      Map<String, dynamic>? remoteConfig,
    }) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        if (remoteConfig != null)
          'remote_config_cache': jsonEncode(remoteConfig),
      });
      final storage = await AppStorage.open();
      final controller = PomodoroController(
        storage,
        remote: RemoteConfigService(
          storage.prefs,
          client: MockClient((_) async => http.Response('', 404)),
        ),
        sync: SyncService(
          storage.prefs,
          connector: (url, key) async => backend,
        ),
        forcedLanguage: 'en',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(SumeraApp(controller: controller));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('cloud backup stays hidden until the config names a project',
        (tester) async {
      final controller = await pumpApp(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Back up to cloud'), findsNothing);
      expect(controller.sync!.isAvailable, isFalse);
    });

    testWidgets('task changes reach the cloud and cloud data can be deleted',
        (tester) async {
      final controller = await pumpApp(
        tester,
        remoteConfig: {
          'cloud': {
            'url': 'https://example.supabase.co',
            'publishableKey': 'public-key',
          },
        },
      );
      expect(controller.sync!.isAvailable, isTrue);

      controller.addTask('Synced task');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        backend.tasks.values.map((r) => r['title']),
        contains('Synced task'),
      );

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Back up to cloud'), findsOneWidget);

      await tester.tap(find.text('Delete my cloud data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(backend.tasks, isEmpty);
      expect(controller.settings.cloudSync, isFalse);
      expect(controller.tasks.single.title, 'Synced task');
    });
  });
}
