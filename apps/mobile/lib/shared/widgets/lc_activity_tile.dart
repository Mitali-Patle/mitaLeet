import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_animations.dart';

/// Activity feed tile for realtime solve events.
class LCActivityTile extends StatefulWidget {
  const LCActivityTile({
    super.key,
    required this.displayName,
    required this.action,
    required this.detail,
    required this.timestamp,
    this.difficulty,
    this.avatarUrl,
  });

  final String displayName;
  final String action;
  final String detail;
  final String timestamp;
  final String? difficulty;
  final String? avatarUrl;

  @override
  State<LCActivityTile> createState() => _LCActivityTileState();
}

class _LCActivityTileState extends State<LCActivityTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppAnimations.enter,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color get _difficultyColor {
    switch (widget.difficulty?.toUpperCase()) {
      case 'EASY':
        return AppColors.easy;
      case 'MEDIUM':
        return AppColors.medium;
      case 'HARD':
        return AppColors.hard;
      default:
        return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.surfaceBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainer,
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  widget.displayName.isNotEmpty
                      ? widget.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.stat(
                    fontSize: 12,
                    color: AppColors.onSurfaceMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: widget.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: ' ${widget.action}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.difficulty != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _difficultyColor.withValues(alpha: 0.15),
                            borderRadius: AppRadius.chipRadius,
                          ),
                          child: Text(
                            widget.difficulty!.toUpperCase(),
                            style: AppTypography.tacticalLabel(
                              fontSize: 8,
                              color: _difficultyColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          widget.detail,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceDim,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Timestamp
            Text(
              widget.timestamp,
              style: AppTypography.tacticalLabel(
                fontSize: 9,
                color: AppColors.onSurfaceDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
