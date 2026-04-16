import 'package:flutter/material.dart';

/// Trail is dark-mode only (user preference).
///
/// Accent is a muted teal — deliberately understated to match the app's
/// "neutral / disguised" design brief (PLAN.md). The icon colour in Phase 6
/// will pull from the same seed.
final trailDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4DB6AC),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0E1115),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF161B22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
