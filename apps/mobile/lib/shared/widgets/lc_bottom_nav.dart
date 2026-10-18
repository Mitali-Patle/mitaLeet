import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/phosphor_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';

/// Bottom navigation bar with 5 tabs and industrial styling.
///
/// Uses Phosphor outlined icons. Active tab uses burnt orange
/// with subtle glow underline indicator.
class LCScaffoldWithNav extends StatelessWidget {
  const LCScaffoldWithNav({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/leaderboard')) return 1;
    if (location.startsWith('/activity')) return 2;
    if (location.startsWith('/coding')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    const routes = ['/', '/leaderboard', '/activity', '/coding', '/profile'];
    context.go(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: PhosphorIconsBold.house,
                  label: 'HOME',
                  isSelected: currentIndex == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  icon: PhosphorIconsBold.trophy,
                  label: 'RANK',
                  isSelected: currentIndex == 1,
                  onTap: () => _onTap(context, 1),
                ),
                _NavItem(
                  icon: PhosphorIconsBold.pulse,
                  label: 'ACTIVITY',
                  isSelected: currentIndex == 2,
                  onTap: () => _onTap(context, 2),
                ),
                _NavItem(
                  icon: PhosphorIconsBold.code,
                  label: 'CODING',
                  isSelected: currentIndex == 3,
                  onTap: () => _onTap(context, 3),
                ),
                _NavItem(
                  icon: PhosphorIconsBold.user,
                  label: 'PROFILE',
                  isSelected: currentIndex == 4,
                  onTap: () => _onTap(context, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.onSurfaceDim;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppAnimations.fast,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 1.0,
                    fontSize: 9,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 3),
            // Active tab indicator line
            AnimatedContainer(
              duration: AppAnimations.medium,
              curve: AppAnimations.sharp,
              width: isSelected ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
