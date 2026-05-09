import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Custom app bar with industrial styling.
///
/// Flat, borderless, with optional leading action and
/// trailing widgets.
class LCAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LCAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showBorder = true,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBorder;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: showBorder
            ? const Border(
                bottom: BorderSide(
                  color: AppColors.surfaceBorder,
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 1.5,
                      color: AppColors.onSurface,
                    ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
