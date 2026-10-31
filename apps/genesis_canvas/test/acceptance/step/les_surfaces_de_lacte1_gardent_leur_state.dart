import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/acte2_harness.dart';
import '../support/keys.dart';

/// Usage: les surfaces de l'acte 1 gardent leur State
///
/// Même `State` du moteur de rendu (`Surface`) que celui relevé quand le
/// tableau de l'acte 1 était complet : rien n'a été recréé ni remonté quand la
/// grille a changé de forme (A7). Les positions peuvent changer.
Future<void> lesSurfacesDeLacte1GardentLeurState(WidgetTester tester) async {
  expect(
    Acte2Harness.surfaceStates,
    isNotEmpty,
    reason: "le tableau de l'acte 1 n'a pas été relevé",
  );
  for (final id in AcceptanceKeys.act1Surfaces) {
    expect(
      tester.state(Acte2Harness.engineOf(id)),
      same(Acte2Harness.surfaceStates[id]),
      reason: 'la surface $id a été recréée (autre State de Surface)',
    );
    expect(
      find.descendant(
        of: find.byKey(AcceptanceKeys.surface(id)),
        matching: find.byType(DsSkeleton),
      ),
      findsNothing,
      reason: 'un squelette est réapparu sur la surface $id',
    );
  }
}
