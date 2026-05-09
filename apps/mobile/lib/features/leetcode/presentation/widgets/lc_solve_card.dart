import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../providers/leetcode_provider.dart';

/// Compact solve card for recent solves list.
class LCSolveCard extends StatefulWidget {
  const LCSolveCard({super.key, required this.solve, this.isNew = false});
  final SolveRecord solve;
  final bool isNew;

  @override
  State<LCSolveCard> createState() => _LCSolveCardState();
}

class _LCSolveCardState extends State<LCSolveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.medium);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _diffColor {
    switch (widget.solve.difficulty.toUpperCase()) {
      case 'EASY': return AppColors.easy;
      case 'MEDIUM': return AppColors.medium;
      case 'HARD': return AppColors.hard;
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solve;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: widget.isNew
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: AppRadius.cardRadius,
          border: const Border(
            bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Difficulty dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _diffColor,
                boxShadow: [
                  BoxShadow(
                    color: _diffColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),

            // Problem info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.problemName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Difficulty badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _diffColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.chipRadius,
                        ),
                        child: Text(
                          s.difficulty.toUpperCase(),
                          style: AppTypography.tacticalLabel(fontSize: 7, color: _diffColor),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Language
                      Text(
                        s.language.toUpperCase(),
                        style: AppTypography.tacticalLabel(
                            fontSize: 7, color: AppColors.onSurfaceDim),
                      ),
                      if (s.runtime != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(PhosphorIconsBold.lightning, size: 8, color: AppColors.onSurfaceDim),
                        Text(
                          '${s.runtime}ms',
                          style: AppTypography.tacticalLabel(
                              fontSize: 7, color: AppColors.onSurfaceDim),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Timestamp
            Text(
              s.timeAgo,
              style: AppTypography.tacticalLabel(
                  fontSize: 8, color: AppColors.onSurfaceDim),
            ),
          ],
        ),
      ),
    );
  }
}
