import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_streak_indicator.dart';
import '../../../../shared/widgets/lc_challenge_card.dart';
import '../../../../shared/widgets/lc_activity_tile.dart';
import '../../../../shared/widgets/lc_progress_bar.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';

/// Home dashboard — tactical overview of user state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'mitaLeet'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status bar ──────────────────────────────────
            Row(
              children: [
                const LCStatusBadge(status: UserStatusType.online),
                const Spacer(),
                Text(
                  'DEV-001',
                  style: AppTypography.tacticalLabel(
                    fontSize: 9,
                    color: AppColors.onSurfaceDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Stats row ───────────────────────────────────
            Row(
              children: const [
                Expanded(
                  child: LCStatContainer(
                    label: 'SOLVED',
                    value: '147',
                    icon: PhosphorIconsBold.checkCircle,
                    valueColor: AppColors.success,
                  ),
                ),
                SizedBox(width: AppSpacing.itemGap),
                Expanded(
                  child: LCStatContainer(
                    label: 'XP',
                    value: '2,450',
                    icon: PhosphorIconsBold.lightning,
                    valueColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.itemGap),

            Row(
              children: const [
                Expanded(
                  child: LCStatContainer(
                    label: 'RANK',
                    value: '#3',
                    icon: PhosphorIconsBold.trophy,
                    valueColor: Color(0xFFB87333),
                  ),
                ),
                SizedBox(width: AppSpacing.itemGap),
                Expanded(
                  child: LCStreakIndicator(currentStreak: 12, longestStreak: 23),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Daily progress ──────────────────────────────
            LCMetallicContainer(
              intensity: MetallicIntensity.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY GOAL',
                    style: AppTypography.tacticalLabel(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const LCProgressBar(
                    progress: 0.6,
                    height: 6,
                    showGlow: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3 / 5 PROBLEMS',
                        style: AppTypography.tacticalLabel(
                          fontSize: 9,
                          color: AppColors.onSurfaceMedium,
                        ),
                      ),
                      Text(
                        '60%',
                        style: AppTypography.stat(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Active challenge ────────────────────────────
            Text(
              'ACTIVE CHALLENGE',
              style: AppTypography.tacticalLabel(),
            ),
            const SizedBox(height: AppSpacing.md),
            const LCChallengeCard(
              title: 'Binary Search Sprint',
              problemSlug: 'search-in-rotated-sorted-array',
              timeRemaining: '02:34:12',
              difficulty: 'MEDIUM',
              participantCount: 8,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Recent activity ─────────────────────────────
            Text(
              'RECENT ACTIVITY',
              style: AppTypography.tacticalLabel(),
            ),
            const SizedBox(height: AppSpacing.md),
            LCCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: const [
                  LCActivityTile(
                    displayName: 'akshay',
                    action: 'solved',
                    detail: 'two-sum',
                    timestamp: '2m',
                    difficulty: 'EASY',
                  ),
                  LCActivityTile(
                    displayName: 'priya',
                    action: 'solved',
                    detail: 'merge-k-sorted-lists',
                    timestamp: '5m',
                    difficulty: 'HARD',
                  ),
                  LCActivityTile(
                    displayName: 'rahul',
                    action: 'started streak',
                    detail: 'Day 1',
                    timestamp: '12m',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
