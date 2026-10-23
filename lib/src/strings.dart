import 'package:flutter/widgets.dart';

import 'l10n/de.dart';
import 'l10n/en.dart';
import 'l10n/es.dart';
import 'l10n/fr.dart';
import 'l10n/pt.dart';
import 'l10n/tr.dart';

/// UI texts. Each language lives in `l10n/<code>.dart`; English is the
/// fallback for any missing key.
class AppStrings {
  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('es'),
    Locale('de'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// Native names for the language picker.
  static const Map<String, String> languageNames = {
    'tr': 'Türkçe',
    'en': 'English',
    'es': 'Español',
    'de': 'Deutsch',
    'fr': 'Français',
    'pt': 'Português',
  };

  static const Map<String, Map<String, String>> _values = {
    'tr': trStrings,
    'en': enStrings,
    'es': esStrings,
    'de': deStrings,
    'fr': frStrings,
    'pt': ptStrings,
  };

  /// Remote overrides from the live config (language -> key -> text).
  static Map<String, Map<String, String>> overrides = const {};

  @visibleForTesting
  static Map<String, Map<String, String>> get table => _values;

  static String forLanguage(String languageCode, String key) {
    return overrides[languageCode]?[key] ??
        _values[languageCode]?[key] ??
        _values['en']?[key] ??
        key;
  }

  static String of(BuildContext context, String key) {
    return forLanguage(Localizations.localeOf(context).languageCode, key);
  }

  /// "1 sa 25 dk" / "1 h 25 min"
  static String duration(BuildContext context, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hs = of(context, 'hoursShort');
    final ms = of(context, 'minutesShort');
    if (h == 0) return '$m $ms';
    if (m == 0) return '$h $hs';
    return '$h $hs $m $ms';
  }
}

extension AppStringsContext on BuildContext {
  String tr(String key) => AppStrings.of(this, key);
}
