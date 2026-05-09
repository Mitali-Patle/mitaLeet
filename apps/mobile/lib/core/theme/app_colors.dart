import 'package:flutter/material.dart';

/// mitaLeet color palette.
///
/// Cyber-industrial aesthetic: matte black surfaces, graphite containers,
/// metallic accents, burnt orange primary, soft cyan secondary.
abstract final class AppColors {
  // ── Surface hierarchy ──────────────────────────────────────────────
  static const Color surface = Color(0xFF0E0E10);
  static const Color surfaceVariant = Color(0xFF1A1A1F);
  static const Color surfaceContainer = Color(0xFF242429);
  static const Color surfaceContainerHigh = Color(0xFF2E2E34);
  static const Color surfaceBorder = Color(0xFF35353D);

  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFC4642A);
  static const Color primaryLight = Color(0xFFD4834E);
  static const Color primaryDark = Color(0xFF9A4D1E);

  static const Color secondary = Color(0xFF6EC8D4);
  static const Color secondaryLight = Color(0xFF92D8E1);
  static const Color secondaryDark = Color(0xFF4BA8B4);

  // ── Metallic accents ───────────────────────────────────────────────
  static const Color metallic = Color(0xFF8A8A92);
  static const Color metallicLight = Color(0xFFB0B0B8);
  static const Color metallicDark = Color(0xFF5E5E66);

  // ── Text ───────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFFE4E4E8);
  static const Color onSurfaceMedium = Color(0xFFA0A0A8);
  static const Color onSurfaceDim = Color(0xFF6E6E78);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF3BA55D);
  static const Color warning = Color(0xFFE5A523);
  static const Color error = Color(0xFFD4453A);
  static const Color info = Color(0xFF5B8DEF);

  // ── Status indicators ──────────────────────────────────────────────
  static const Color statusOnline = Color(0xFF3BA55D);
  static const Color statusSolving = Color(0xFFC4642A);
  static const Color statusIdle = Color(0xFFE5A523);
  static const Color statusOffline = Color(0xFF6E6E78);

  // ── Difficulty ─────────────────────────────────────────────────────
  static const Color easy = Color(0xFF3BA55D);
  static const Color medium = Color(0xFFE5A523);
  static const Color hard = Color(0xFFD4453A);

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient metallicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2E2E34),
      Color(0xFF1A1A1F),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC4642A),
      Color(0xFF9A4D1E),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF242429),
      Color(0xFF1A1A1F),
    ],
  );
}
