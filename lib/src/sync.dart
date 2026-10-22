import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Cloud storage used by [SyncService]. Rows use the column names of
/// `supabase/schema.sql`.
abstract class SyncBackend {
  /// Signs in (anonymously if needed) and returns the user id.
  Future<String?> signIn();

  Future<void> upsertTasks(String userId, List<Map<String, dynamic>> rows);
  Future<void> deleteTasks(String userId, List<String> clientIds);
  Future<List<Map<String, dynamic>>> fetchTasks(String userId);

  Future<void> upsertSessions(String userId, List<Map<String, dynamic>> rows);
  Future<List<Map<String, dynamic>>> fetchSessions(String userId);
  Future<void> deleteSessions(String userId);

  /// Removes every row of the user and signs out.
  Future<void> deleteAccountData(String userId);
}

class SupabaseSyncBackend implements SyncBackend {
  /// Connects to the project given in the remote config (or via
  /// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`).
  /// The publishable/anon key is public by design; row level security in
  /// supabase/schema.sql limits every user to their own rows.
  static Future<SyncBackend?> connect(String url, String key) async {
    if (url.isEmpty || key.isEmpty) return null;
    await Supabase.initialize(url: url, publishableKey: key);
    return SupabaseSyncBackend();
  }

  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<String?> signIn() async {
    var user = _db.auth.currentUser;
    if (user == null) {
      final response = await _db.auth.signInAnonymously();
      user = response.user;
    }
    if (user == null) return null;
    await _db.from('profiles').upsert({'id': user.id}, onConflict: 'id');
    return user.id;
  }

  @override
  Future<void> upsertTasks(String userId, List<Map<String, dynamic>> rows) =>
      _db.from('tasks').upsert([
        for (final r in rows) {...r, 'user_id': userId},
      ], onConflict: 'user_id,client_id');

  @override
  Future<void> deleteTasks(String userId, List<String> clientIds) => _db
      .from('tasks')
      .delete()
      .eq('user_id', userId)
      .inFilter('client_id', clientIds);

  @override
  Future<List<Map<String, dynamic>>> fetchTasks(String userId) async =>
      List<Map<String, dynamic>>.from(
        await _db
            .from('tasks')
            .select('client_id, title, is_done, estimate')
            .eq('user_id', userId)
            .order('created_at'),
      );

  @override
  Future<void> upsertSessions(String userId, List<Map<String, dynamic>> rows) =>
      _db.from('focus_sessions').upsert([
        for (final r in rows) {...r, 'user_id': userId},
      ], onConflict: 'user_id,client_id');

  @override
  Future<List<Map<String, dynamic>>> fetchSessions(String userId) async =>
      List<Map<String, dynamic>>.from(
        await _db
            .from('focus_sessions')
            .select('client_id, mode, completed_at, minutes, task_client_id')
            .eq('user_id', userId)
            .order('completed_at'),
      );

  @override
  Future<void> deleteSessions(String userId) =>
      _db.from('focus_sessions').delete().eq('user_id', userId);

  @override
  Future<void> deleteAccountData(String userId) async {
    await _db.from('focus_sessions').delete().eq('user_id', userId);
    await _db.from('tasks').delete().eq('user_id', userId);
    await _db.from('profiles').delete().eq('id', userId);
    await _db.auth.signOut();
  }
}

enum SyncStatus { idle, syncing, synced, failed }

/// Offline-first sync: the app always works on local data; this pushes local
/// changes to the cloud and, once per account, pulls rows the device lacks.
/// Failures are logged and retried on the next trigger.
class SyncService extends ChangeNotifier {
  SyncService(
    this._prefs, {
    SyncBackend? backend,
    Future<SyncBackend?> Function(String url, String key)? connector,
  }) : _backend = backend,
       _connector = connector ?? SupabaseSyncBackend.connect;

  final SharedPreferences _prefs;
  final Future<SyncBackend?> Function(String url, String key) _connector;
  SyncBackend? _backend;
  bool _connecting = false;

  /// Connects once per app run; a changed project needs a restart.
  Future<bool> connect(String url, String key) async {
    if (_backend != null) return true;
    if (_connecting) return false;
    _connecting = true;
    try {
      _backend = await _connector(url, key);
    } catch (error) {
      debugPrint('Cloud connect failed: $error');
    } finally {
      _connecting = false;
    }
    notifyListeners();
    return _backend != null;
  }

  static const _pendingDeletesKey = 'sync_pending_task_deletes';
  static const _watermarkKey = 'sync_sessions_watermark';
  static const _pulledUserKey = 'sync_pulled_user';
  static const _lastSyncKey = 'sync_last';

  SyncStatus status = SyncStatus.idle;
  bool _running = false;
  bool _again = false;

  bool get isAvailable => _backend != null;

  DateTime? get lastSyncedAt {
    final ms = _prefs.getInt(_lastSyncKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  List<String> get _pendingDeletes =>
      _prefs.getStringList(_pendingDeletesKey) ?? const [];

  void markTaskDeleted(String id) => _prefs.setStringList(
    _pendingDeletesKey,
    {..._pendingDeletes, id}.toList(),
  );

  void unmarkTaskDeleted(String id) => _prefs.setStringList(
    _pendingDeletesKey,
    _pendingDeletes.where((d) => d != id).toList(),
  );

  /// Next sync pushes the whole history again (used after a stats reset).
  Future<void> resetSessions() async {
    await _prefs.remove(_watermarkKey);
    final backend = _backend;
    if (backend == null) return;
    try {
      final uid = await backend.signIn();
      if (uid != null) await backend.deleteSessions(uid);
    } catch (error) {
      debugPrint('Cloud session reset failed: $error');
    }
  }

  static Map<String, dynamic> taskRow(TaskItem t) => {
    'client_id': t.id,
    'title': t.title,
    'is_done': t.isDone,
    'estimate': t.estimate,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  static Map<String, dynamic> sessionRow(SessionRecord r) => {
    'client_id': r.syncId,
    'mode': r.mode.name,
    'completed_at': r.completedAt.toUtc().toIso8601String(),
    'date': r.completedAt.toIso8601String().substring(0, 10),
    'minutes': r.minutes,
    'task_client_id': r.taskId,
  };

  /// Pushes [tasks] and new [history] entries; on the first sync of an
  /// account, hands rows missing locally to [onPulled].
  Future<void> sync({
    required List<TaskItem> tasks,
    required List<SessionRecord> history,
    required void Function(List<TaskItem>, List<SessionRecord>) onPulled,
  }) async {
    final backend = _backend;
    if (backend == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    status = SyncStatus.syncing;
    notifyListeners();

    try {
      final uid = await backend.signIn();
      if (uid == null) throw StateError('Anonymous sign-in failed');

      final deletes = _pendingDeletes;
      if (deletes.isNotEmpty) {
        await backend.deleteTasks(uid, deletes);
        await _prefs.setStringList(
          _pendingDeletesKey,
          _pendingDeletes.where((d) => !deletes.contains(d)).toList(),
        );
      }

      if (tasks.isNotEmpty) {
        await backend.upsertTasks(uid, tasks.map(taskRow).toList());
      }

      final watermark = DateTime.tryParse(
        _prefs.getString(_watermarkKey) ?? '',
      );
      final fresh = [
        for (final r in history)
          if (watermark == null || r.completedAt.isAfter(watermark)) r,
      ];
      if (fresh.isNotEmpty) {
        await backend.upsertSessions(uid, fresh.map(sessionRow).toList());
        final newest = fresh
            .map((r) => r.completedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        await _prefs.setString(_watermarkKey, newest.toIso8601String());
      }

      if (_prefs.getString(_pulledUserKey) != uid) {
        await _pull(backend, uid, tasks, history, onPulled);
        await _prefs.setString(_pulledUserKey, uid);
      }

      await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      status = SyncStatus.synced;
    } catch (error) {
      debugPrint('Sync failed: $error');
      status = SyncStatus.failed;
    } finally {
      _running = false;
      notifyListeners();
    }

    if (_again) {
      _again = false;
      await sync(tasks: tasks, history: history, onPulled: onPulled);
    }
  }

  Future<void> _pull(
    SyncBackend backend,
    String uid,
    List<TaskItem> tasks,
    List<SessionRecord> history,
    void Function(List<TaskItem>, List<SessionRecord>) onPulled,
  ) async {
    final localTasks = {for (final t in tasks) t.id};
    final deleted = _pendingDeletes.toSet();
    final newTasks = <TaskItem>[];
    for (final row in await backend.fetchTasks(uid)) {
      final id = row['client_id'] as String?;
      final title = row['title'] as String?;
      if (id == null || title == null) continue;
      if (localTasks.contains(id) || deleted.contains(id)) continue;
      newTasks.add(
        TaskItem(
          id: id,
          title: title,
          isDone: row['is_done'] as bool? ?? false,
          estimate: (row['estimate'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    final localSessions = {for (final r in history) r.syncId};
    final newSessions = <SessionRecord>[];
    for (final row in await backend.fetchSessions(uid)) {
      final id = row['client_id'] as String?;
      final at = DateTime.tryParse(row['completed_at'] as String? ?? '');
      if (id == null || at == null || localSessions.contains(id)) continue;
      newSessions.add(
        SessionRecord(
          mode: FocusMode.values.asNameMap()[row['mode']] ?? FocusMode.work,
          completedAt: at.toLocal(),
          minutes: (row['minutes'] as num?)?.toInt() ?? 0,
          taskId: row['task_client_id'] as String?,
        ),
      );
    }

    if (newTasks.isNotEmpty || newSessions.isNotEmpty) {
      onPulled(newTasks, newSessions);
    }
  }

  /// Deletes the user's cloud copy and signs out. Local data is kept.
  Future<bool> deleteCloudData() async {
    final backend = _backend;
    if (backend == null) return false;
    try {
      final uid = await backend.signIn();
      if (uid == null) return false;
      await backend.deleteAccountData(uid);
      for (final key in [
        _pendingDeletesKey,
        _watermarkKey,
        _pulledUserKey,
        _lastSyncKey,
      ]) {
        await _prefs.remove(key);
      }
      status = SyncStatus.idle;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Cloud delete failed: $error');
      return false;
    }
  }
}
