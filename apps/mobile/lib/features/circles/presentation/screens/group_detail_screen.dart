import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';
import '../../../../shared/widgets/lc_activity_tile.dart';
import '../../../../shared/widgets/lc_toast.dart';
import '../../../activity/providers/activity_feed_provider.dart';
import '../../../gamification/providers/gamification_provider.dart';
import '../../providers/groups_provider.dart';

/// Members of one squad ranked by XP, with level, solves and streak.
final squadLeaderboardProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, groupId) async {
  final res = await ref.read(apiClientProvider).get(ApiEndpoints.groupLeaderboard(groupId));
  return (res.data['data'] as List)
      .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Recent activity of the squad's members.
final squadActivityProvider =
    FutureProvider.autoDispose.family<List<ActivityItem>, String>((ref, groupId) async {
  final res = await ref.read(apiClientProvider).get(ApiEndpoints.groupActivity(groupId));
  return (res.data['data'] as List)
      .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

String _roleLabel(String role) => switch (role) {
      'OWNER' => 'Owner',
      'ADMIN' => 'Admin',
      _ => 'Member',
    };

/// Squad page: invite code, totals, members ranked by XP, recent activity.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(squadLeaderboardProvider(group.id));
    final activity = ref.watch(squadActivityProvider(group.id));
    final online = {for (final m in group.members) m.userId: m.isOnline};
    final roles = {for (final m in group.members) m.userId: m.role};

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(title: group.name),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () async {
          ref.invalidate(squadLeaderboardProvider(group.id));
          ref.invalidate(squadActivityProvider(group.id));
          await Future.wait([
            ref.read(squadLeaderboardProvider(group.id).future),
            ref.read(squadActivityProvider(group.id).future),
            ref.read(groupsProvider.notifier).loadGroups(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SquadHeader(group: group),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Totals ──────────────────────────────────────
              board.when(
                data: (entries) {
                  final solves = entries.fold<int>(0, (sum, e) => sum + e.totalSolves);
                  final avgStreak = entries.isEmpty
                      ? 0.0
                      : entries.fold<int>(0, (sum, e) => sum + e.currentStreak) / entries.length;
                  return Row(
                    children: [
                      Expanded(child: LCStatContainer(label: 'Total solves', value: '$solves')),
                      const SizedBox(width: AppSpacing.itemGap),
                      Expanded(
                        child: LCStatContainer(
                          label: 'Average streak',
                          value: '${avgStreak.toStringAsFixed(1)} d',
                          valueColor: AppColors.primary,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 72),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Members ─────────────────────────────────────
              _SectionTitle(title: 'Members', trailing: '${group.memberCount}'),
              const SizedBox(height: AppSpacing.md),
              board.when(
                data: (entries) => Column(
                  children: [
                    for (final e in entries)
                      _MemberTile(
                        rank: e.rank,
                        name: e.displayName,
                        isOnline: online[e.userId] ?? false,
                        role: roles[e.userId] ?? 'MEMBER',
                        xp: e.xp,
                        level: e.level,
                        streak: e.currentStreak,
                      ),
                  ],
                ),
                loading: () => const _Loading(),
                error: (_, __) => const _ErrorText('Could not load members. Pull down to retry.'),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Activity ────────────────────────────────────
              const _SectionTitle(title: 'Recent activity'),
              const SizedBox(height: AppSpacing.md),
              activity.when(
                data: (items) => items.isEmpty
                    ? const _ErrorText('No activity yet. Solves by squad members show up here.')
                    : LCCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final a in items.take(20))
                              LCActivityTile(
                                displayName: a.displayName,
                                action: a.action,
                                detail: a.detail,
                                timestamp: a.timeAgo,
                                difficulty: a.difficulty,
                              ),
                          ],
                        ),
                      ),
                loading: () => const _Loading(),
                error: (_, __) => const _ErrorText('Could not load activity. Pull down to retry.'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquadHeader extends StatelessWidget {
  const _SquadHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LCMetallicContainer(
      intensity: MetallicIntensity.prominent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                    style: AppTypography.stat(fontSize: 18, color: AppColors.primaryLight),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('Invite code ', style: text.bodySmall?.copyWith(color: AppColors.onSurfaceDim)),
                        Text(group.code, style: AppTypography.timer(fontSize: 13, color: AppColors.onSurfaceMedium)),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(PhosphorIconsBold.copy, size: 14),
                label: const Text('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: group.code));
                  if (context.mounted) {
                    LCToastManager.show(
                      context,
                      title: 'Invite code copied',
                      subtitle: 'Friends can join with it from Squads → Join',
                      accentColor: AppColors.primary,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _StatusChip(icon: PhosphorIconsBold.users, value: '${group.memberCount}', label: 'Members'),
              const SizedBox(width: AppSpacing.xl),
              _StatusChip(
                icon: PhosphorIconsBold.checkCircle,
                value: '${group.activeMemberCount}',
                label: 'Online',
                valueColor: AppColors.statusOnline,
              ),
              if (group.myRole != null) ...[
                const SizedBox(width: AppSpacing.xl),
                _StatusChip(icon: PhosphorIconsBold.shield, value: _roleLabel(group.myRole!), label: 'Your role'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: text.titleSmall),
        if (trailing != null) Text(trailing!, style: text.bodySmall?.copyWith(color: AppColors.onSurfaceDim)),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.value, required this.label, this.valueColor});

  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.onSurfaceDim),
            const SizedBox(width: 5),
            Text(value, style: AppTypography.stat(fontSize: 15, color: valueColor ?? AppColors.onSurface)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.statLabel()),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.rank,
    required this.name,
    required this.isOnline,
    required this.role,
    required this.xp,
    required this.level,
    required this.streak,
  });

  final int rank;
  final String name;
  final bool isOnline;
  final String role;
  final int xp;
  final int level;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: AppTypography.rank(fontSize: 13, color: AppColors.onSurfaceDim)),
          ),
          Stack(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.surfaceContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTypography.stat(fontSize: 13, color: AppColors.onSurfaceMedium),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: LCStatusBadge(
                  status: isOnline ? UserStatusType.online : UserStatusType.offline,
                  size: 8,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: text.titleSmall, overflow: TextOverflow.ellipsis)),
                    if (role != 'MEMBER') ...[
                      const SizedBox(width: 6),
                      Text(
                        _roleLabel(role),
                        style: text.labelSmall?.copyWith(
                          color: role == 'OWNER' ? const Color(0xFFD4A843) : AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Level $level · $streak-day streak',
                  style: text.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
                ),
              ],
            ),
          ),
          Text('$xp XP', style: AppTypography.stat(fontSize: 13, color: AppColors.onSurfaceMedium)),
        ],
      ),
    );
  }
}
