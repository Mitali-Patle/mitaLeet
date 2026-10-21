import 'package:flutter/material.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../providers/leetcode_provider.dart';

/// Animated streak display card.
class LCStreakCard extends StatefulWidget {
  const LCStreakCard({super.key, required this.streak});
  final StreakData streak;

  @override
  State<LCStreakCard> createState() => _LCStreakCardState();
}

class _LCStreakCardState extends State<LCStreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: AppAnimations.pulse,
    );
    if (widget.streak.isSolvedToday) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.streak;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: s.currentStreak > 0
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.surfaceBorder,
          width: s.currentStreak > 0 ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Flame icon with pulse
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final glow = s.isSolvedToday
                  ? _pulseCtrl.value * 0.4 + 0.1
                  : 0.0;
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1 + glow * 0.1),
                  boxShadow: s.isSolvedToday
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: glow), blurRadius: 16)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    s.currentStreak > 0 ? '${s.currentStreak}' : '0',
                    style: AppTypography.stat(
                      fontSize: s.currentStreak >= 100 ? 18 : 24,
                      color: s.currentStreak > 0
                          ? AppColors.primary
                          : AppColors.onSurfaceDim,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xl),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day streak',
                  style: AppTypography.tacticalLabel(
                    color: s.currentStreak > 0
                        ? AppColors.primary
                        : AppColors.onSurfaceDim,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      s.isSolvedToday
                          ? PhosphorIconsBold.checkCircle
                          : PhosphorIconsBold.warning,
                      size: 12,
                      color: s.isSolvedToday
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.isSolvedToday ? 'SOLVED TODAY' : 'Not yet today',
                      style: AppTypography.tacticalLabel(
                        fontSize: 9,
                        color: s.isSolvedToday
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Longest streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${s.longestStreak}',
                style: AppTypography.stat(
                    fontSize: 20, color: AppColors.onSurfaceMedium),
              ),
              Text(
                'Best',
                style: AppTypography.tacticalLabel(
                    fontSize: 8, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
