import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_logo.dart';
import '../../../auth/providers/auth_provider.dart';

const _features = [
  (PhosphorIconsBold.usersThree, 'Private squads', 'Invite friends with a code and see who practised today.'),
  (PhosphorIconsBold.flame, 'Streaks that count', 'Verified LeetCode solves keep your streak, in your own timezone.'),
  (PhosphorIconsBold.trophy, 'Live leaderboards', 'Weekly and all-time rankings for your squad and friends.'),
  (PhosphorIconsBold.flagCheckered, 'Solve races', 'Race friends on the same problem, timed by LeetCode.'),
];

/// Sign-in page: product pitch beside a focused sign-in panel on wide
/// screens, a single column on phones.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: wide
            ? const Row(
                children: [
                  Expanded(flex: 11, child: _PitchPanel()),
                  VerticalDivider(width: 1, thickness: 1, color: AppColors.surfaceBorder),
                  Expanded(flex: 9, child: Center(child: _SignInPanel())),
                ],
              )
            : const _NarrowLayout(),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LCLogo(size: 30),
          const SizedBox(height: AppSpacing.huge),
          Text('Practice together.\nStay consistent.', style: text.displaySmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'mitaLeet turns your LeetCode practice into a habit you share with friends.',
            style: text.bodyLarge?.copyWith(color: AppColors.onSurfaceMedium),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const _SignInPanel(compact: true),
          const SizedBox(height: AppSpacing.huge),
          for (final f in _features) ...[
            _FeatureItem(icon: f.$1, title: f.$2, body: f.$3),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _PitchPanel extends StatelessWidget {
  const _PitchPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.9, -1.0),
          radius: 1.3,
          colors: [AppColors.primary.withValues(alpha: 0.10), AppColors.surface],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 40, 56, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LCLogo(size: 28),
            const Spacer(flex: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Practice together.\nStay consistent.', style: text.displayLarge),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'mitaLeet turns your LeetCode practice into a habit you share with friends: '
                    'verified solves, streaks and friendly competition.',
                    style: text.bodyLarge?.copyWith(color: AppColors.onSurfaceMedium, fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                  Wrap(
                    spacing: AppSpacing.xxl,
                    runSpacing: AppSpacing.xxl,
                    children: [
                      for (final f in _features)
                        SizedBox(width: 260, child: _FeatureItem(icon: f.$1, title: f.$2, body: f.$3)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            Text(
              'Not affiliated with LeetCode.',
              style: text.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryLight),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall?.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMedium, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignInPanel extends ConsumerWidget {
  const _SignInPanel({this.compact = false});

  /// Inside the phone layout: no heading, the page already has one.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isLoading = ref.watch(authStateProvider.select((s) => s.isLoading));
    final notifier = ref.read(authStateProvider.notifier);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text('Sign in', style: text.headlineLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Use your Google account to continue. New here? Signing in creates your account.',
                style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMedium),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            _GoogleButton(isLoading: isLoading, onPressed: notifier.signInWithGoogle),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'We use your Google name, email and photo to create your profile.',
              style: text.bodySmall?.copyWith(color: AppColors.onSurfaceDim),
              textAlign: compact ? TextAlign.start : TextAlign.center,
            ),

            // Debug builds only; the server also refuses dev login in production.
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: isLoading ? null : notifier.devBypass,
                child: Text(
                  'Developer sign-in',
                  style: AppTypography.tacticalLabel(fontSize: 11, color: AppColors.primaryLight),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1F1F);
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsBold.googleLogo, size: 18, color: ink),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Flexible(
                    child: Text(
                      'Continue with Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink, fontSize: 15),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
