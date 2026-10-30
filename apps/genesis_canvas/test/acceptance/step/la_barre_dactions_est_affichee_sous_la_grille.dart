import 'package:flutter_test/flutter_test.dart';

import '../support/acte3_harness.dart';
import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la Barre d'actions est affichée sous la grille
///
/// Bandeau hors de la grille 2 × 2 (pdr-0065, D7) : son bord haut n'est pas
/// au-dessus du bord bas des quatre surfaces, et il couvre la largeur de la
/// grille.
Future<void> laBarreDactionsEstAfficheeSousLaGrille(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    Acte3Harness.actionsCell(),
    "la cellule de la Barre d'actions (surface-actions) doit exister",
  );
  final bar = tester.getRect(Acte3Harness.actionsCell());
  var gridBottom = 0.0;
  var gridLeft = double.infinity;
  var gridRight = 0.0;
  for (final id in AcceptanceKeys.act1Surfaces) {
    final cell = tester.getRect(find.byKey(AcceptanceKeys.surface(id)));
    if (cell.bottom > gridBottom) gridBottom = cell.bottom;
    if (cell.left < gridLeft) gridLeft = cell.left;
    if (cell.right > gridRight) gridRight = cell.right;
  }
  expect(
    bar.top,
    greaterThanOrEqualTo(gridBottom),
    reason:
        'la Barre d\'actions ($bar) n\'est pas sous la grille '
        '(bas de la grille : $gridBottom)',
  );
  expect(
    bar.left <= gridLeft && bar.right >= gridRight,
    isTrue,
    reason: 'le bandeau ($bar) ne couvre pas la largeur de la grille',
  );
}
