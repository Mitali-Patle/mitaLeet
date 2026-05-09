import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_animations.dart';

/// Animated progress bar with optional glow.
class LCProgressBar extends StatefulWidget {
  const LCProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.color,
    this.backgroundColor,
    this.showGlow = false,
  });

  final double progress;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final bool showGlow;

  @override
  State<LCProgressBar> createState() => _LCProgressBarState();
}

class _LCProgressBarState extends State<LCProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.slow);
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: AppAnimations.sharp),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(LCProgressBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: AppAnimations.sharp),
      );
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _anim.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: widget.showGlow
                    ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
