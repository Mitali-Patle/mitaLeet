import 'package:flutter/material.dart';

/// mitaLeet border radius tokens.
///
/// Sharp, industrial aesthetic — small radii preferred.
abstract final class AppRadius {
  static const double none = 0;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double full = 999;

  // ── Convenience BorderRadius ───────────────────────────────────────
  static final BorderRadius cardRadius = BorderRadius.circular(xl);
  static final BorderRadius buttonRadius = BorderRadius.circular(lg);
  static final BorderRadius chipRadius = BorderRadius.circular(md);
  static final BorderRadius circularRadius = BorderRadius.circular(full);
}
