import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/acte2_harness.dart';
import '../support/keys.dart';

/// Usage: les surfaces existantes restent à leur place
///
/// Mêmes cellules, mêmes positions, même `State` du moteur de rendu
/// (`Surface`) qu'avant la phrase : rien n'a été recréé ni remonté (D1) ; aucun
/// squelette n'est repeint.
Future<void> lesSurfacesExistantesRestentALeurPlace(WidgetTester tester) async {
  expect(
    Acte2Harness.surfaceStates,
    isNotEmpty,
    reason: "le tableau de l'acte 1 n'a pas été relevé",
  );
  for (final id in AcceptanceKeys.act1Surfaces) {
    expect(
      find.byKey(AcceptanceKeys.surface(id)),
      findsOneWidget,
      reason: 'la surface $id doit être toujours affichée',
    );
    expect(
      tester.getTopLeft(find.byKey(AcceptanceKeys.surface(id))),
      Acte2Harness.surfacePositions[id],
      reason: 'la surface $id a changé de place',
    );
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
