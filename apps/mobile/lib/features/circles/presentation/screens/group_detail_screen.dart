import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';
import '../../../../shared/widgets/lc_progress_bar.dart';
import '../../../../shared/widgets/lc_activity_tile.dart';
import '../../../../shared/widgets/lc_leaderboard_card.dart';

/// Group detail dashboard — tactical HQ view.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.memberCount,
    required this.onlineCount,
    required this.myRole,
  });

  final String groupId;
  final String groupName;
  final String groupCode;
  final int memberCount;
  final int onlineCount;
  final String? myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: groupName,
        actions: [
          if (myRole == 'OWNER' || myRole == 'ADMIN')
            IconButton(
              icon: const Icon(PhosphorIconsBold.gear, size: 20),
              onPressed: () {},
              color: AppColors.onSurfaceMedium,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Squad header ────────────────────────────────
              LCMetallicContainer(
                intensity: MetallicIntensity.prominent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.metallic.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              groupName.isNotEmpty ? groupName[0] : '?',
                              style: AppTypography.stat(
                                fontSize: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(groupName,
                                  style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(PhosphorIconsBold.link, size: 12, color: AppColors.onSurfaceDim),
                                  const SizedBox(width: 4),
                                  Text(groupCode,
                                      style: AppTypography.stat(fontSize: 11, color: AppColors.onSurfaceMedium)),
                                  const SizedBox(width: AppSpacing.md),
                                  GestureDetector(
                                    onTap: () {
                                      // Copy to clipboard
                                    },
                                    child: Text('COPY', style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.primary)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        _StatusChip(
                          icon: PhosphorIconsBold.users,
                          value: '$memberCount',
                          label: 'MEMBERS',
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _StatusChip(
                          icon: PhosphorIconsBold.circleWavyCheck,
                          value: '$onlineCount',
                          label: 'ONLINE',
                          valueColor: AppColors.statusOnline,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        if (myRole != null)
                          _StatusChip(
                            icon: PhosphorIconsBold.shield,
                            value: myRole!,
                            label: 'ROLE',
                            valueColor: myRole == 'OWNER'
                                ? const Color(0xFFD4A843)
                                : AppColors.onSurfaceMedium,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Stats row ──────────────────────────────────
              const Row(
                children: [
                  Expanded(
                    child: LCStatContainer(label: 'TOTAL SOLVES', value: '487'),
                  ),
                  SizedBox(width: AppSpacing.itemGap),
                  Expanded(
                    child: LCStatContainer(
                      label: 'AVG STREAK',
                      value: '8.3d',
                      valueColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Members ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MEMBERS', style: AppTypography.tacticalLabel()),
                  Text('$memberCount', style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ..._buildDemoMembers(),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Activity ───────────────────────────────────
              Text('RECENT ACTIVITY', style: AppTypography.tacticalLabel()),
              const SizedBox(height: AppSpacing.md),
              LCCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: const [
                    LCActivityTile(
                      displayName: 'akshay',
                      action: 'solved',
                      detail: 'two-sum',
                      timestamp: '3m',
                      difficulty: 'EASY',
                    ),
                    LCActivityTile(
                      displayName: 'priya',
                      action: 'extended streak to',
                      detail: '9 days',
                      timestamp: '15m',
                    ),
                    LCActivityTile(
                      displayName: 'rahul',
                      action: 'solved',
                      detail: 'valid-parentheses',
                      timestamp: '42m',
                      difficulty: 'EASY',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDemoMembers() {
    final members = [
      ('akshay', 'ONLINE', 'OWNER', 2680),
      ('priya', 'SOLVING', 'ADMIN', 2180),
      ('mitali', 'ONLINE', 'MEMBER', 2050),
      ('rahul', 'OFFLINE', 'MEMBER', 1890),
    ];

    return members.map((m) {
      final (name, status, role, xp) = m;
      return _MemberTile(name: name, status: status, role: role, xp: xp);
    }).toList();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.onSurfaceDim),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.stat(
                fontSize: 14,
                color: valueColor ?? AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.tacticalLabel(fontSize: 8)),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.status,
    required this.role,
    required this.xp,
  });

  final String name;
  final String status;
  final String role;
  final int xp;

  UserStatusType get _statusType {
    switch (status) {
      case 'ONLINE': return UserStatusType.online;
      case 'SOLVING': return UserStatusType.solving;
      case 'IDLE': return UserStatusType.idle;
      default: return UserStatusType.offline;
    }
  }

  Color get _roleColor {
    switch (role) {
      case 'OWNER': return const Color(0xFFD4A843);
      case 'ADMIN': return AppColors.secondary;
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: status != 'OFFLINE' ? AppColors.surfaceVariant : Colors.transparent,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: AppTypography.stat(fontSize: 14, color: AppColors.onSurfaceMedium),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: LCStatusBadge(status: _statusType, size: 8),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(role, style: AppTypography.tacticalLabel(fontSize: 8, color: _roleColor)),
              ],
            ),
          ),
          Text(
            '$xp XP',
            style: AppTypography.stat(fontSize: 12, color: AppColors.onSurfaceMedium),
          ),
        ],
      ),
    );
  }
}
