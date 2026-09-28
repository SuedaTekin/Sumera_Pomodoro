import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const _defaultSupabaseUrl =
      'https://nglwgpwfummbtybupznq.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5nbHdncHdmdW1tYnR5YnVwem5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1MjM0MTUsImV4cCI6MjEwNjA5OTQxNX0.4G9XlmEPhT0qXPkZLYzRzX_HMUC34MJNqeDQUv3d2yg';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _defaultSupabaseUrl,
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _defaultSupabaseAnonKey,
    );

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static bool get isAvailable =>
      Supabase.instance.client.auth.currentUser != null ||
      Supabase.instance.client.auth.currentSession != null;

  static Future<String?> getCurrentUserId() async {
    await ensureAuthenticated();
    return client.auth.currentUser?.id;
  }

  static Future<void> ensureAuthenticated() async {
    if (!isAvailable) {
      final response = await client.auth.signInAnonymously();
      if (response.user == null) {
        return;
      }
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    if (existing == null) {
      await client.from('profiles').upsert({
        'id': userId,
        'email': null,
        'full_name': 'Anonymous User',
      }, onConflict: 'id');
    }
  }

  static Future<List<Map<String, dynamic>>> getTasks() async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      return const [];
    }

    final response = await client
        .from('tasks')
        .select('id, title, is_done')
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> saveTask(String title, {bool isDone = false}) async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      return null;
    }

    final response = await client
        .from('tasks')
        .insert({
          'user_id': userId,
          'title': title,
          'is_done': isDone,
        })
        .select('id, title, is_done');

    if (response.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(response.first);
  }

  static Future<void> updateTask(String taskId, {required bool isDone}) async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      return;
    }

    await client
        .from('tasks')
        .update({'is_done': isDone})
        .eq('id', taskId)
        .eq('user_id', userId);
  }

  static Future<List<Map<String, dynamic>>> getFocusSessions() async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      return const [];
    }

    final response = await client
        .from('focus_sessions')
        .select('id, date, minutes')
        .eq('user_id', userId)
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> saveFocusSession({
    required String date,
    required int minutes,
  }) async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      return;
    }

    await client.from('focus_sessions').upsert({
      'user_id': userId,
      'date': date,
      'minutes': minutes,
    }, onConflict: 'user_id,date');
  }
}
