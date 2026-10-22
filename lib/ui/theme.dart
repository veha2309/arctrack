import 'package:flutter/material.dart';
import 'package:liquid_ui_components/liquid_ui_components.dart';

// Translucent tint and painted rims retain the glass appearance without
// sampling the moving screen behind every panel during scrolling.
const arcGlassSettings = LiquidGlassSettings(
  rendering: LiquidGlassRendering.frosted,
  tintColor: Color(0xFF294452),
  foregroundColor: ArcColors.text,
  opacity: .22,
  blur: 0,
  borderWidth: .7,
  shadowBlur: 0,
  shadowOpacity: 0,
  dynamicsIntensity: 0,
  animationDuration: Duration.zero,
);

// Small controls keep the glass styling without another backdrop blur pass.
const arcControlGlassSettings = LiquidGlassSettings(
  rendering: LiquidGlassRendering.frosted,
  tintColor: ArcColors.raised,
  foregroundColor: ArcColors.text,
  opacity: .7,
  blur: 0,
  borderWidth: .7,
  shadowBlur: 0,
  shadowOpacity: 0,
  dynamicsIntensity: .35,
);

const arcBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF24465B), Color(0xFF111C30), Color(0xFF283726)],
    stops: [0, .55, 1],
  ),
);

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
    surface: ArcColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme.copyWith(
      primary: ArcColors.accent,
      onPrimary: ArcColors.background,
      surface: ArcColors.surface,
      error: ArcColors.danger,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    dividerColor: ArcColors.line,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: ArcColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: ArcColors.line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: ArcColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ArcColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ArcColors.line),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: ArcColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ArcColors.surface,
      indicatorColor: ArcColors.raised,
      height: 72,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ArcColors.surface,
      selectedColor: ArcColors.accent.withValues(alpha: .16),
      side: const BorderSide(color: ArcColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ArcColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ArcColors.accent,
      linearTrackColor: ArcColors.raised,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: ArcColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ArcColors.raised,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
