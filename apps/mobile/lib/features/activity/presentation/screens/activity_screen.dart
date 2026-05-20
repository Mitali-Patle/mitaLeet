import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../providers/activity_feed_provider.dart';

/// Realtime activity feed screen.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(activityFeedProvider.notifier).loadFeed());
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(activityFeedProvider);
    final filtered = feed.filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Activity'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter row ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'ALL',
                  isSelected: feed.activeFilter == 'ALL',
                  onTap: () => ref.read(activityFeedProvider.notifier).setFilter('ALL'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'SOLVES',
                  isSelected: feed.activeFilter == 'SOLVES',
                  onTap: () => ref.read(activityFeedProvider.notifier).setFilter('SOLVES'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'STREAKS',
                  isSelected: feed.activeFilter == 'STREAKS',
                  onTap: () => ref.read(activityFeedProvider.notifier).setFilter('STREAKS'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'CHALLENGES',
                  isSelected: feed.activeFilter == 'CHALLENGES',
                  onTap: () =>
                      ref.read(activityFeedProvider.notifier).setFilter('CHALLENGES'),
                ),
                const Spacer(),
                // Live indicator
                Row(
                  children: [
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
              ],
            ),
          ),

          // ── Activity feed ─────────────────────────────────
          Expanded(
            child: feed.isLoading && filtered.isEmpty
                ? const LCShimmer(itemCount: 10)
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'NO ACTIVITY YET',
                          style: AppTypography.tacticalLabel(
                            color: AppColors.onSurfaceDim,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant,
                        onRefresh: () =>
                            ref.read(activityFeedProvider.notifier).loadFeed(),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            return _ActivityTile(item: item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final ActivityItem item;

  Color get _diffColor {
    switch (item.difficulty?.toUpperCase()) {
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
        horizontal: AppSpacing.screenPadding,
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainer,
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: Center(
              child: Text(
                item.displayName.isNotEmpty
                    ? item.displayName[0].toUpperCase()
                    : '?',
                style: AppTypography.stat(
                    fontSize: 13, color: AppColors.onSurfaceMedium),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTypography.tacticalLabel(fontSize: 9),
                    children: [
                      TextSpan(
                        text: item.displayName.toUpperCase(),
                        style: const TextStyle(color: AppColors.onSurface),
                      ),
                      TextSpan(
                        text: ' ${item.action} ',
                        style: const TextStyle(color: AppColors.onSurfaceDim),
                      ),
                      TextSpan(
                        text: item.detail,
                        style: TextStyle(
                          color: item.difficulty != null
                              ? _diffColor
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.timeAgo,
                  style: AppTypography.tacticalLabel(
                    fontSize: 8,
                    color: AppColors.onSurfaceDim,
                  ),
                ),
              ],
            ),
          ),
          if (item.difficulty != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _diffColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                item.difficulty!.toUpperCase(),
                style: AppTypography.tacticalLabel(
                    fontSize: 7, color: _diffColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.surfaceBorder,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.tacticalLabel(
            fontSize: 8,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceDim,
          ),
        ),
      ),
    );
  }
}
