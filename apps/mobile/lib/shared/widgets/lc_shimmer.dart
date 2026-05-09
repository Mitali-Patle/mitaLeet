import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Shimmer loading placeholder.
///
/// Renders a pulsing skeleton with the matte surface color scheme.
class LCShimmer extends StatelessWidget {
  const LCShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// Rectangular shimmer for content blocks.
  const LCShimmer.rect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  /// Circular shimmer for avatars.
  const LCShimmer.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceContainerHigh,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: borderRadius ??
              (width == height
                  ? AppRadius.circularRadius
                  : AppRadius.cardRadius),
        ),
      ),
    );
  }
}
