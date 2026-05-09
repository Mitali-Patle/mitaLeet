import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerHigh,
            AppColors.surfaceVariant,
            if (intensity == MetallicIntensity.prominent)
              AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: intensity == MetallicIntensity.prominent
              ? AppColors.metallic.withValues(alpha: 0.25)
              : AppColors.surfaceBorder,
          width: 0.75,
        ),
        boxShadow: intensity == MetallicIntensity.prominent
            ? AppShadows.metallicEdge
            : null,
      ),
      child: child,
    );
  }
}

enum MetallicIntensity { subtle, prominent }
