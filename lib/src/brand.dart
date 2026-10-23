import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';

const kAppName = 'Sumera Pomodoro';
const kAppVersion = '1.1.0';

class Brand {
  static const indigo = Color(0xFF5B4DFF);
  static const violet = Color(0xFF7C5CFF);
  static const deep = Color(0xFF2D1F8C);
  static const cyan = Color(0xFF4CC9F0);

  static const background = Color(0xFF0F1020);
  static const surface = Color(0xFF181A2E);
  static const surfaceHigh = Color(0xFF22253D);
  static const outline = Color(0xFF2E3250);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xB3FFFFFF);
  static const textMuted = Color(0x8AFFFFFF);

  /// Single-series chart color; 5.7:1 contrast on [surface].
  static const chartBar = Color(0xFF8B85FF);
  static const chartBarSelected = cyan;
  static const chartGrid = Color(0x1FFFFFFF);

  static const success = Color(0xFF4ADE80);
}

extension FocusModeStyle on FocusMode {
  List<Color> get gradient => switch (this) {
    FocusMode.work => const [Brand.violet, Brand.deep],
    FocusMode.shortBreak => const [Color(0xFF14B8A6), Color(0xFF0E5E6F)],
    FocusMode.longBreak => const [Color(0xFF3B82F6), Color(0xFF1E2F7A)],
  };

  Color get accent => gradient.first;

  String get labelKey => switch (this) {
    FocusMode.work => 'workMode',
    FocusMode.shortBreak => 'shortBreakMode',
    FocusMode.longBreak => 'longBreakMode',
  };

  String get descriptionKey => switch (this) {
    FocusMode.work => 'focusDescription',
    FocusMode.shortBreak => 'shortBreakDescription',
    FocusMode.longBreak => 'longBreakDescription',
  };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.indigo,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Brand.chartBar,
    secondary: Brand.cyan,
    surface: Brand.surface,
    surfaceContainerHighest: Brand.surfaceHigh,
    outline: Brand.outline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    appBarTheme: AppBarTheme(
      backgroundColor: Brand.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      // Derived from the platform typography so it keeps the system font.
      titleTextStyle: Typography.material2021(
        platform: defaultTargetPlatform,
      ).white.titleLarge!.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Brand.textPrimary,
      ),
    ),
    cardTheme: CardTheme(
      color: Brand.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Brand.outline, width: 0.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Brand.surface,
      indicatorColor: Brand.indigo.withAlpha(90),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.surfaceHigh,
      contentTextStyle: TextStyle(color: Brand.textPrimary),
    ),
    dividerTheme: const DividerThemeData(color: Brand.outline, space: 1),
  );
}
