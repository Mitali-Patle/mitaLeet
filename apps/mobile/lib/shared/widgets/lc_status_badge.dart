import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Status badge for ONLINE / SOLVING / IDLE / OFFLINE.
///
/// Includes pulsing animation for active states.
class LCStatusBadge extends StatefulWidget {
  const LCStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.size = 8,
  });

  final UserStatusType status;
  final bool showLabel;
  final double size;

  @override
  State<LCStatusBadge> createState() => _LCStatusBadgeState();
}

class _LCStatusBadgeState extends State<LCStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_shouldPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  bool get _shouldPulse =>
      widget.status == UserStatusType.online ||
      widget.status == UserStatusType.solving;

  @override
  void didUpdateWidget(LCStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case UserStatusType.online:
        return AppColors.statusOnline;
      case UserStatusType.solving:
        return AppColors.statusSolving;
      case UserStatusType.idle:
        return AppColors.statusIdle;
      case UserStatusType.offline:
        return AppColors.statusOffline;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case UserStatusType.online:
        return 'Online';
      case UserStatusType.solving:
        return 'Solving';
      case UserStatusType.idle:
        return 'Idle';
      case UserStatusType.offline:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
                boxShadow: _shouldPulse
                    ? [
                        BoxShadow(
                          color: _statusColor
                              .withValues(alpha: _pulseAnimation.value * 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            _statusLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _statusColor,
                  letterSpacing: 1.0,
                ),
          ),
        ],
      ],
    );
  }
}

enum UserStatusType { online, solving, idle, offline }
