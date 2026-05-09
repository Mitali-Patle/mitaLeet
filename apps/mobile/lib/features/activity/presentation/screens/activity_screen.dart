import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_activity_tile.dart';

/// Realtime activity feed screen.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Activity'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter row ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _FilterChip(label: 'ALL', isSelected: true),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'SOLVES', isSelected: false),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'STREAKS', isSelected: false),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'CHALLENGES', isSelected: false),
                const Spacer(),
                // Live indicator
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: AppTypography.tacticalLabel(
                        fontSize: 8,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Activity feed ─────────────────────────────────
          Expanded(
            child: ListView(
              children: const [
                LCActivityTile(
                  displayName: 'akshay',
                  action: 'solved',
                  detail: 'two-sum',
                  timestamp: '2m',
                  difficulty: 'EASY',
                ),
                LCActivityTile(
                  displayName: 'priya',
                  action: 'solved',
                  detail: 'merge-k-sorted-lists',
                  timestamp: '5m',
                  difficulty: 'HARD',
                ),
                LCActivityTile(
                  displayName: 'mitali',
                  action: 'extended streak to',
                  detail: '15 days',
                  timestamp: '8m',
                ),
                LCActivityTile(
                  displayName: 'rahul',
                  action: 'joined challenge',
                  detail: 'Binary Search Sprint',
                  timestamp: '12m',
                ),
                LCActivityTile(
                  displayName: 'sneha',
                  action: 'solved',
                  detail: 'longest-substring-without-repeating',
                  timestamp: '18m',
                  difficulty: 'MEDIUM',
                ),
                LCActivityTile(
                  displayName: 'arjun',
                  action: 'solved',
                  detail: 'container-with-most-water',
                  timestamp: '25m',
                  difficulty: 'MEDIUM',
                ),
                LCActivityTile(
                  displayName: 'neha',
                  action: 'started streak',
                  detail: 'Day 1',
                  timestamp: '32m',
                ),
                LCActivityTile(
                  displayName: 'vikram',
                  action: 'solved',
                  detail: 'valid-parentheses',
                  timestamp: '45m',
                  difficulty: 'EASY',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.tacticalLabel(
          fontSize: 8,
          color: isSelected ? AppColors.primary : AppColors.onSurfaceDim,
        ),
      ),
    );
  }
}
