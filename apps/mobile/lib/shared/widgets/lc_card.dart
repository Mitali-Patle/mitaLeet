import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Metallic-accented card with optional gradient border.
///
/// Core card component for leaderboard entries, stats,
/// streak indicators, and challenge cards.
class LCCard extends StatelessWidget {
  const LCCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.metallicAccent = false,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool metallicAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.cardGradient,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: borderColor ?? AppColors.surfaceBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          hoverColor: Colors.white.withValues(alpha: 0.03),
          splashColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: padding ??
                const EdgeInsets.all(AppSpacing.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
