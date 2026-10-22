import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand.dart';

/// Where the live config is published. Edit `remote/config.json` in the
/// GitHub repository and every installed app picks it up within minutes.
/// Override at build time with `--dart-define=REMOTE_CONFIG_URL=...`.
const kRemoteConfigUrl = String.fromEnvironment(
  'REMOTE_CONFIG_URL',
  defaultValue:
      'https://raw.githubusercontent.com/SuedaTekin/pomodoro/main/remote/config.json',
);

const kStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sumera.pomodoro';
const kPrivacyPolicyUrl =
    'https://github.com/SuedaTekin/pomodoro/blob/main/store/privacy-policy.md';

/// A text with one value per language code.
class LocalizedText {
  const LocalizedText(this.values);

  final Map<String, String> values;

  static LocalizedText? parse(Object? json) {
    if (json is String) return LocalizedText({'en': json});
    if (json is! Map) return null;
    final values = {
      for (final e in json.entries)
        if (e.value is String && (e.value as String).trim().isNotEmpty)
          e.key.toString(): e.value as String,
    };
    return values.isEmpty ? null : LocalizedText(values);
  }

  String resolve(String languageCode) =>
      values[languageCode] ?? values['en'] ?? values.values.first;
}

class Announcement {
  const Announcement({
    required this.id,
    required this.message,
    this.title,
    this.buttonText,
    this.url,
    this.style = 'info',
    this.dismissible = true,
  });

  final String id;
  final LocalizedText? title;
  final LocalizedText message;
  final LocalizedText? buttonText;
  final String? url;

  /// 'info', 'success' or 'warning'.
  final String style;
  final bool dismissible;

  static Announcement? parse(Object? json) {
    if (json is! Map || json['enabled'] != true) return null;
    final message = LocalizedText.parse(json['message']);
    final id = json['id'];
    if (message == null || id is! String) return null;
    return Announcement(
      id: id,
      title: LocalizedText.parse(json['title']),
      message: message,
      buttonText: LocalizedText.parse(json['buttonText']),
      url: safeUrl(json['url']),
      style: json['style'] is String ? json['style'] as String : 'info',
      dismissible: json['dismissible'] != false,
    );
  }
}

/// Everything that can be changed remotely, with safe defaults for any
/// missing or malformed field.
class RemoteConfig {
  const RemoteConfig({
    this.announcement,
    this.latestVersion,
    this.minVersion,
    this.updateMessage,
    this.quotes = const {},
    this.defaults = const {},
    this.features = const {},
    this.strings = const {},
    this.storeUrl = kStoreUrl,
    this.privacyPolicyUrl = kPrivacyPolicyUrl,
    this.feedbackEmail,
    this.cloudUrl,
    this.cloudKey,
  });

  static const empty = RemoteConfig();

  final Announcement? announcement;
  final String? latestVersion;

  /// Versions below this are blocked until the user updates.
  final String? minVersion;
  final LocalizedText? updateMessage;
  final Map<String, List<String>> quotes;

  /// Fallback values for settings the user has never changed.
  final Map<String, int> defaults;
  final Map<String, bool> features;

  /// Overrides for any UI text, by language and key (see strings.dart).
  final Map<String, Map<String, String>> strings;
  final String storeUrl;
  final String privacyPolicyUrl;
  final String? feedbackEmail;

  /// Supabase project for cloud backup; backup is hidden while unset.
  final String? cloudUrl;
  final String? cloudKey;

  bool feature(String name) => features[name] ?? true;

  bool get updateRequired =>
      minVersion != null && compareVersions(kAppVersion, minVersion!) < 0;

  bool get updateAvailable =>
      latestVersion != null && compareVersions(kAppVersion, latestVersion!) < 0;

  /// One quote per day, rotating through the list.
  String? quoteOfTheDay(String languageCode, DateTime now) {
    final list = quotes[languageCode] ?? quotes['en'];
    if (list == null || list.isEmpty) return null;
    final dayIndex =
        DateTime(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime(2024)).inDays;
    return list[dayIndex % list.length];
  }

  static RemoteConfig parse(Map<String, dynamic> json) {
    final update = json['update'];
    final links = json['links'];
    final cloud = json['cloud'];
    final cloudUrl = cloud is Map ? safeUrl(cloud['url']) : null;
    final cloudKey =
        cloud is Map && cloud['publishableKey'] is String
            ? (cloud['publishableKey'] as String).trim()
            : '';

    Map<String, List<String>> quotes = {};
    if (json['quotes'] case final Map q) {
      quotes = {
        for (final e in q.entries)
          if (e.value is List)
            e.key.toString(): [
              for (final s in e.value as List)
                if (s is String && s.trim().isNotEmpty) s,
            ],
      };
    }

    Map<String, Map<String, String>> strings = {};
    if (json['strings'] case final Map s) {
      strings = {
        for (final e in s.entries)
          if (e.value is Map)
            e.key.toString(): {
              for (final kv in (e.value as Map).entries)
                if (kv.value is String) kv.key.toString(): kv.value as String,
            },
      };
    }

    return RemoteConfig(
      cloudUrl:
          cloudUrl != null &&
                  cloudUrl.startsWith('https://') &&
                  cloudKey.isNotEmpty
              ? cloudUrl
              : null,
      cloudKey: cloudKey.isEmpty ? null : cloudKey,
      announcement: Announcement.parse(json['announcement']),
      latestVersion: update is Map ? _version(update['latestVersion']) : null,
      minVersion: update is Map ? _version(update['minVersion']) : null,
      updateMessage:
          update is Map ? LocalizedText.parse(update['message']) : null,
      quotes: quotes,
      defaults: {
        if (json['defaults'] case final Map d)
          for (final e in d.entries)
            if (e.value is int) e.key.toString(): e.value as int,
      },
      features: {
        if (json['features'] case final Map f)
          for (final e in f.entries)
            if (e.value is bool) e.key.toString(): e.value as bool,
      },
      strings: strings,
      storeUrl: (links is Map ? safeUrl(links['store']) : null) ?? kStoreUrl,
      privacyPolicyUrl:
          (links is Map ? safeUrl(links['privacyPolicy']) : null) ??
          kPrivacyPolicyUrl,
      feedbackEmail:
          links is Map &&
                  links['feedbackEmail'] is String &&
                  (links['feedbackEmail'] as String).contains('@')
              ? links['feedbackEmail'] as String
              : null,
    );
  }

  static String? _version(Object? v) =>
      v is String && RegExp(r'^\d+(\.\d+)*$').hasMatch(v) ? v : null;
}

/// Only web links are opened from remote content.
String? safeUrl(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return null;
  }
  return value;
}

/// Compares dotted versions numerically: -1, 0 or 1.
int compareVersions(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

Future<void> openExternal(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Could not open $url: $error');
  }
}

/// Loads the last known config instantly from disk, then refreshes it from
/// the network in the background. A failed or malformed download never
/// replaces a good config.
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService(
    this._prefs, {
    http.Client? client,
    this.url = kRemoteConfigUrl,
  }) : _client = client ?? http.Client() {
    final cached = _prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        config = RemoteConfig.parse(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        // Ignore a corrupt cache; the next fetch replaces it.
      }
    }
  }

  static const _cacheKey = 'remote_config_cache';
  static const _fetchedAtKey = 'remote_config_fetched_at';
  static const _dismissedKey = 'dismissed_announcements';
  static const _minRefreshInterval = Duration(minutes: 30);

  final SharedPreferences _prefs;
  final http.Client _client;
  final String url;

  RemoteConfig config = RemoteConfig.empty;
  bool _fetching = false;

  /// Fetches unless a fetch happened recently (or [force] is set).
  Future<void> refresh({bool force = false}) async {
    if (_fetching || url.isEmpty) return;
    final last = _prefs.getInt(_fetchedAtKey);
    if (!force &&
        last != null &&
        DateTime.now().millisecondsSinceEpoch - last <
            _minRefreshInterval.inMilliseconds) {
      return;
    }

    _fetching = true;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final body = utf8.decode(response.bodyBytes);
      final parsed = RemoteConfig.parse(
        jsonDecode(body) as Map<String, dynamic>,
      );
      config = parsed;
      await _prefs.setString(_cacheKey, body);
      await _prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      notifyListeners();
    } catch (error) {
      debugPrint('Remote config fetch failed: $error');
    } finally {
      _fetching = false;
    }
  }

  bool isDismissed(String id) =>
      (_prefs.getStringList(_dismissedKey) ?? const []).contains(id);

  Announcement? get visibleAnnouncement {
    final a = config.announcement;
    return a == null || isDismissed(a.id) ? null : a;
  }

  /// Id used to remember that the "update available" card was closed.
  String get updateNoticeId => 'update-${config.latestVersion}';

  bool get showUpdateNotice =>
      config.updateAvailable && !isDismissed(updateNoticeId);

  Future<void> dismissAnnouncement(String id) async {
    final dismissed = _prefs.getStringList(_dismissedKey) ?? [];
    await _prefs.setStringList(_dismissedKey, [...dismissed, id]);
    notifyListeners();
  }
}
