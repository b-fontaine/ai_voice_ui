import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la valeur liée au modèle de données est affichée
///
/// Valeur du jeu figé (product/functional/dataset.md) : sessions sans crash
/// global 7 j, version 3.4 = 99,57 %.
///
/// Migration A8b (catalogue `genesis`) : la valeur est portée par la cellule
/// `surface-kpi` (liée à `/kpi`), rendue PAR le moteur A2UI (sous
/// `A2uiSurface`).
Future<void> laValeurLieeAuModeleDeDonneesEstAffichee(
  WidgetTester tester,
) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget);
  final value = find.descendant(
    of: find.descendant(
      of: find.byKey(kpi),
      matching: find.byType(A2uiSurface),
    ),
    matching: find.textContaining('99,57'),
  );
  // Le chiffre descend de 100 vers sa valeur pendant 1,4 s (compteur, pdr-0088
  // F3 et F13) : la valeur liée n'est affichée qu'à la fin.
  await SessionHarness.waitFor(
    tester,
    value,
    'la valeur « 99,57 % » liée au modèle doit être affichée',
  );
  expect(value, findsOneWidget);
}
