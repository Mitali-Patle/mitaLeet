import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// mitaLeet typography system.
///
/// Three-tier font stack:
///   - JetBrains Mono: primary (headings, body, labels)
///   - IBM Plex Mono: secondary (stats, data, indicators)
///   - System monospace: fallback
///
/// Terminal-inspired, technical, compact, premium.
abstract final class AppTypography {
  // ── Primary text theme (JetBrains Mono) ────────────────────────────
  static TextTheme get textTheme {
    return GoogleFonts.jetBrainsMonoTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700,
          letterSpacing: -0.5, height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600,
          letterSpacing: -0.25, height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600,
          letterSpacing: 0, height: 1.3,
        ),
        headlineLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          letterSpacing: 0, height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          letterSpacing: 0.15, height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500,
          letterSpacing: 0.15, height: 1.4,
        ),
        titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500,
          letterSpacing: 0.4, height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          letterSpacing: 0.5, height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          letterSpacing: 0.25, height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          letterSpacing: 0.25, height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400,
          letterSpacing: 0.3, height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          letterSpacing: 1.2, height: 1.4,
        ),
        labelMedium: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500,
          letterSpacing: 1.0, height: 1.4,
        ),
        labelSmall: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w500,
          letterSpacing: 1.0, height: 1.4,
        ),
      ),
    );
  }

  // ── Secondary font (IBM Plex Mono) — for stats & data ──────────────
  static TextStyle stat({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.5,
      height: 1.1,
      color: color ?? AppColors.onSurface,
    );
  }

  static TextStyle statLabel({
    double fontSize = 10,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      height: 1.4,
      color: color ?? AppColors.onSurfaceDim,
    );
  }

  static TextStyle timer({
    double fontSize = 28,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      height: 1.0,
      color: color ?? AppColors.onSurface,
    );
  }

  static TextStyle rank({
    double fontSize = 16,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.0,
      color: color ?? AppColors.primary,
    );
  }

  // ── Tactical uppercase label ───────────────────────────────────────
  static TextStyle tacticalLabel({
    double fontSize = 10,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.5,
      height: 1.4,
      color: color ?? AppColors.onSurfaceDim,
    );
  }

  // ── Realtime indicator text ────────────────────────────────────────
  static TextStyle indicator({
    double fontSize = 11,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      height: 1.2,
      color: color ?? AppColors.secondary,
    );
  }
}
