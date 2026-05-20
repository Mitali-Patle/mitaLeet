// Basic Flutter widget smoke test for mitaLeet.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mitaleet/app.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: mitaLeetApp()),
    );

    // If we reach here without error, the app renders successfully.
    expect(find.byType(mitaLeetApp), findsOneWidget);
  });
}
