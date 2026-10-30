import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;

/// Usage: la valeur liée au modèle de données est affichée
///
/// Valeur du jeu figé (product/functional/dataset.md) : sessions sans crash
/// global 7 j, version 3.4 = 99,57 %.
///
/// Migration A8b (catalogue `genesis`) : la valeur est portée par la cellule
/// `surface-kpi` (liée à `/kpi`), rendue PAR le moteur genui (sous `Surface`).
Future<void> laValeurLieeAuModeleDeDonneesEstAffichee(
  WidgetTester tester,
) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget);
  expect(
    find.descendant(
      of: find.descendant(of: find.byKey(kpi), matching: find.byType(Surface)),
      matching: find.textContaining('99,57'),
    ),
    findsOneWidget,
  );
}
