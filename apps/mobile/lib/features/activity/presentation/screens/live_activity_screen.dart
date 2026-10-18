import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../social/providers/activity_feed_provider.dart';

/// Live activity feed with realtime updates and infinite scroll.
class LiveActivityScreen extends ConsumerStatefulWidget {
  const LiveActivityScreen({super.key});

  @override
  ConsumerState<LiveActivityScreen> createState() => _LiveActivityScreenState();
}

class _LiveActivityScreenState extends ConsumerState<LiveActivityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(activityFeedProvider.notifier).loadFeed(refresh: true));
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(activityFeedProvider.notifier).loadFeed();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Activity'),
      body: Column(
        children: [
          // ── Filter + live indicator ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _FilterChip(label: 'ALL', isSelected: true),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'SOLVES', isSelected: false),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: 'STREAKS', isSelected: false),
                const Spacer(),
                _LiveIndicator(),
              ],
            ),
          ),

          // ── Feed ────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
              onRefresh: () => ref.read(activityFeedProvider.notifier).refresh(),
              child: state.events.isEmpty && state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : state.events.isEmpty
                      ? _EmptyFeed()
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: state.events.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.events.length) {
                              return const Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _LiveActivityTile(
                              event: state.events[index],
                              isNew: index == 0,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveActivityTile extends StatefulWidget {
  const _LiveActivityTile({required this.event, this.isNew = false});
  final ActivityEvent event;
  final bool isNew;

  @override
  State<_LiveActivityTile> createState() => _LiveActivityTileState();
}

class _LiveActivityTileState extends State<_LiveActivityTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.medium);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: AppAnimations.enter);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.sharp));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _diffColor {
    switch (widget.event.difficulty?.toUpperCase()) {
      case 'EASY': return AppColors.easy;
      case 'MEDIUM': return AppColors.medium;
      case 'HARD': return AppColors.hard;
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    widget.event.displayName.isNotEmpty
                        ? widget.event.displayName[0].toUpperCase()
                        : '?',
                    style: AppTypography.stat(fontSize: 12, color: AppColors.onSurfaceMedium),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: widget.event.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.event.actionText}',
                            style: const TextStyle(color: AppColors.onSurfaceMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.event.difficulty != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _diffColor.withValues(alpha: 0.15),
                              borderRadius: AppRadius.chipRadius,
                            ),
                            child: Text(
                              widget.event.difficulty!.toUpperCase(),
                              style: AppTypography.tacticalLabel(fontSize: 8, color: _diffColor),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            widget.event.detail,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceDim,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Text(
                widget.event.timeAgo,
                style: AppTypography.tacticalLabel(fontSize: 9, color: AppColors.onSurfaceDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: AppAnimations.pulse,
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.2 + _pulse.value * 0.3),
                  blurRadius: 4 + _pulse.value * 4,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'LIVE',
          style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.success),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.tacticalLabel(
          fontSize: 8,
          color: isSelected ? AppColors.primary : AppColors.onSurfaceDim,
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsBold.pulse, size: 48, color: AppColors.onSurfaceDim),
          const SizedBox(height: AppSpacing.lg),
          Text('NO ACTIVITY YET', style: AppTypography.tacticalLabel(color: AppColors.onSurfaceDim)),
        ],
      ),
    );
  }
}
