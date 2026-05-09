import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_animations.dart';

/// Realtime toast notification overlay.
///
/// Use [LCToastManager.show] to display a toast from anywhere.
class LCToastManager {
  static OverlayEntry? _currentEntry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Color? accentColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();
    _hideTimer?.cancel();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _LCToast(
        title: title,
        subtitle: subtitle,
        accentColor: accentColor ?? AppColors.primary,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _hideTimer = Timer(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _LCToast extends StatefulWidget {
  const _LCToast({
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.onDismiss,
  });

  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onDismiss;

  @override
  State<_LCToast> createState() => _LCToastState();
}

class _LCToastState extends State<_LCToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.medium);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.sharp));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpacing.md,
      left: AppSpacing.screenPadding,
      right: AppSpacing.screenPadding,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onDismiss,
            onVerticalDragEnd: (_) => widget.onDismiss(),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: widget.accentColor,
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.onSurface,
                              ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: AppTypography.tacticalLabel(
                              fontSize: 9,
                              color: AppColors.onSurfaceDim,
                            ),
                          ),
                        ],
                      ],
                    ),
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
