import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../friends/providers/friends_provider.dart';

/// Search and add friends.
class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Add Friends'),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(PhosphorIconsBold.magnifyingGlass, size: 18),
                suffixIcon: state.isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              onChanged: (query) {
                ref.read(friendsProvider.notifier).search(query);
              },
            ),
          ),

          // Results
          Expanded(
            child: state.searchResults.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.isEmpty
                          ? 'Type to search users'
                          : 'No results found',
                      style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    itemCount: state.searchResults.length,
                    itemBuilder: (context, index) {
                      final user = state.searchResults[index];
                      return _SearchResultTile(
                        user: user,
                        onSendRequest: () {
                          ref.read(friendsProvider.notifier).sendRequest(
                            user['userId'] as String,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.user, required this.onSendRequest});
  final Map<String, dynamic> user;
  final VoidCallback onSendRequest;

  @override
  Widget build(BuildContext context) {
    final isFriend = user['isFriend'] == true;
    final hasPending = user['hasPendingRequest'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
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
                (user['displayName'] as String? ?? '?')[0].toUpperCase(),
                style: AppTypography.stat(fontSize: 16, color: AppColors.onSurfaceMedium),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['displayName'] as String? ?? '',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '@${user['username'] ?? ''}',
                  style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.onSurfaceDim),
                ),
              ],
            ),
          ),
          if (isFriend)
            Text('Friends', style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.success))
          else if (hasPending)
            Text('Pending', style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.secondary))
          else
            GestureDetector(
              onTap: onSendRequest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(
                  'Add',
                  style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
