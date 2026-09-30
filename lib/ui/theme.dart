import 'package:flutter/material.dart';

abstract final class ArcColors {
  static const background = Color(0xFF080C12);
  static const surface = Color(0xFF111923);
  static const raised = Color(0xFF1B2632);
  static const line = Color(0xFF2B3947);
  static const text = Color(0xFFF6F8F7);
  static const muted = Color(0xFFAAB8C4);
  static const accent = Color(0xFFD5FB57);
  static const blue = Color(0xFF78A2FF);
  static const danger = Color(0xFFE56D6D);
}

ThemeData arcTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: ArcColors.accent,
      brightness: Brightness.dark,
      surface: ArcColors.surface);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme.copyWith(
        primary: ArcColors.accent,
        onPrimary: ArcColors.background,
        surface: ArcColors.surface,
        error: ArcColors.danger),
    scaffoldBackgroundColor: ArcColors.background,
    dividerColor: ArcColors.line,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .2),
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: ArcColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0),
    cardTheme: const CardThemeData(
        color: ArcColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: ArcColors.line))),
    inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: ArcColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: ArcColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: ArcColors.line)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: ArcColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13))),
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ArcColors.surface,
        indicatorColor: ArcColors.raised,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    dialogTheme: const DialogThemeData(
        backgroundColor: ArcColors.raised,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)))),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: ArcColors.raised, behavior: SnackBarBehavior.floating),
  );
}
