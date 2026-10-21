import 'package:flutter/material.dart';
import '../../core/theme/phosphor_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// Challenge card with timer and metallic border.
class LCChallengeCard extends StatelessWidget {
  const LCChallengeCard({
    super.key,
    required this.title,
    required this.problemSlug,
    required this.timeRemaining,
    this.difficulty,
    this.participantCount = 0,
    this.isActive = true,
    this.onTap,
  });

  final String title;
  final String problemSlug;
  final String timeRemaining;
  final String? difficulty;
  final int participantCount;
  final bool isActive;
  final VoidCallback? onTap;

  Color get _diffColor {
    switch (difficulty?.toUpperCase()) {
      case 'EASY': return AppColors.easy;
      case 'MEDIUM': return AppColors.medium;
      case 'HARD': return AppColors.hard;
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isActive
              ? AppColors.metallic.withValues(alpha: 0.3)
              : AppColors.surfaceBorder,
          width: 0.75,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIconsBold.sword,
                      size: 14,
                      color: isActive ? AppColors.primary : AppColors.onSurfaceDim,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isActive ? 'ACTIVE CHALLENGE' : 'Challenge',
                      style: AppTypography.tacticalLabel(
                        color: isActive ? AppColors.primary : AppColors.onSurfaceDim,
                      ),
                    ),
                    const Spacer(),
                    if (difficulty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _diffColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.chipRadius,
                        ),
                        child: Text(
                          difficulty!.toUpperCase(),
                          style: AppTypography.tacticalLabel(fontSize: 8, color: _diffColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  problemSlug,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceDim,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(PhosphorIconsBold.timer, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(timeRemaining, style: AppTypography.indicator()),
                    const Spacer(),
                    Icon(PhosphorIconsBold.users, size: 12, color: AppColors.onSurfaceDim),
                    const SizedBox(width: 4),
                    Text(
                      '$participantCount',
                      style: AppTypography.tacticalLabel(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
