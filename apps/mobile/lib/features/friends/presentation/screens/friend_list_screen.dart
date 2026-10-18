import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../../friends/providers/friends_provider.dart';

/// Friend list with realtime presence indicators.
class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(friendsProvider.notifier).loadFriends());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Friends',
        actions: [
          // Pending requests badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(PhosphorIconsBold.bellRinging, size: 20),
                tooltip: 'Friend requests',
                onPressed: () => context.push('/profile/friends/requests'),
                color: AppColors.onSurfaceMedium,
              ),
              if (state.incoming.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${state.incoming.length}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(PhosphorIconsBold.magnifyingGlass, size: 20),
            tooltip: 'Find friends',
            onPressed: () => context.push('/profile/friends/search'),
            color: AppColors.primary,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () async {
          await ref.read(friendsProvider.notifier).loadFriends();
          await ref.read(friendsProvider.notifier).loadIncoming();
        },
        child: state.isLoading && state.friends.isEmpty
            ? const LCShimmer(itemCount: 6)
            : state.friends.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    itemCount: state.friends.length,
                    itemBuilder: (context, index) {
                      final friend = state.friends[index];
                      return _FriendTile(friend: friend);
                    },
                  ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});
  final Friend friend;

  UserStatusType get _statusType {
    switch (friend.status.toUpperCase()) {
      case 'ONLINE': return UserStatusType.online;
      case 'SOLVING': return UserStatusType.solving;
      case 'IDLE': return UserStatusType.idle;
      default: return UserStatusType.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: friend.isOnline
            ? AppColors.surfaceVariant
            : Colors.transparent,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                    border: Border.all(
                      color: friend.isOnline
                          ? AppColors.statusOnline.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '?',
                      style: AppTypography.stat(
                        fontSize: 16,
                        color: friend.isOnline
                            ? AppColors.onSurface
                            : AppColors.onSurfaceDim,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: LCStatusBadge(status: _statusType, size: 10),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // Name + username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: friend.isOnline
                              ? AppColors.onSurface
                              : AppColors.onSurfaceMedium,
                        ),
                  ),
                  if (friend.username != null)
                    Text(
                      '@${friend.username}',
                      style: AppTypography.tacticalLabel(
                        fontSize: 9,
                        color: AppColors.onSurfaceDim,
                      ),
                    ),
                ],
              ),
            ),

            // Status text
            Text(
              friend.status.toUpperCase(),
              style: AppTypography.tacticalLabel(
                fontSize: 8,
                color: friend.isOnline ? AppColors.statusOnline : AppColors.onSurfaceDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsBold.usersThree, size: 48, color: AppColors.onSurfaceDim),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'NO FRIENDS YET',
            style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Search and add friends to get started',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceDim,
                ),
          ),
        ],
      ),
    );
  }
}
