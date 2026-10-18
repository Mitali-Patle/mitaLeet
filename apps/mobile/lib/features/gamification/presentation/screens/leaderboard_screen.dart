import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../providers/gamification_provider.dart';
import '../widgets/lc_rank_badge.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.groupId});
  final String? groupId;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _period = 'alltime';

  final _tabs = ['SQUAD', 'FRIENDS', 'GLOBAL'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    Future.microtask(() => ref.read(gamificationProvider.notifier).loadAll(groupId: widget.groupId));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gamificationProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Rankings',
        bottom: TabBar(
          controller: _tab,
          labelStyle: AppTypography.tacticalLabel(fontSize: 10),
          unselectedLabelStyle: AppTypography.tacticalLabel(fontSize: 10, color: AppColors.onSurfaceDim),
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.surfaceBorder,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Squad
                _LeaderboardList(
                  entries: state.groupLeaderboard,
                  isLoading: state.isLoading,
                  emptyMessage: 'NO SQUAD MEMBERS YET',
                  onRefresh: () => ref.read(gamificationProvider.notifier)
                      .loadGroupLeaderboard(widget.groupId ?? ''),
                ),
                // Friends
                _LeaderboardList(
                  entries: state.friendsLeaderboard,
                  isLoading: state.isLoading,
                  emptyMessage: 'NO FRIENDS YET',
                  onRefresh: () => ref.read(gamificationProvider.notifier).loadFriendsLeaderboard(),
                ),
                // Global + period filter
                Column(
                  children: [
                    _PeriodFilter(
                      selected: _period,
                      onSelect: (p) {
                        setState(() => _period = p);
                        ref.read(gamificationProvider.notifier).loadGlobalLeaderboard(period: p);
                      },
                    ),
                    Expanded(
                      child: _LeaderboardList(
                        entries: state.globalLeaderboard,
                        isLoading: state.isLoading,
                        emptyMessage: 'NO GLOBAL DATA',
                        onRefresh: () => ref.read(gamificationProvider.notifier)
                            .loadGlobalLeaderboard(period: _period),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final periods = ['daily', 'weekly', 'monthly', 'alltime'];
    final labels = ['TODAY', 'WEEK', 'MONTH', 'ALL'];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: List.generate(periods.length, (i) {
          final isSelected = periods[i] == selected;
          return Padding(
            padding: EdgeInsets.only(right: i < periods.length - 1 ? AppSpacing.md : 0),
            child: GestureDetector(
              onTap: () => onSelect(periods[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.surfaceBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: AppTypography.tacticalLabel(
                    fontSize: 8,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceDim,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.isLoading,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && entries.isEmpty) return const LCShimmer(itemCount: 8);

    if (entries.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim)),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) => _LeaderboardTile(
          entry: entries[i],
          isTop3: i < 3,
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry, this.isTop3 = false});
  final LeaderboardEntry entry;
  final bool isTop3;

  Color get _rankColor {
    switch (entry.rank) {
      case 1: return const Color(0xFFD4A843); // gold
      case 2: return const Color(0xFFB0B0B8); // silver
      case 3: return const Color(0xFFA0714F); // bronze
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isTop3 ? _rankColor.withValues(alpha: 0.04) : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: AppTypography.stat(
                fontSize: 12,
                color: _rankColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainer,
              border: Border.all(
                color: isTop3 ? _rankColor.withValues(alpha: 0.4) : AppColors.surfaceBorder,
                width: isTop3 ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
                style: AppTypography.stat(fontSize: 13, color: AppColors.onSurfaceMedium),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name + rank badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: [
                    LCRankBadge(rank: entry.rankBadge, size: BadgeSize.small),
                    const SizedBox(width: AppSpacing.sm),
                    Text('LVL ${entry.level}',
                        style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim)),
                    if (entry.currentStreak > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('${entry.currentStreak}d',
                          style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.primary)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatXP(entry.xp)} XP',
                style: AppTypography.stat(fontSize: 13, color: AppColors.onSurface),
              ),
              Text(
                '${entry.totalSolves} solved',
                style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatXP(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return '$xp';
  }
}
