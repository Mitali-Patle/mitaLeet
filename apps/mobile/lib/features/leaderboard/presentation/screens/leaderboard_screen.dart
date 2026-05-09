import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_leaderboard_card.dart';
import '../../../../shared/widgets/lc_rank_display.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';

/// Leaderboard screen with top 3 podium and scrollable list.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Leaderboard'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),

            // ── Top 3 podium ────────────────────────────────
            LCMetallicContainer(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              intensity: MetallicIntensity.prominent,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd place
                  Column(
                    children: [
                      const LCRankDisplay(rank: 2, size: 44),
                      const SizedBox(height: 8),
                      Text('priya', style: Theme.of(context).textTheme.titleSmall),
                      Text('2,180', style: AppTypography.stat(fontSize: 14)),
                    ],
                  ),
                  // 1st place (elevated)
                  Column(
                    children: [
                      const LCRankDisplay(rank: 1, size: 56),
                      const SizedBox(height: 8),
                      Text('akshay', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFD4A843),
                      )),
                      Text('2,680', style: AppTypography.stat(fontSize: 16, color: const Color(0xFFD4A843))),
                    ],
                  ),
                  // 3rd place
                  Column(
                    children: [
                      const LCRankDisplay(rank: 3, size: 44),
                      const SizedBox(height: 8),
                      Text('mitali', style: Theme.of(context).textTheme.titleSmall),
                      Text('2,050', style: AppTypography.stat(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Period selector ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                children: [
                  _PeriodChip(label: 'WEEKLY', isSelected: true),
                  const SizedBox(width: AppSpacing.sm),
                  _PeriodChip(label: 'MONTHLY', isSelected: false),
                  const SizedBox(width: AppSpacing.sm),
                  _PeriodChip(label: 'ALL TIME', isSelected: false),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Full leaderboard ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                children: List.generate(8, (i) {
                  final rank = i + 1;
                  final names = ['akshay', 'priya', 'mitali', 'rahul', 'sneha', 'arjun', 'neha', 'vikram'];
                  final scores = [2680, 2180, 2050, 1890, 1720, 1650, 1480, 1320];
                  final solves = [147, 132, 128, 115, 104, 98, 87, 72];
                  final streaks = [12, 8, 15, 3, 7, 0, 5, 2];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: LCLeaderboardCard(
                      rank: rank,
                      displayName: names[i],
                      score: scores[i],
                      solveCount: solves[i],
                      streak: streaks[i],
                      isCurrentUser: rank == 3,
                      rankDelta: rank <= 3 ? (rank == 1 ? 2 : -1) : null,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.isSelected});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.tacticalLabel(
          fontSize: 9,
          color: isSelected ? AppColors.primary : AppColors.onSurfaceDim,
        ),
      ),
    );
  }
}
