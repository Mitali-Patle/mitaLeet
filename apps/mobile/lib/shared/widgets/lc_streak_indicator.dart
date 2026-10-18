import 'package:flutter/material.dart';
import '../../core/theme/phosphor_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_animations.dart';

/// Streak indicator with pulsing flame and animated count.
class LCStreakIndicator extends StatefulWidget {
  const LCStreakIndicator({
    super.key,
    required this.currentStreak,
    this.longestStreak,
    this.compact = false,
  });

  final int currentStreak;
  final int? longestStreak;
  final bool compact;

  @override
  State<LCStreakIndicator> createState() => _LCStreakIndicatorState();
}

class _LCStreakIndicatorState extends State<LCStreakIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimations.pulse,
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.currentStreak > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentStreak > 0;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Icon(
                PhosphorIconsFill.flame,
                size: 14,
                color: isActive
                    ? AppColors.primary
                    : AppColors.onSurfaceDim,
                shadows: isActive
                    ? [
                        Shadow(
                          color: AppColors.primary
                              .withValues(alpha: _glowAnimation.value),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.currentStreak}',
            style: AppTypography.stat(
              fontSize: 14,
              color: isActive ? AppColors.primary : AppColors.onSurfaceDim,
            ),
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
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Icon(
                    PhosphorIconsFill.flame,
                    size: 20,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceDim,
                    shadows: isActive
                        ? [
                            Shadow(
                              color: AppColors.primary
                                  .withValues(alpha: _glowAnimation.value),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Streak',
                style: AppTypography.tacticalLabel(
                  color: AppColors.onSurfaceDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${widget.currentStreak}',
            style: AppTypography.stat(
              fontSize: 32,
              color: isActive ? AppColors.primary : AppColors.onSurfaceDim,
            ),
          ),
          Text(
            'Days',
            style: AppTypography.tacticalLabel(fontSize: 9),
          ),
          if (widget.longestStreak != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'BEST: ${widget.longestStreak}d',
              style: AppTypography.tacticalLabel(
                fontSize: 9,
                color: AppColors.onSurfaceDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
