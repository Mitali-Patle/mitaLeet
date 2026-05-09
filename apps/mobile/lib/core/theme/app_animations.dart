import 'package:flutter/material.dart';

/// mitaLeet animation timing and curve tokens.
///
/// Tactical, fluid, premium motion language.
abstract final class AppAnimations {
  // ── Durations ──────────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration dramatic = Duration(milliseconds: 800);
  static const Duration pulse = Duration(milliseconds: 1500);
  static const Duration breathe = Duration(milliseconds: 2000);

  // ── Curves ─────────────────────────────────────────────────────────
  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve sharp = Curves.easeInOutCubicEmphasized;
  static const Curve bounce = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;

  // ── Page transition ────────────────────────────────────────────────
  static const Duration pageTransition = Duration(milliseconds: 250);
  static const Curve pageTransitionCurve = Curves.easeInOutCubic;
}
