import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/gamification/presentation/screens/leaderboard_screen.dart';
import '../features/gamification/presentation/screens/progression_screen.dart';
import '../features/activity/presentation/screens/activity_screen.dart';
import '../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../features/leetcode/presentation/screens/coding_activity_screen.dart';
import '../features/leetcode/presentation/screens/leetcode_link_screen.dart';
import '../features/circles/presentation/screens/circles_screen.dart';
import '../features/circles/presentation/screens/squad_detail_route.dart';
import '../features/friends/presentation/screens/friend_list_screen.dart';
import '../features/friends/presentation/screens/friend_requests_screen.dart';
import '../features/friends/presentation/screens/friend_search_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/race/presentation/screens/race_lobby_screen.dart';
import '../features/race/presentation/screens/race_room_screen.dart';
import '../features/race/presentation/screens/race_results_screen.dart';
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
///
/// Every screen is a route. Detail pages are nested under the tab they
/// belong to, so they keep the bottom nav, get a back button, survive a page
/// reload, and are cleared when another tab is selected. Never open a screen
/// with Navigator.push: the router doesn't know about such pages, so they
/// stay on top when the user switches tabs.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == '/splash') return null;

      // On the web a reload starts at the current URL, not /splash. Restore
      // the saved session first, then come back to the same page.
      if (!ref.read(authStateProvider.notifier).sessionRestored) {
        return Uri(path: '/splash', queryParameters: {'from': state.uri.toString()}).toString();
      }

      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isLogin = location == '/login';
      final isOnboarding = location == '/onboarding';

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return authState.isNewUser ? '/onboarding' : '/';
      if (isLoggedIn && authState.isNewUser && !isOnboarding) return '/onboarding';

      return null;
    },
    routes: [
      // ── Splash (restores the saved session) ────────────────────────
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => SplashScreen(from: state.uri.queryParameters['from']),
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
            pageBuilder: (context, state) => _tabPage(state, const HomeScreen()),
            routes: [
              GoRoute(
                path: 'squads',
                name: RouteNames.squad,
                builder: (context, state) => const CirclesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => SquadDetailRoute(groupId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'races',
                builder: (context, state) => const RaceLobbyScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RaceRoomScreen(
                      roomId: state.pathParameters['id']!,
                      isCreator: state.uri.queryParameters['host'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: ':id/results',
                    // Results are handed over from the race room; after a
                    // reload they are gone, so fall back to the room.
                    redirect: (context, state) => state.extra is List
                        ? null
                        : '/races/${state.pathParameters['id']}',
                    builder: (context, state) =>
                        RaceResultsScreen(results: (state.extra! as List).cast<Map<String, dynamic>>()),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/leaderboard',
            name: RouteNames.leaderboard,
            pageBuilder: (context, state) => _tabPage(state, const LeaderboardScreen()),
          ),
          GoRoute(
            path: '/activity',
            name: RouteNames.activity,
            pageBuilder: (context, state) => _tabPage(state, const ActivityScreen()),
          ),
          GoRoute(
            path: '/coding',
            name: RouteNames.coding,
            pageBuilder: (context, state) => _tabPage(state, const CodingActivityScreen()),
            routes: [
              GoRoute(
                path: 'leetcode',
                builder: (context, state) =>
                    LeetCodeLinkScreen(initialUsername: state.uri.queryParameters['username']),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const AnalyticsDashboardScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            pageBuilder: (context, state) => _tabPage(state, const ProfileScreen()),
            routes: [
              GoRoute(
                path: 'friends',
                builder: (context, state) => const FriendListScreen(),
                routes: [
                  GoRoute(path: 'requests', builder: (context, state) => const FriendRequestsScreen()),
                  GoRoute(path: 'search', builder: (context, state) => const FriendSearchScreen()),
                ],
              ),
              GoRoute(
                path: 'progression',
                builder: (context, state) => const ProgressionScreen(),
              ),
            ],
          ),
        ],
      ),

      // Old link to the squad list.
      GoRoute(path: '/squad', redirect: (context, state) => '/squads'),
    ],
  );
});

/// Tabs cross-fade instead of sliding, since they are siblings.
CustomTransitionPage<void> _tabPage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: _fadeTransition,
  );
}

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
