import 'package:flutter/material.dart';
import 'app_colors.dart';

/// mitaLeet shadow and glow system.
///
/// Subtle, restrained shadows for depth. Glow effects
/// for realtime indicators and active states.
abstract final class AppShadows {
  // ── Elevation shadows ──────────────────────────────────────────────
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // ── Glow effects ───────────────────────────────────────────────────
  static List<BoxShadow> primaryGlow({double intensity = 0.3}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: intensity),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> secondaryGlow({double intensity = 0.3}) => [
        BoxShadow(
          color: AppColors.secondary.withValues(alpha: intensity),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> successGlow({double intensity = 0.3}) => [
        BoxShadow(
          color: AppColors.success.withValues(alpha: intensity),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> statusGlow(Color color, {double intensity = 0.4}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  // ── Metallic edge highlight ────────────────────────────────────────
  static const List<BoxShadow> metallicEdge = [
    BoxShadow(
      color: Color(0x0DFFFFFF),
      blurRadius: 1,
      offset: Offset(0, -0.5),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  // ── Inner shadow for inset containers ──────────────────────────────
  static const List<BoxShadow> inset = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      blurStyle: BlurStyle.inner,
    ),
  ];
}
