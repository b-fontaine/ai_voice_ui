import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: la position du curseur a avancé de {33} points à {5} points près
Future<void> laPositionDuCurseurAAvanceDePointsAPointsPres(
  WidgetTester tester,
  num points,
  num tolerance,
) async {
  expect(
    Acte4Harness.position(tester) - Acte4Harness.notedPosition!,
    closeTo(points, tolerance),
    reason: 'avance du curseur depuis la position notée',
  );
}
