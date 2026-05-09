import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_streak_indicator.dart';
import '../../../../shared/widgets/lc_progress_bar.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../auth/providers/auth_provider.dart';

/// Profile screen — user stats and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.gear, size: 20),
            onPressed: () {},
            color: AppColors.onSurfaceMedium,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            // ── Avatar & name ───────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainer,
                      border: Border.all(
                        color: AppColors.metallic.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'M',
                        style: AppTypography.stat(
                          fontSize: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'mitali',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  const LCStatusBadge(status: UserStatusType.online),
                  const SizedBox(height: 8),
                  Text(
                    'MEMBER SINCE JAN 2025',
                    style: AppTypography.tacticalLabel(
                      fontSize: 8,
                      color: AppColors.onSurfaceDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Stats grid ──────────────────────────────────
            Row(
              children: const [
                Expanded(child: LCStatContainer(label: 'SOLVED', value: '128', valueColor: AppColors.success)),
                SizedBox(width: AppSpacing.itemGap),
                Expanded(child: LCStatContainer(label: 'XP', value: '2,050', valueColor: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.itemGap),
            Row(
              children: const [
                Expanded(child: LCStatContainer(label: 'GLOBAL RANK', value: '#3')),
                SizedBox(width: AppSpacing.itemGap),
                Expanded(child: LCStreakIndicator(currentStreak: 15, longestStreak: 23)),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Difficulty breakdown ────────────────────────
            LCMetallicContainer(
              intensity: MetallicIntensity.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DIFFICULTY BREAKDOWN', style: AppTypography.tacticalLabel()),
                  const SizedBox(height: AppSpacing.lg),
                  _DifficultyRow(label: 'EASY', count: 62, total: 128, color: AppColors.easy),
                  const SizedBox(height: AppSpacing.md),
                  _DifficultyRow(label: 'MEDIUM', count: 48, total: 128, color: AppColors.medium),
                  const SizedBox(height: AppSpacing.md),
                  _DifficultyRow(label: 'HARD', count: 18, total: 128, color: AppColors.hard),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Sign out ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ref.read(authStateProvider.notifier).signOut(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 0.5),
                  foregroundColor: AppColors.error,
                ),
                child: Text(
                  'SIGN OUT',
                  style: AppTypography.tacticalLabel(color: AppColors.error),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: AppTypography.tacticalLabel(fontSize: 9, color: color)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: LCProgressBar(
            progress: total > 0 ? count / total : 0,
            height: 4,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            style: AppTypography.stat(fontSize: 12, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
