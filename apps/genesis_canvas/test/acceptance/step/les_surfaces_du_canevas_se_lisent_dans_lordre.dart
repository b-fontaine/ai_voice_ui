import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: les surfaces du canevas se lisent dans l'ordre {'kpi, trend, reviews, checklist, crashes'}
///
/// Ordre de lecture : de haut en bas puis de gauche à droite, sur les cellules
/// `surface-*` de la grille (le bandeau d'actions n'en fait pas partie).
Future<void> lesSurfacesDuCanevasSeLisentDansLordre(
  WidgetTester tester,
  String order,
) async {
  final expected = order.split(',').map((id) => id.trim()).toList();
  final cells = <(String, double, double)>[];
  for (final id in expected) {
    final cell = find.byKey(AcceptanceKeys.surface(id));
    expect(cell, findsOneWidget, reason: 'la surface $id doit être affichée');
    final origin = tester.getTopLeft(cell);
    cells.add((id, origin.dy.roundToDouble(), origin.dx.roundToDouble()));
  }
  cells.sort(
    (a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$3.compareTo(b.$3),
  );
  expect(
    cells.map((c) => c.$1).toList(),
    expected,
    reason: 'ordre de lecture de la grille',
  );
}
