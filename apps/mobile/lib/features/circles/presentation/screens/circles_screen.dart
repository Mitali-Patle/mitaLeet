import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_card.dart';
import '../../../../shared/widgets/lc_status_badge.dart';

/// Squad (circles) screen — list of coding groups.
class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Squad',
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.plus, size: 20),
            onPressed: () {},
            color: AppColors.primary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Join code input ──────────────────────────────
            Container(
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
                  Icon(PhosphorIconsBold.arrowRight, size: 16, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            Text('YOUR SQUADS', style: AppTypography.tacticalLabel()),
            const SizedBox(height: AppSpacing.md),

            // ── Squad cards ─────────────────────────────────
            _SquadCard(
              name: 'DSA Grinders',
              memberCount: 8,
              activeMemberCount: 5,
              code: 'DSA-X7K2',
              rank: 3,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            _SquadCard(
              name: 'Interview Prep',
              memberCount: 12,
              activeMemberCount: 3,
              code: 'INT-M4P9',
              rank: 1,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            _SquadCard(
              name: 'Algo Masters',
              memberCount: 6,
              activeMemberCount: 2,
              code: 'ALG-R2D4',
              rank: 2,
            ),
          ],
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
    required this.rank,
  });

  final String name;
  final int memberCount;
  final int activeMemberCount;
  final String code;
  final int rank;

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
                    name[0],
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
                    Text(code, style: AppTypography.tacticalLabel(fontSize: 9)),
                  ],
                ),
              ),
              Text(
                '#$rank',
                style: AppTypography.rank(fontSize: 14),
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
