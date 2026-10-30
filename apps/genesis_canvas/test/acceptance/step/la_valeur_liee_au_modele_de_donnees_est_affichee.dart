import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: la valeur liée au modèle de données est affichée
///
/// Valeur du jeu figé (product/functional/dataset.md) : sessions sans crash
/// global 7 j, version 3.4 = 99,57 %.
///
/// Migration A8b (catalogue `genesis`) : la valeur est portée par la cellule
/// `surface-kpi` (liée à `/kpi`).
Future<void> laValeurLieeAuModeleDeDonneesEstAffichee(
  WidgetTester tester,
) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget);
  expect(
    find.ancestor(of: find.textContaining('99,57'), matching: find.byKey(kpi)),
    findsOneWidget,
  );
}
