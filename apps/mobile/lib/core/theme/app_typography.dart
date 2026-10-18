import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// mitaLeet typography.
///
///   - Inter: all interface text (headings, body, labels, buttons)
///   - Inter with tabular figures: numbers that line up (stats, ranks, XP)
///   - JetBrains Mono: only where code-like text helps (timers, codes)
///
/// Text is sentence case. Don't uppercase labels or add letter spacing for
/// emphasis; use weight and colour instead.
abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.15),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.2),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.25),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.3),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.35),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.35),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.4),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.4),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.5),
        bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.45),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.3),
        labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.3),
        labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.3),
      ),
    );
  }

  // ── Numbers ────────────────────────────────────────────────────────
  static TextStyle stat({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.4,
      height: 1.1,
      fontFeatures: _tabular,
      color: color ?? AppColors.onSurface,
    );
  }

  /// Caption under or beside a number ("Day streak", "Solved").
  static TextStyle statLabel({
    double fontSize = 10,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: _readable(fontSize),
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: color ?? AppColors.onSurfaceDim,
    );
  }

  static TextStyle timer({
    double fontSize = 28,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
      fontFeatures: _tabular,
      color: color ?? AppColors.onSurface,
    );
  }

  static TextStyle rank({
    double fontSize = 16,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.0,
      fontFeatures: _tabular,
      color: color ?? AppColors.primary,
    );
  }

  // ── Labels ─────────────────────────────────────────────────────────
  /// Small secondary label: section headers, captions, button text.
  ///
  /// (Historically an all-caps "tactical" style; callers still pass the
  /// small sizes that suited it, so sizes are scaled to stay readable.)
  static TextStyle tacticalLabel({
    double fontSize = 10,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: _readable(fontSize),
      fontWeight: fontWeight == FontWeight.w700 ? FontWeight.w600 : fontWeight,
      height: 1.35,
      color: color ?? AppColors.onSurfaceDim,
    );
  }

  /// Live/realtime status text ("3 online").
  static TextStyle indicator({
    double fontSize = 11,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: _readable(fontSize),
      fontWeight: FontWeight.w500,
      height: 1.25,
      color: color ?? AppColors.secondary,
    );
  }

  /// Sizes chosen for 9–11 px all-caps monospace read too small in Inter.
  static double _readable(double size) => (size + 2.5).clamp(12.0, 16.0);
}
