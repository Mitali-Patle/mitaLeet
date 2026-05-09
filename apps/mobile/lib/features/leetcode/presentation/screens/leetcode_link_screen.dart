import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_button.dart';
import '../../../../shared/widgets/lc_toast.dart';
import '../../providers/leetcode_provider.dart';

/// LeetCode account linking screen.
class LeetCodeLinkScreen extends ConsumerStatefulWidget {
  const LeetCodeLinkScreen({super.key});

  @override
  ConsumerState<LeetCodeLinkScreen> createState() => _LeetCodeLinkScreenState();
}

class _LeetCodeLinkScreenState extends ConsumerState<LeetCodeLinkScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final username = _controller.text.trim();
    if (username.isEmpty) return;

    final ok = await ref.read(leetcodeProvider.notifier).linkAccount(username);
    if (!mounted) return;

    if (ok) {
      LCToastManager.show(
        context,
        title: 'Account linked',
        subtitle: '@$username — initial sync started',
        accentColor: AppColors.success,
      );
      Navigator.pop(context);
    } else {
      final err = ref.read(leetcodeProvider).error;
      LCToastManager.show(
        context,
        title: 'Link failed',
        subtitle: err ?? 'Username not found on LeetCode',
        accentColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leetcodeProvider);
    final isLinked = state.linkStatus.isLinked;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'LeetCode Account'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: isLinked
            ? _LinkedView(
                username: state.linkStatus.leetcodeUsername!,
                lastSync: state.linkStatus.lastSyncAt,
                isSyncing: state.linkStatus.isSyncing,
                onSync: () => ref.read(leetcodeProvider.notifier).triggerSync(),
                onUnlink: () async {
                  await ref.read(leetcodeProvider.notifier).unlinkAccount();
                  if (mounted) Navigator.pop(context);
                },
              )
            : _LinkForm(
                controller: _controller,
                isLinking: state.isLinking,
                onLink: _link,
              ),
      ),
    );
  }
}

class _LinkForm extends StatelessWidget {
  const _LinkForm({
    required this.controller,
    required this.isLinking,
    required this.onLink,
  });

  final TextEditingController controller;
  final bool isLinking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),

        // Icon header
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: const Center(
            child: Icon(PhosphorIconsBold.code, size: 28, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('LINK LEETCODE', style: AppTypography.stat(fontSize: 18, color: AppColors.onSurface)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enter your LeetCode username to enable automatic solve tracking and streak sync.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMedium, height: 1.6),
        ),
        const SizedBox(height: AppSpacing.xxxl),

        Text('LEETCODE USERNAME', style: AppTypography.tacticalLabel()),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'e.g. leetcode_user',
            prefixIcon: Icon(PhosphorIconsBold.at, size: 18),
          ),
          onSubmitted: (_) => onLink(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'NO PASSWORD REQUIRED. WE ONLY READ YOUR PUBLIC PROFILE.',
          style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim),
        ),
        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: LCButton(
            label: 'LINK ACCOUNT',
            icon: PhosphorIconsBold.link,
            isLoading: isLinking,
            isExpanded: true,
            onPressed: onLink,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _LinkedView extends StatelessWidget {
  const _LinkedView({
    required this.username,
    required this.lastSync,
    required this.isSyncing,
    required this.onSync,
    required this.onUnlink,
  });

  final String username;
  final DateTime? lastSync;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onUnlink;

  String get _lastSyncText {
    if (lastSync == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSync!);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),

        // Linked card
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.checkCircle, size: 20, color: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$username', style: AppTypography.stat(fontSize: 15, color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text('LINKED · LAST SYNC $_lastSyncText',
                        style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Sync button
        SizedBox(
          width: double.infinity,
          child: LCButton(
            label: isSyncing ? 'SYNCING...' : 'SYNC NOW',
            icon: PhosphorIconsBold.arrowsClockwise,
            isLoading: isSyncing,
            isExpanded: true,
            onPressed: isSyncing ? null : onSync,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Auto-sync info
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.clock, size: 14, color: AppColors.onSurfaceDim),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'AUTOMATIC SYNC RUNS EVERY 30 MINUTES',
                  style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        // Unlink
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onUnlink,
            child: Text(
              'UNLINK ACCOUNT',
              style: AppTypography.tacticalLabel(fontSize: 10, color: AppColors.error),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
