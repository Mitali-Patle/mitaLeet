import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// Compact stat container for dashboards.
///
/// Displays a label/value pair in a machined container.
class LCStatContainer extends StatelessWidget {
  const LCStatContainer({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.stat(
              fontSize: 18,
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTypography.tacticalLabel(fontSize: 9),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.onSurfaceDim),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label.toUpperCase(),
                style: AppTypography.tacticalLabel(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.stat(
              fontSize: 24,
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
