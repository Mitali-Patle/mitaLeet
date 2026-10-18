// Basic Flutter widget smoke test for mitaLeet.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mitaleet/app.dart';
import 'package:mitaleet/core/constants/app_constants.dart';
import 'package:mitaleet/routing/app_router.dart';
import 'package:mitaleet/features/auth/presentation/screens/login_screen.dart';

void main() {
  setUpAll(() {
    // Tests have no network; fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    // No platform keystore in tests: start with an empty in-memory store
    // (no saved session).
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('signed-out launch shows splash, then the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: mitaLeetApp()));
    expect(find.byType(mitaLeetApp), findsOneWidget);

    // Let the splash sequence finish; with no stored session the router
    // must land on the login screen well before the 10 s restore timeout.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(LoginScreen), findsOneWidget);

    // Flush remaining timers (auth-check timeout, network timeouts).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a reload on a deep link keeps a saved session on that page', (WidgetTester tester) async {
    // A saved session. The test binding answers every HTTP request with 400,
    // i.e. "the server didn't confirm, but didn't reject the session either":
    // the user must stay signed in, on the page they reloaded.
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'saved-access',
      AppConstants.refreshTokenKey: 'saved-refresh',
      AppConstants.userIdKey: 'user-1',
    });
    // The browser hands the router the current URL on reload.
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/leaderboard';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const mitaLeetApp()));

    final router = container.read(appRouterProvider);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(router.routerDelegate.currentConfiguration.uri.path, '/leaderboard');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
