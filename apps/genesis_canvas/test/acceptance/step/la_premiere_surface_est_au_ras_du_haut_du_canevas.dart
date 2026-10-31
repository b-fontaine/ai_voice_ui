import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: la première surface est au ras du haut du canevas
///
/// La cellule de `kpi` (première de la grille) commence en haut à gauche du
/// canevas : aucune bande vide au-dessus du contenu.
Future<void> laPremiereSurfaceEstAuRasDuHautDuCanevas(
  WidgetTester tester,
) async {
  final board = DesignHarness.rectOf(tester, AcceptanceKeys.canvasBoard);
  final first = DesignHarness.rectOf(tester, AcceptanceKeys.surface('kpi'));
  expect(
    first.topLeft,
    board.topLeft,
    reason:
        'la première surface (${first.topLeft}) doit être au ras du coin du '
        'canevas (${board.topLeft})',
  );
}
