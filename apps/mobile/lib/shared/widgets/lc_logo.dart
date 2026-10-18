import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// mitaLeet brand mark: three ascending bars (practice that adds up) on the
/// brand orange, optionally followed by the wordmark.
class LCLogo extends StatelessWidget {
  const LCLogo({super.key, this.size = 28, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.36),
        Text(
          'mitaLeet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: size * 0.64,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.onSurface,
              ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
      Paint()..color = AppColors.primary,
    );
    final bar = Paint()..color = const Color(0xFF16100C);
    final w = s * 0.14;
    final gap = s * 0.08;
    final left = (s - (3 * w + 2 * gap)) / 2;
    final bottom = s * 0.74;
    for (final (i, h) in const [(0, 0.22), (1, 0.34), (2, 0.48)]) {
      final x = left + i * (w + gap);
      canvas.drawRRect(
        RRect.fromLTRBR(x, bottom - s * h, x + w, bottom, Radius.circular(w * 0.3)),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
