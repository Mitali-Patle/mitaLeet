import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/lc_logo.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../auth/providers/auth_provider.dart';

/// Splash screen with animated logo and auth check.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.from});

  /// The page that was requested before the saved session was restored
  /// (e.g. after a browser reload). Only in-app paths are honoured.
  final String? from;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: AppAnimations.sharp),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: AppAnimations.sharp,
    ));

    _startSequence();
  }

  Future<void> _startSequence() async {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _textController.forward();
    });

    // Restore the saved session while the logo animates; checkAuth has its
    // own timeout and never throws, so there is no need for a safety timer
    // (the old 4-second one sent signed-in users to /login on slow networks).
    await Future.wait([
      ref.read(authStateProvider.notifier).checkAuth(),
      Future.delayed(const Duration(milliseconds: 500)),
    ]);
    if (!mounted) return;

    final from = widget.from;
    final target = from != null && from.startsWith('/') && !from.startsWith('//') && !from.startsWith('/splash')
        ? from
        : '/';
    // The router's redirect sends signed-out users to /login from here.
    context.go(target);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: const LCLogo(size: 52, showWordmark: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // App name
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    Text(
                      'mitaLeet',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
