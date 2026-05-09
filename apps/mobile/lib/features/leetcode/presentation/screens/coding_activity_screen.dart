import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../providers/leetcode_provider.dart';
import '../widgets/lc_streak_card.dart';
import '../widgets/lc_solve_card.dart';
import '../widgets/lc_heatmap.dart';
import '../widgets/lc_diff_breakdown.dart';
import 'leetcode_link_screen.dart';

/// Main coding activity dashboard screen.
class CodingActivityScreen extends ConsumerStatefulWidget {
  const CodingActivityScreen({super.key});

  @override
  ConsumerState<CodingActivityScreen> createState() => _CodingActivityScreenState();
}

class _CodingActivityScreenState extends ConsumerState<CodingActivityScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(leetcodeProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leetcodeProvider);

    if (state.isLoading && !state.linkStatus.isLinked) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const LCAppBar(title: 'Coding'),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: LCShimmer.rect(width: double.infinity, height: 56),
              ),
            ),
          ),
        ),
      );
    }

    if (!state.linkStatus.isLinked) {
      return _NotLinkedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Coding',
        actions: [
          // Sync indicator
          if (state.linkStatus.isSyncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(PhosphorIconsBold.arrowsClockwise, size: 18),
              color: AppColors.onSurfaceMedium,
              onPressed: () => ref.read(leetcodeProvider.notifier).triggerSync(),
            ),
          IconButton(
            icon: const Icon(PhosphorIconsBold.gear, size: 18),
            color: AppColors.onSurfaceMedium,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeetCodeLinkScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () => ref.read(leetcodeProvider.notifier).loadAll(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── Streak card ──────────────────────────────
            LCStreakCard(streak: state.stats.streak),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Today stats row ──────────────────────────
            _TodayRow(
              todayCount: state.stats.todayCount,
              isSolvedToday: state.stats.streak.isSolvedToday,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Difficulty breakdown ─────────────────────
            LCDiffBreakdown(
              total: state.stats.totalSolves,
              easy: state.stats.easySolves,
              medium: state.stats.mediumSolves,
              hard: state.stats.hardSolves,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Activity heatmap ─────────────────────────
            if (state.heatmap.isNotEmpty) ...[
              Text('ACTIVITY', style: AppTypography.tacticalLabel()),
              const SizedBox(height: AppSpacing.md),
              LCHeatmap(data: state.heatmap),
              const SizedBox(height: AppSpacing.sectionGap),
            ],

            // ── Recent solves ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECENT SOLVES', style: AppTypography.tacticalLabel()),
                Text(
                  '${state.recentSolves.length} TOTAL',
                  style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.recentSolves.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'NO SOLVES YET',
                    style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
                  ),
                ),
              )
            else
              ...state.recentSolves.take(15).map(
                    (s) => LCSolveCard(solve: s),
                  ),
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.todayCount, required this.isSolvedToday});
  final int todayCount;
  final bool isSolvedToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: PhosphorIconsBold.checkSquare,
            value: '$todayCount',
            label: 'TODAY',
            accent: isSolvedToday ? AppColors.success : AppColors.onSurfaceDim,
          ),
        ),
        const SizedBox(width: AppSpacing.itemGap),
        Expanded(
          child: _StatChip(
            icon: PhosphorIconsBold.calendar,
            value: isSolvedToday ? 'DONE' : 'PENDING',
            label: 'DAILY GOAL',
            accent: isSolvedToday ? AppColors.success : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTypography.stat(fontSize: 16, color: accent)),
              Text(label, style: AppTypography.tacticalLabel(fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotLinkedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Coding'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Center(
                  child: Icon(PhosphorIconsBold.code, size: 36, color: AppColors.onSurfaceDim),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('NO ACCOUNT LINKED',
                  style: AppTypography.stat(fontSize: 16, color: AppColors.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Link your LeetCode username to start tracking solves, streaks, and activity.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceDim,
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(PhosphorIconsBold.link, size: 16),
                  label: Text(
                    'LINK LEETCODE',
                    style: AppTypography.tacticalLabel(fontSize: 11, color: AppColors.onSurface),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeetCodeLinkScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
