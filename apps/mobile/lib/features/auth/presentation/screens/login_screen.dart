import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../shared/widgets/lc_button.dart';
import '../../../auth/providers/auth_provider.dart';

/// Login screen with Google OAuth.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Show error snackbar when auth fails
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  (AppSpacing.xxl * 2),
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.surfaceBorder,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'LC',
                        style: AppTypography.stat(
                          fontSize: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Title
                  Text(
                    'MITALEET',
                    style: AppTypography.stat(
                      fontSize: 22,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'COMPETITIVE CODING OS',
                    style: AppTypography.tacticalLabel(
                      fontSize: 10,
                      color: AppColors.onSurfaceDim,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.huge),

                  // Feature list
                  _FeatureRow(
                    icon: PhosphorIconsBold.trophy,
                    text: 'REALTIME LEADERBOARDS',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FeatureRow(
                    icon: PhosphorIconsBold.flame,
                    text: 'STREAK TRACKING',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FeatureRow(
                    icon: PhosphorIconsBold.usersThree,
                    text: 'PRIVATE CODING SQUADS',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FeatureRow(
                    icon: PhosphorIconsBold.sword,
                    text: 'SOLVE RACES',
                  ),

                  const Spacer(),

                  // Sign in button
                  SizedBox(
                    width: double.infinity,
                    child: LCButton(
                      label: 'CONTINUE WITH GOOGLE',
                      icon: PhosphorIconsBold.googleLogo,
                      isLoading: authState.isLoading,
                      isExpanded: true,
                      onPressed: () {
                        ref.read(authStateProvider.notifier).signInWithGoogle();
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Terms
                  Text(
                    'BY CONTINUING YOU AGREE TO OUR TERMS',
                    style: AppTypography.tacticalLabel(
                      fontSize: 8,
                      color: AppColors.onSurfaceDim,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // DEV ONLY bypass button — remove before production
                  if (kDebugMode) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: authState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(authStateProvider.notifier)
                                    .devBypass();
                                // Router redirect handles navigation automatically
                                // once isAuthenticated becomes true.
                              },
                        child: Text(
                          '⚡ DEV: SKIP LOGIN',
                          style: AppTypography.tacticalLabel(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Text(text, style: AppTypography.tacticalLabel(color: AppColors.onSurfaceMedium)),
      ],
    );
  }
}
