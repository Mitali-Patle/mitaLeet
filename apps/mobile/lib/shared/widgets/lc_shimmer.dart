import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Shimmer loading placeholder.
///
/// Renders a pulsing skeleton with the matte surface color scheme.
/// When [itemCount] is provided, renders a scrollable list of
/// shimmer skeleton rows.
class LCShimmer extends StatelessWidget {
  const LCShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.itemCount,
  });

  /// Rectangular shimmer for content blocks.
  const LCShimmer.rect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : itemCount = null;

  /// Circular shimmer for avatars.
  const LCShimmer.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        itemCount = null;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  /// When non-null, renders a list of [itemCount] skeleton rows
  /// instead of a single shimmer block.
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    if (itemCount != null) {
      return Shimmer.fromColors(
        baseColor: AppColors.surfaceContainer,
        highlightColor: AppColors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: List.generate(itemCount!, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: AppRadius.circularRadius,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 8,
                            width: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      );
    }

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
