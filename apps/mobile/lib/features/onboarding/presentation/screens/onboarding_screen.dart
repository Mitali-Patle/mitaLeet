import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../shared/widgets/lc_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Onboarding screen — username + LeetCode setup for new users.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    // TODO: Call API to update profile
    await Future.delayed(AppAnimations.slow);

    if (mounted) context.go('/');
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
