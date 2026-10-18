import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../friends/providers/friends_provider.dart';

/// Incoming and outgoing friend requests.
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(friendsProvider.notifier).loadIncoming();
      ref.read(friendsProvider.notifier).loadOutgoing();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(title: 'Requests'),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(5),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: AppTypography.tacticalLabel(fontSize: 10),
              unselectedLabelStyle: AppTypography.tacticalLabel(fontSize: 10),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceDim,
              dividerHeight: 0,
              tabs: [
                Tab(text: 'INCOMING (${state.incoming.length})'),
                Tab(text: 'OUTGOING (${state.outgoing.length})'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Incoming
                _RequestList(
                  requests: state.incoming,
                  type: 'incoming',
                  onAccept: (id) => ref.read(friendsProvider.notifier).acceptRequest(id),
                  onDecline: (id) => ref.read(friendsProvider.notifier).declineRequest(id),
                ),
                // Outgoing
                _RequestList(
                  requests: state.outgoing,
                  type: 'outgoing',
                  onCancel: (id) => ref.read(friendsProvider.notifier).cancelRequest(id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.type,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final List<FriendRequest> requests;
  final String type;
  final void Function(String)? onAccept;
  final void Function(String)? onDecline;
  final void Function(String)? onCancel;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          'NO ${type.toUpperCase()} REQUESTS',
          style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return AnimatedContainer(
          duration: AppAnimations.fast,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    req.displayName.isNotEmpty ? req.displayName[0].toUpperCase() : '?',
                    style: AppTypography.stat(fontSize: 16, color: AppColors.onSurfaceMedium),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.displayName, style: Theme.of(context).textTheme.titleSmall),
                    if (req.username != null)
                      Text(
                        '@${req.username}',
                        style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.onSurfaceDim),
                      ),
                  ],
                ),
              ),

              if (type == 'incoming') ...[
                _ActionButton(
                  icon: PhosphorIconsBold.check,
                  color: AppColors.success,
                  onTap: () => onAccept?.call(req.id),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ActionButton(
                  icon: PhosphorIconsBold.x,
                  color: AppColors.error,
                  onTap: () => onDecline?.call(req.id),
                ),
              ] else ...[
                _ActionButton(
                  icon: PhosphorIconsBold.x,
                  color: AppColors.onSurfaceDim,
                  onTap: () => onCancel?.call(req.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
