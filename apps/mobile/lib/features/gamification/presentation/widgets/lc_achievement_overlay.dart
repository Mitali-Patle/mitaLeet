import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_animations.dart';
import '../../providers/gamification_provider.dart';

/// Overlay toast for achievement unlocks and XP gains.
/// Mount this in the root widget tree inside a Consumer.
class LCGamificationOverlay extends StatefulWidget {
  const LCGamificationOverlay({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  final Achievement achievement;
  final VoidCallback onDismiss;

  @override
  State<LCGamificationOverlay> createState() => _LCGamificationOverlayState();
}

class _LCGamificationOverlayState extends State<LCGamificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.medium);
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.sharp));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: AppSpacing.screenPadding,
      right: AppSpacing.screenPadding,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(PhosphorIconsBold.trophy, size: 20, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACHIEVEMENT UNLOCKED',
                          style: AppTypography.tacticalLabel(
                              fontSize: 8, color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.achievement.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          widget.achievement.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceDim,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${widget.achievement.xpReward} XP',
                    style: AppTypography.stat(fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
