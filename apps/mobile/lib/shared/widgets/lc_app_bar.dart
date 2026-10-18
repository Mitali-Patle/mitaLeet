import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Custom app bar with industrial styling.
///
/// Wraps Flutter's native [AppBar] so the [Scaffold] computes the
/// intrinsic height correctly (no manual preferredSize tricks needed).
class LCAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LCAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showBorder = true,
    this.bottom,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBorder;

  /// Optional widget displayed below the title row (e.g. a [TabBar]).
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight +
            (showBorder ? 0.5 : 0) +
            (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: AppSpacing.screenPadding,
      leading: leading,
      leadingWidth: leading != null ? 48 : 0,
      title: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              letterSpacing: 1.5,
              color: AppColors.onSurface,
            ),
      ),
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: AppSpacing.sm),
      ],
      bottom: showBorder
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottom?.preferredSize.height ?? 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: AppColors.surfaceBorder,
                  ),
                  if (bottom != null) bottom!,
                ],
              ),
            )
          : bottom,
    );
  }
}
