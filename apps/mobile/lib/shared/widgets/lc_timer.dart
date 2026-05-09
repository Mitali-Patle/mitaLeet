import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Timer display using IBM Plex Mono.
class LCTimer extends StatelessWidget {
  const LCTimer({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.fontSize = 28,
  });

  final String value;
  final String? label;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTypography.timer(fontSize: fontSize, color: color)),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(label!.toUpperCase(), style: AppTypography.tacticalLabel(fontSize: 9)),
        ],
      ],
    );
  }
}
