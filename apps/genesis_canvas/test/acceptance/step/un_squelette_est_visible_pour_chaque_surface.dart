import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: un squelette est visible pour chaque surface
///
/// Avant toute donnée (NFR-02, RG-02) : seul `createSurface` a été émis.
Future<void> unSqueletteEstVisiblePourChaqueSurface(WidgetTester tester) async {
  for (final id in AcceptanceKeys.act1Surfaces) {
    await SessionHarness.waitFor(
      tester,
      find.descendant(
        of: find.byKey(AcceptanceKeys.surface(id)),
        matching: find.byKey(AcceptanceKeys.skeleton(id)),
      ),
      'un squelette (skeleton-$id) doit être visible pour la surface $id',
    );
  }
  expect(find.textContaining('99,57'), findsNothing);
}
