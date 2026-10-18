import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../providers/gamification_provider.dart';
import '../widgets/lc_rank_badge.dart';
import '../widgets/lc_xp_bar.dart';

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(gamificationProvider.notifier).loadProgression();
      ref.read(gamificationProvider.notifier).loadAchievements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gamificationProvider);
    final p = state.progression;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Progression'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // ── XP card ───────────────────────────────────────
          LCXPBar(progression: p),
          const SizedBox(height: AppSpacing.sectionGap),

          // ── Rank ladder ───────────────────────────────────
          Text('RANK LADDER', style: AppTypography.tacticalLabel()),
          const SizedBox(height: AppSpacing.md),
          _RankLadder(currentRank: p.rank, currentXP: p.xp),
          const SizedBox(height: AppSpacing.sectionGap),

          // ── Achievements ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACHIEVEMENTS', style: AppTypography.tacticalLabel()),
              Text(
                '${state.achievements.length} UNLOCKED',
                style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.achievements.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'SOLVE PROBLEMS TO UNLOCK ACHIEVEMENTS',
                  style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...state.achievements.map((a) => _AchievementTile(achievement: a)),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Rank ladder ─────────────────────────────────────────────────────

class _RankLadder extends StatelessWidget {
  const _RankLadder({required this.currentRank, required this.currentXP});
  final String currentRank;
  final int currentXP;

  static const _thresholds = {
    'INITIATE': 0, 'OPERATOR': 500, 'SPECIALIST': 1500,
    'ELITE': 4000, 'TITAN': 10000, 'APEX': 25000,
  };

  @override
  Widget build(BuildContext context) {
    final ranks = _thresholds.entries.toList();

    return Column(
      children: ranks.map((entry) {
        final isUnlocked = currentXP >= entry.value;
        final isCurrent = currentRank == entry.key;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: isCurrent
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surfaceBorder,
              width: isCurrent ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isUnlocked ? PhosphorIconsBold.checkCircle : PhosphorIconsBold.lock,
                size: 14,
                color: isUnlocked ? AppColors.success : AppColors.onSurfaceDim,
              ),
              const SizedBox(width: AppSpacing.md),
              LCRankBadge(rank: entry.key, size: BadgeSize.medium),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isUnlocked ? AppColors.onSurface : AppColors.onSurfaceDim,
                      ),
                ),
              ),
              Text(
                '${entry.value} XP',
                style: AppTypography.tacticalLabel(
                  fontSize: 9,
                  color: isUnlocked ? AppColors.onSurfaceMedium : AppColors.onSurfaceDim,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Achievement tile ─────────────────────────────────────────────────

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.5),
            ),
            child: const Center(
              child: Icon(PhosphorIconsBold.trophy, size: 16, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceDim,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${achievement.xpReward} XP',
                style: AppTypography.stat(fontSize: 11, color: AppColors.primary),
              ),
              Text(
                _formatDate(achievement.unlockedAt),
                style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
