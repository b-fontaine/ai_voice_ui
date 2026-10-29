import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: l'orbe est visible
Future<void> lorbeEstVisible(WidgetTester tester) async {
  expect(
    find.byKey(const Key('voice-orb')),
    findsOneWidget,
    reason: "l'orbe vocal (voice-orb) doit être visible",
  );
}
