import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../providers/gamification_provider.dart';
import 'lc_rank_badge.dart';

/// XP progress bar with level and rank display.
class LCXPBar extends StatefulWidget {
  const LCXPBar({super.key, required this.progression, this.compact = false});

  final Progression progression;
  final bool compact;

  @override
  State<LCXPBar> createState() => _LCXPBarState();
}

class _LCXPBarState extends State<LCXPBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  double _targetProgress = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.slow);
    _progressAnim = Tween<double>(begin: 0, end: widget.progression.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.enter));
    _targetProgress = widget.progression.progress;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(LCXPBar old) {
    super.didUpdateWidget(old);
    if (old.progression.progress != widget.progression.progress) {
      _progressAnim = Tween<double>(
        begin: _targetProgress,
        end: widget.progression.progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.enter));
      _targetProgress = widget.progression.progress;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progression;

    if (widget.compact) {
      return _CompactXPBar(progression: p, progressAnim: _progressAnim);
    }

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
            children: [
              // Level circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${p.level}',
                    style: AppTypography.stat(fontSize: 16, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LCRankBadge(rank: p.rank, size: BadgeSize.medium),
                        const Spacer(),
                        Text(
                          '${p.xp} XP',
                          style: AppTypography.stat(fontSize: 12, color: AppColors.onSurfaceMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (context, _) => _ProgressBar(value: _progressAnim.value),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${p.currentLevelXP} XP',
                          style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim),
                        ),
                        Text(
                          '${p.nextLevelXP} XP to level ${p.level + 1}',
                          style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.nextRank != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Next rank', style: AppTypography.tacticalLabel(fontSize: 8)),
                const Spacer(),
                LCRankBadge(rank: p.nextRank!, size: BadgeSize.small),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactXPBar extends StatelessWidget {
  const _CompactXPBar({required this.progression, required this.progressAnim});
  final Progression progression;
  final Animation<double> progressAnim;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Level ${progression.level}',
            style: AppTypography.stat(fontSize: 12, color: AppColors.primary)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AnimatedBuilder(
            animation: progressAnim,
            builder: (_, __) => _ProgressBar(value: progressAnim.value, height: 3),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        LCRankBadge(rank: progression.rank, size: BadgeSize.small),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, this.height = 5});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: AppColors.surfaceContainer,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: height,
      ),
    );
  }
}
