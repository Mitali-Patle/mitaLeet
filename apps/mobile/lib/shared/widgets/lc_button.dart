import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Primary and secondary button variants.
///
/// Styled for the cyber-industrial aesthetic with
/// sharp corners and compact padding.
class LCButton extends StatelessWidget {
  const LCButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = LCButtonVariant.primary,
    this.isLoading = false,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LCButtonVariant variant;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
        );

    Widget buttonChild = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onSurface,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.iconTextGap),
          ],
          Text(label.toUpperCase(), style: textStyle),
        ],
      ],
    );

    switch (variant) {
      case LCButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
      case LCButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
      case LCButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onSurfaceMedium,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
          ),
          child: buttonChild,
        );
    }
  }
}

enum LCButtonVariant { primary, secondary, ghost }
