import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_animations.dart';

/// Leaderboard entry card with rank, metallic accent, and animated transitions.
class LCLeaderboardCard extends StatelessWidget {
  const LCLeaderboardCard({
    super.key,
    required this.rank,
    required this.displayName,
    required this.score,
    required this.solveCount,
    required this.streak,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.rankDelta,
    this.onTap,
  });

  final int rank;
  final String displayName;
  final int score;
  final int solveCount;
  final int streak;
  final String? avatarUrl;
  final bool isCurrentUser;
  final int? rankDelta;
  final VoidCallback? onTap;

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFD4A843);
    if (rank == 2) return AppColors.metallicLight;
    if (rank == 3) return const Color(0xFFB87333);
    return AppColors.onSurfaceDim;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.medium,
      curve: AppAnimations.standard,
      decoration: BoxDecoration(
        gradient: isCurrentUser ? AppColors.cardGradient : null,
        color: isCurrentUser ? null : AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
          width: isCurrentUser ? 0.75 : 0.5,
        ),
        boxShadow: isCurrentUser ? AppShadows.primaryGlow(intensity: 0.1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: AppTypography.rank(color: _rankColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                    border: Border.all(
                      color: rank <= 3
                          ? _rankColor.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: AppTypography.stat(
                        fontSize: 14,
                        color: AppColors.onSurfaceMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name + solve count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isCurrentUser
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$solveCount SOLVED',
                        style: AppTypography.tacticalLabel(
                          fontSize: 9,
                          color: AppColors.onSurfaceDim,
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: AppTypography.stat(
                        fontSize: 16,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rankDelta != null && rankDelta != 0) ...[
                          Icon(
                            rankDelta! > 0
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 14,
                            color: rankDelta! > 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ],
                        Text(
                          '${streak}d',
                          style: AppTypography.tacticalLabel(
                            fontSize: 9,
                            color: streak > 0
                                ? AppColors.primary
                                : AppColors.onSurfaceDim,
                          ),
                        ),
                      ],
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
