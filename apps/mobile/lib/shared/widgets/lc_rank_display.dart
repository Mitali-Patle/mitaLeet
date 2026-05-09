import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shadows.dart';

/// Rank display with metallic accent for top positions.
class LCRankDisplay extends StatelessWidget {
  const LCRankDisplay({
    super.key,
    required this.rank,
    this.size = 40,
    this.showLabel = true,
  });

  final int rank;
  final double size;
  final bool showLabel;

  Color get _color {
    if (rank == 1) return const Color(0xFFD4A843); // Gold
    if (rank == 2) return AppColors.metallicLight;  // Silver
    if (rank == 3) return const Color(0xFFB87333);  // Bronze
    return AppColors.onSurfaceDim;
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTop3
                ? _color.withValues(alpha: 0.15)
                : AppColors.surfaceContainer,
            border: Border.all(
              color: isTop3
                  ? _color.withValues(alpha: 0.6)
                  : AppColors.surfaceBorder,
              width: isTop3 ? 1.5 : 1,
            ),
            boxShadow: isTop3
                ? AppShadows.statusGlow(_color, intensity: 0.2)
                : null,
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: AppTypography.rank(
                fontSize: size * 0.35,
                color: _color,
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            _rankLabel,
            style: AppTypography.tacticalLabel(
              fontSize: 8,
              color: _color,
            ),
          ),
        ],
      ],
    );
  }

  String get _rankLabel {
    if (rank == 1) return 'FIRST';
    if (rank == 2) return 'SECOND';
    if (rank == 3) return 'THIRD';
    return 'RANK';
  }
}
