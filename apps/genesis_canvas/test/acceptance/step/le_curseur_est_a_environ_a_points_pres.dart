import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le curseur est à environ {0} % à {5} points près
Future<void> leCurseurEstAEnvironAPointsPres(
  WidgetTester tester,
  num percent,
  num tolerance,
) async {
  expect(
    Acte4Harness.position(tester),
    closeTo(percent, tolerance),
    reason: 'position du curseur (en % de sa course)',
  );
}
