import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Container with subtle metallic accent styling.
///
/// Use for premium containers: leaderboard headers, achievement cards,
/// navigation bars, progress sections.
/// Maintains 90% matte / 10% metallic ratio.
class LCMetallicContainer extends StatelessWidget {
  const LCMetallicContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.intensity = MetallicIntensity.subtle,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final MetallicIntensity intensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Flat panel; "prominent" is one step lighter, not a glossy effect.
        color: intensity == MetallicIntensity.prominent
            ? AppColors.surfaceVariant
            : const Color(0xFF151519),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: child,
    );
  }
}

enum MetallicIntensity { subtle, prominent }
