// Basic Flutter widget smoke test for mitaLeet.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mitaleet/app.dart';
import 'package:mitaleet/features/auth/presentation/screens/login_screen.dart';

void main() {
  setUpAll(() {
    // Tests have no network; fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('signed-out launch shows splash, then the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: mitaLeetApp()));
    expect(find.byType(mitaLeetApp), findsOneWidget);

    // Let the splash sequence finish; with no stored session the router
    // must land on the login screen.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(LoginScreen), findsOneWidget);

    // Flush remaining timers (auth-check timeout, network timeouts).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
