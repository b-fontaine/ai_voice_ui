import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: la ligne de comparaison de la surface {'kpi'} a disparu
Future<void> laLigneDeComparaisonDeLaSurfaceADisparu(
  WidgetTester tester,
  String surface,
) async {
  expect(
    find.byKey(AcceptanceKeys.surface(surface)),
    findsOneWidget,
    reason: 'la surface $surface doit rester affichée',
  );
  expect(
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface(surface)),
      matching: find.byKey(AcceptanceKeys.comparison(surface)),
    ),
    findsNothing,
    reason: 'la ligne de comparaison de $surface est encore affichée',
  );
}
