import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

/// mitaLeet theme builder.
///
/// Assembles the full ThemeData from design tokens.
abstract final class AppTheme {
  static ThemeData get dark {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Colors ──────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        onSurface: AppColors.onSurface,
        onPrimary: AppColors.surface,
        onSecondary: AppColors.surface,
        outline: AppColors.surfaceBorder,
        surfaceContainerHighest: AppColors.surfaceContainerHigh,
      ),

      // ── Typography ─────────────────────────────────────────────────
      textTheme: textTheme.apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),

      // ── AppBar ──────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // ── Bottom Navigation ───────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      // ── Card ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(
            color: AppColors.surfaceBorder,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ─────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.surfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Input ───────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.buttonRadius,
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonRadius,
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonRadius,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceDim,
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 0.5,
        space: 0,
      ),

      // ── Icon ────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.onSurfaceMedium,
        size: 20,
      ),

      // ── Splash ──────────────────────────────────────────────────────
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
