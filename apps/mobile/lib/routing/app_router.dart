import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/gamification/presentation/screens/leaderboard_screen.dart';
import '../features/activity/presentation/screens/activity_screen.dart';
import '../features/leetcode/presentation/screens/coding_activity_screen.dart';
import '../features/circles/presentation/screens/circles_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../shared/widgets/lc_bottom_nav.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that fires when auth state changes, triggering
/// GoRouter redirect re-evaluation without recreating the router.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// Application router with auth-guarded navigation.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isNewUser = authState.isNewUser;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Allow splash to show always initially
      if (isSplash) return null;

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return isNewUser ? '/onboarding' : '/';
      if (isLoggedIn && isNewUser && !isOnboarding) return '/onboarding';

      return null;
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Login ──────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Onboarding (new users) ─────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Authenticated shell with bottom nav (5 tabs) ──────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return LCScaffoldWithNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: RouteNames.home,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const HomeScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/leaderboard',
            name: RouteNames.leaderboard,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const LeaderboardScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/activity',
            name: RouteNames.activity,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ActivityScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/coding',
            name: RouteNames.coding,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const CodingActivityScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ProfileScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),

      // ── Squad — accessible via push from HomeScreen ────────────────
      GoRoute(
        path: '/squad',
        name: RouteNames.squad,
        builder: (context, state) => const CirclesScreen(),
      ),
    ],
  );
});

/// Smooth fade transition for tab switches.
Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
    child: child,
  );
}
