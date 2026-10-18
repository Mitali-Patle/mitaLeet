import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../providers/groups_provider.dart';

/// Squad (circles) screen — list of coding groups with live API data.
class CirclesScreen extends ConsumerStatefulWidget {
  const CirclesScreen({super.key});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(groupsProvider.notifier).loadGroups());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showJoinDialog() {
    _codeCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Join Squad', style: Theme.of(context).textTheme.titleSmall),
        content: TextField(
          controller: _codeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'SQUAD CODE',
            hintStyle: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(groupsProvider.notifier)
                  .joinGroup(_codeCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Joined squad!' : ref.read(groupsProvider).error ?? 'Failed'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              }
            },
            child: Text('JOIN', style: AppTypography.tacticalLabel(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    _nameCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Create Squad', style: Theme.of(context).textTheme.titleSmall),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Squad name',
            hintStyle: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(groupsProvider.notifier)
                  .createGroup(_nameCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Squad created!' : ref.read(groupsProvider).error ?? 'Failed'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              }
            },
            child: Text('CREATE', style: AppTypography.tacticalLabel(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Squads',
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.plus, size: 20),
            onPressed: _showCreateDialog,
            color: AppColors.primary,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () => ref.read(groupsProvider.notifier).loadGroups(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Join code input ──────────────────────────────
              GestureDetector(
                onTap: _showJoinDialog,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIconsBold.link, size: 16, color: AppColors.onSurfaceDim),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'ENTER SQUAD CODE TO JOIN',
                          style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim),
                        ),
                      ),
                      if (gs.isJoining)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.primary),
                        )
                      else
                        Icon(PhosphorIconsBold.arrowRight, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              Text('YOUR SQUADS', style: AppTypography.tacticalLabel()),
              const SizedBox(height: AppSpacing.md),

              if (gs.isLoading && gs.groups.isEmpty)
                const LCShimmer(itemCount: 3)
              else if (gs.groups.isEmpty)
                LCCard(
                  child: Center(
                    child: Text(
                      'NO SQUADS YET — JOIN OR CREATE ONE',
                      style: AppTypography.tacticalLabel(
                        color: AppColors.onSurfaceDim,
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
              else
                ...gs.groups.asMap().entries.map((e) {
                  final group = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.itemGap),
                    child: _SquadCard(
                      name: group.name,
                      memberCount: group.memberCount,
                      activeMemberCount: group.activeMemberCount,
                      code: group.code,
                      rank: group.rank,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({
    required this.name,
    required this.memberCount,
    required this.activeMemberCount,
    required this.code,
    this.rank,
  });

  final String name;
  final int memberCount;
  final int activeMemberCount;
  final String code;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return LCCard(
      metallicAccent: true,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTypography.stat(fontSize: 16, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: AppTypography.tacticalLabel(
                          fontSize: 9, color: AppColors.onSurfaceDim),
                    ),
                  ],
                ),
              ),
              if (rank != null)
                Text(
                  '#$rank',
                  style: AppTypography.stat(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(PhosphorIconsBold.users, size: 12, color: AppColors.onSurfaceDim),
              const SizedBox(width: 4),
              Text(
                '$memberCount MEMBERS',
                style: AppTypography.tacticalLabel(fontSize: 9),
              ),
              const SizedBox(width: AppSpacing.lg),
              const LCStatusBadge(status: UserStatusType.online, size: 6),
              const SizedBox(width: 4),
              Text(
                '$activeMemberCount ACTIVE',
                style: AppTypography.tacticalLabel(
                  fontSize: 9,
                  color: AppColors.statusOnline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
