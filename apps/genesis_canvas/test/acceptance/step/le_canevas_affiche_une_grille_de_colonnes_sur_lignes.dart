import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: le canevas affiche une grille de {3} colonnes sur {2} lignes
///
/// Lue sur les positions des cellules `surface-*` (hors bandeau d'actions).
Future<void> leCanevasAfficheUneGrilleDeColonnesSurLignes(
  WidgetTester tester,
  num columns,
  num rows,
) async {
  final tops = <double>{};
  final lefts = <double>{};
  for (final id in const <String>[
    'kpi',
    'trend',
    'reviews',
    'checklist',
    'crashes',
  ]) {
    final cell = find.byKey(AcceptanceKeys.surface(id));
    if (cell.evaluate().isEmpty) continue;
    final origin = tester.getTopLeft(cell);
    tops.add(origin.dy.roundToDouble());
    lefts.add(origin.dx.roundToDouble());
  }
  expect(lefts.length, columns, reason: 'colonnes de la grille : $lefts');
  expect(tops.length, rows, reason: 'lignes de la grille : $tops');
}
