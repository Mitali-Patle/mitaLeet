import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../providers/groups_provider.dart';
import 'group_detail_screen.dart';

/// `/squads/:id`: finds the squad in the user's squad list (loading it after
/// a reload or from a shared link) and shows its detail page.
class SquadDetailRoute extends ConsumerStatefulWidget {
  const SquadDetailRoute({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<SquadDetailRoute> createState() => _SquadDetailRouteState();
}

class _SquadDetailRouteState extends ConsumerState<SquadDetailRoute> {
  @override
  void initState() {
    super.initState();
    if (ref.read(groupsProvider).groups.isEmpty) {
      Future.microtask(() => ref.read(groupsProvider.notifier).loadGroups());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupsProvider);
    final group = state.groups.where((g) => g.id == widget.groupId).firstOrNull;

    if (group == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const LCAppBar(title: 'Squad'),
        body: Center(
          child: state.isLoading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Text(
                  'Squad not found. You may not be a member.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMedium),
                ),
        ),
      );
    }

    return GroupDetailScreen(group: group);
  }
}
