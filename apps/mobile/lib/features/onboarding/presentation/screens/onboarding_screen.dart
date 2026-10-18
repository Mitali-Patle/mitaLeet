import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../shared/widgets/lc_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../leetcode/presentation/screens/leetcode_link_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_button.dart';
import '../../../../core/theme/phosphor_icons.dart';

/// Onboarding screen — username + LeetCode setup for new users.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Same rule as the server: 3-24 lowercase letters, digits or underscores.
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,24}$');

  final _usernameController = TextEditingController();
  final _leetcodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _leetcodeController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(username)) {
      _toast('Invalid username', '3-24 characters: lowercase letters, numbers, underscores');
      return;
    }
    setState(() => _isLoading = true);

    try {
      await ref.read(apiClientProvider).put(
        ApiEndpoints.usersMeProfile,
        data: {'username': username},
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast(
        'Could not save username',
        e.response?.statusCode == 409 ? 'That username is taken' : 'Check your connection and try again',
      );
      return;
    }
    if (!mounted) return;

    ref.read(authStateProvider.notifier).completeOnboarding();
    context.go('/');

    // Linking needs a verification step, so continue on the LeetCode screen.
    final leetcode = _leetcodeController.text.trim();
    if (leetcode.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LeetCodeLinkScreen(initialUsername: leetcode)),
      );
    }
  }

  void _toast(String title, String subtitle) {
    LCToastManager.show(context, title: title, subtitle: subtitle, accentColor: AppColors.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.huge),

              Text(
                'SET UP YOUR PROFILE',
                style: AppTypography.stat(
                  fontSize: 20,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'CHOOSE A USERNAME AND LINK YOUR LEETCODE ACCOUNT',
                style: AppTypography.tacticalLabel(
                  color: AppColors.onSurfaceDim,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Username field
              Text(
                'USERNAME',
                style: AppTypography.tacticalLabel(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'your_username',
                  prefixIcon: Icon(PhosphorIconsBold.at, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // LeetCode username field
              Text(
                'LEETCODE USERNAME',
                style: AppTypography.tacticalLabel(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _leetcodeController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'leetcode_username',
                  prefixIcon: Icon(PhosphorIconsBold.code, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'OPTIONAL. REQUIRED FOR AUTOMATIC SOLVE TRACKING.',
                style: AppTypography.tacticalLabel(
                  fontSize: 8,
                  color: AppColors.onSurfaceDim,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: LCButton(
                  label: 'COMPLETE SETUP',
                  isLoading: _isLoading,
                  isExpanded: true,
                  onPressed: _completeSetup,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
