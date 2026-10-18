import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';

/// Difficulty breakdown bar with solve counts.
class LCDiffBreakdown extends StatelessWidget {
  const LCDiffBreakdown({
    super.key,
    required this.total,
    required this.easy,
    required this.medium,
    required this.hard,
  });

  final int total;
  final int easy;
  final int medium;
  final int hard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Solved', style: AppTypography.tacticalLabel()),
              Text(
                '$total total',
                style: AppTypography.stat(fontSize: 14, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stacked progress bar
          _StackedBar(total: total, easy: easy, medium: medium, hard: hard),
          const SizedBox(height: AppSpacing.lg),

          // Row of counts
          Row(
            children: [
              _DiffLabel(label: 'Easy', count: easy, color: AppColors.easy),
              const SizedBox(width: AppSpacing.xl),
              _DiffLabel(label: 'Medium', count: medium, color: AppColors.medium),
              const SizedBox(width: AppSpacing.xl),
              _DiffLabel(label: 'Hard', count: hard, color: AppColors.hard),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.total,
    required this.easy,
    required this.medium,
    required this.hard,
  });

  final int total;
  final int easy;
  final int medium;
  final int hard;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Row(
        children: [
          if (easy > 0)
            Flexible(
              flex: easy,
              child: Container(height: 6, color: AppColors.easy),
            ),
          if (medium > 0)
            Flexible(
              flex: medium,
              child: Container(height: 6, color: AppColors.medium),
            ),
          if (hard > 0)
            Flexible(
              flex: hard,
              child: Container(height: 6, color: AppColors.hard),
            ),
        ],
      ),
    );
  }
}

class _DiffLabel extends StatelessWidget {
  const _DiffLabel({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: AppTypography.stat(fontSize: 13, color: AppColors.onSurface)),
            Text(label, style: AppTypography.tacticalLabel(fontSize: 7)),
          ],
        ),
      ],
    );
  }
}
