import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Set once the server has issued a verification code for [_pendingUsername].
  String? _code;
  String? _pendingUsername;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final username = _controller.text.trim();
    if (username.isEmpty) return;

    final code = await ref.read(leetcodeProvider.notifier).requestLinkCode(username);
    if (!mounted) return;

    if (code != null) {
      setState(() {
        _code = code;
        _pendingUsername = username;
      });
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

  Future<void> _verify() async {
    final username = _pendingUsername;
    if (username == null) return;

    final ok = await ref.read(leetcodeProvider.notifier).verifyLink(username);
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
        title: 'Not verified yet',
        subtitle: err ?? 'Code not found on your LeetCode profile',
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
            : _code != null
                ? _VerifyView(
                    username: _pendingUsername!,
                    code: _code!,
                    isVerifying: state.isLinking,
                    onVerify: _verify,
                    onChangeUsername: () => setState(() => _code = null),
                  )
                : _LinkForm(
                    controller: _controller,
                    isLinking: state.isLinking,
                    onLink: _requestCode,
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
            label: 'CONTINUE',
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

/// Step 2: show the code to paste into LeetCode's "About me", then verify.
class _VerifyView extends StatelessWidget {
  const _VerifyView({
    required this.username,
    required this.code,
    required this.isVerifying,
    required this.onVerify,
    required this.onChangeUsername,
  });

  final String username;
  final String code;
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onChangeUsername;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceMedium,
          height: 1.6,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('VERIFY @$username', style: AppTypography.stat(fontSize: 18, color: AppColors.onSurface)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'To prove this LeetCode account is yours, add the code below anywhere in your '
          'LeetCode profile "About me" (Edit Profile → Summary), save, then tap Verify. '
          'You can remove it once linked.',
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.xxl),

        Text('YOUR CODE', style: AppTypography.tacticalLabel()),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: AppTypography.stat(fontSize: 15, color: AppColors.onSurface),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(PhosphorIconsBold.copy, size: 18, color: AppColors.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  LCToastManager.show(
                    context,
                    title: 'Copied',
                    subtitle: 'Paste it into your LeetCode profile summary',
                    accentColor: AppColors.success,
                  );
                },
              ),
            ],
          ),
        ),
        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: LCButton(
            label: 'VERIFY',
            icon: PhosphorIconsBold.sealCheck,
            isLoading: isVerifying,
            isExpanded: true,
            onPressed: onVerify,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onChangeUsername,
            child: Text(
              'USE A DIFFERENT USERNAME',
              style: AppTypography.tacticalLabel(fontSize: 10, color: AppColors.onSurfaceMedium),
            ),
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
