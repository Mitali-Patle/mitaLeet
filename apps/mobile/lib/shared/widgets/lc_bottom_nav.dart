import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/phosphor_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import 'lc_logo.dart';

/// Screens at least this wide get a sidebar instead of the bottom bar.
const double kSidebarBreakpoint = 900;

/// Page content never stretches wider than this, so text and lists stay
/// readable on large monitors.
const double kMaxContentWidth = 960;

class _Tab {
  const _Tab(this.path, this.icon, this.label);
  final String path;
  final IconData icon;
  final String label;
}

const _tabs = [
  _Tab('/', PhosphorIconsBold.house, 'Home'),
  _Tab('/leaderboard', PhosphorIconsBold.trophy, 'Leaderboard'),
  _Tab('/activity', PhosphorIconsBold.pulse, 'Activity'),
  _Tab('/coding', PhosphorIconsBold.code, 'Coding'),
  _Tab('/profile', PhosphorIconsBold.user, 'Profile'),
];

/// App shell: a sidebar on wide screens, a bottom bar on phones.
class LCScaffoldWithNav extends StatelessWidget {
  const LCScaffoldWithNav({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = _tabs.length - 1; i > 0; i--) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    void open(int i) => context.go(_tabs[i].path);
    final wide = MediaQuery.sizeOf(context).width >= kSidebarBreakpoint;

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(current: current, onSelect: open),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.surfaceBorder),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _BottomItem(tab: _tabs[i], selected: i == current, onTap: () => open(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: LCLogo(size: 26),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < _tabs.length; i++)
            _SidebarItem(tab: _tabs[i], selected: i == current, onTap: () => onSelect(i)),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onSurface : AppColors.onSurfaceMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.surfaceVariant : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 9),
            child: Row(
              children: [
                Icon(tab.icon, size: 18, color: selected ? AppColors.primary : color),
                const SizedBox(width: AppSpacing.md),
                Text(
                  tab.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceDim;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.94,
            duration: AppAnimations.fast,
            child: Icon(tab.icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
