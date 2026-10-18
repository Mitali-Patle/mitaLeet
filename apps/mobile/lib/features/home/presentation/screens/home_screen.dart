import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_streak_indicator.dart';
import '../../../../shared/widgets/lc_progress_bar.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../leetcode/providers/leetcode_provider.dart';
import '../../../gamification/providers/gamification_provider.dart';
import '../../../activity/providers/activity_feed_provider.dart';

/// Home dashboard — tactical overview of user state.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leetcodeProvider.notifier).loadAll();
      ref.read(gamificationProvider.notifier).loadAll();
      ref.read(activityFeedProvider.notifier).loadFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final lc = ref.watch(leetcodeProvider);
    final gami = ref.watch(gamificationProvider);
    final feed = ref.watch(activityFeedProvider);

    final stats = lc.stats;
    final progression = gami.progression;
    final displayName = auth.displayName ?? 'OPERATIVE';

    // Daily goal: 5 problems / day
    const dailyGoal = 5;
    final todayCount = stats.todayCount.clamp(0, dailyGoal);
    final dailyProgress = dailyGoal > 0 ? todayCount / dailyGoal : 0.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'mitaLeet',
        actions: [
          // Squads shortcut
          IconButton(
            icon: const Icon(PhosphorIconsBold.usersThree, size: 20),
            onPressed: () => context.push('/squad'),
            color: AppColors.onSurfaceMedium,
            tooltip: 'My Squads',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () async {
          await Future.wait([
            ref.read(leetcodeProvider.notifier).loadAll(),
            ref.read(gamificationProvider.notifier).loadAll(),
            ref.read(activityFeedProvider.notifier).loadFeed(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status bar ──────────────────────────────────
              Row(
                children: [
                  const LCStatusBadge(status: UserStatusType.online),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    displayName.toUpperCase(),
                    style: AppTypography.tacticalLabel(
                      fontSize: 9,
                      color: AppColors.onSurfaceMedium,
                    ),
                  ),
                  const Spacer(),
                  if (lc.isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Stats row ───────────────────────────────────
              if (lc.isLoading && stats.totalSolves == 0)
                const LCShimmer(itemCount: 2)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: LCStatContainer(
                        label: 'SOLVED',
                        value: '${stats.totalSolves}',
                        icon: PhosphorIconsBold.checkCircle,
                        valueColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.itemGap),
                    Expanded(
                      child: LCStatContainer(
                        label: 'XP',
                        value: progression.xp >= 1000
                            ? '${(progression.xp / 1000).toStringAsFixed(1)}k'
                            : '${progression.xp}',
                        icon: PhosphorIconsBold.lightning,
                        valueColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.itemGap),
                Row(
                  children: [
                    Expanded(
                      child: LCStatContainer(
                        label: 'RANK',
                        value: 'LVL ${progression.level}',
                        icon: PhosphorIconsBold.trophy,
                        valueColor: const Color(0xFFB87333),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.itemGap),
                    Expanded(
                      child: LCStreakIndicator(
                        currentStreak: stats.streak.currentStreak,
                        longestStreak: stats.streak.longestStreak,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Daily progress ──────────────────────────────
              LCMetallicContainer(
                intensity: MetallicIntensity.subtle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DAILY GOAL', style: AppTypography.tacticalLabel()),
                    const SizedBox(height: AppSpacing.md),
                    LCProgressBar(
                      progress: dailyProgress,
                      height: 6,
                      showGlow: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$todayCount / $dailyGoal PROBLEMS',
                          style: AppTypography.tacticalLabel(
                            fontSize: 9,
                            color: AppColors.onSurfaceMedium,
                          ),
                        ),
                        Text(
                          '${(dailyProgress * 100).toStringAsFixed(0)}%',
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

              // ── Rank badge ──────────────────────────────────
              LCMetallicContainer(
                intensity: MetallicIntensity.subtle,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        progression.rank,
                        style: AppTypography.tacticalLabel(
                          color: AppColors.primary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LCProgressBar(
                            progress: progression.progress,
                            height: 4,
                            showGlow: false,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progression.nextRank != null
                                ? '${progression.currentLevelXP} / ${progression.nextLevelXP} XP → ${progression.nextRank}'
                                : 'MAX RANK',
                            style: AppTypography.tacticalLabel(
                              fontSize: 8,
                              color: AppColors.onSurfaceDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Recent activity ─────────────────────────────
              Row(
                children: [
                  Text('RECENT ACTIVITY', style: AppTypography.tacticalLabel()),
                  const Spacer(),
                  // Live dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: AppTypography.tacticalLabel(
                      fontSize: 8,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (feed.isLoading && feed.items.isEmpty)
                const LCShimmer(itemCount: 5)
              else if (feed.items.isEmpty)
                LCCard(
                  child: Center(
                    child: Text(
                      'NO ACTIVITY YET — START SOLVING',
                      style: AppTypography.tacticalLabel(
                        color: AppColors.onSurfaceDim,
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
              else
                LCCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: feed.items.take(8).map((item) {
                      return _ActivityRow(
                        displayName: item.displayName,
                        action: item.action,
                        detail: item.detail,
                        timestamp: item.timeAgo,
                        difficulty: item.difficulty,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.displayName,
    required this.action,
    required this.detail,
    required this.timestamp,
    this.difficulty,
  });

  final String displayName;
  final String action;
  final String detail;
  final String timestamp;
  final String? difficulty;

  Color get _diffColor {
    switch (difficulty?.toUpperCase()) {
      case 'EASY':
        return AppColors.easy;
      case 'HARD':
        return AppColors.hard;
      default:
        return AppColors.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainer,
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: AppTypography.stat(fontSize: 11, color: AppColors.onSurfaceMedium),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.tacticalLabel(fontSize: 9),
                children: [
                  TextSpan(
                    text: displayName.toUpperCase(),
                    style: const TextStyle(color: AppColors.onSurface),
                  ),
                  TextSpan(
                    text: ' $action ',
                    style: const TextStyle(color: AppColors.onSurfaceDim),
                  ),
                  TextSpan(
                    text: detail,
                    style: TextStyle(
                      color: difficulty != null ? _diffColor : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (difficulty != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _diffColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                difficulty!.toUpperCase(),
                style: AppTypography.tacticalLabel(fontSize: 7, color: _diffColor),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            timestamp,
            style: AppTypography.tacticalLabel(
              fontSize: 8,
              color: AppColors.onSurfaceDim,
            ),
          ),
        ],
      ),
    );
  }
}
