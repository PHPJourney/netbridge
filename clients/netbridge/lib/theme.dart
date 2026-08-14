import 'package:flutter/material.dart';

/// Brand palette from design: deep teal `#0F1C24` + accent `#2EC4B6`.
class NbColors {
  static const deepTeal = Color(0xFF0F1C24);
  static const accent = Color(0xFF2EC4B6);
  static const surface = Color(0xFF16262F);
  static const surfaceAlt = Color(0xFF1C303B);
  static const warmText = Color(0xFFE8EEEF);
  static const mutedText = Color(0xFF9BB0B8);
  static const danger = Color(0xFFE07A5F);
  static const ok = Color(0xFF3DDC97);
  static const warn = Color(0xFFE9C46A);
}

ThemeData buildNbTheme() {
  const seed = NbColors.accent;
  final base = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    surface: NbColors.deepTeal,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base.copyWith(
      primary: NbColors.accent,
      onPrimary: NbColors.deepTeal,
      surface: NbColors.deepTeal,
      onSurface: NbColors.warmText,
      secondary: NbColors.accent,
      error: NbColors.danger,
    ),
    scaffoldBackgroundColor: NbColors.deepTeal,
    // System fonts for VPN tool readability (design guidance).
    fontFamily: null,
    appBarTheme: const AppBarTheme(
      backgroundColor: NbColors.deepTeal,
      foregroundColor: NbColors.warmText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: NbColors.warmText,
        letterSpacing: 0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NbColors.accent,
        foregroundColor: NbColors.deepTeal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NbColors.warmText,
        side: const BorderSide(color: NbColors.mutedText),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NbColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NbColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: NbColors.mutedText),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NbColors.surfaceAlt,
      contentTextStyle: TextStyle(color: NbColors.warmText),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NbColors.surface,
      titleTextStyle: const TextStyle(
        color: NbColors.warmText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: NbColors.mutedText, fontSize: 14),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: NbColors.warmText,
      iconColor: NbColors.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return NbColors.deepTeal;
        return NbColors.mutedText;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return NbColors.accent;
        return NbColors.surfaceAlt;
      }),
    ),
  );
}
