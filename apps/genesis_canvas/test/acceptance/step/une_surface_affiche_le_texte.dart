import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: une surface affiche le texte {'Sessions sans crash'}
///
/// Migration A8b (catalogue `genesis`) : la surface est la cellule
/// `surface-kpi` du contrat, qui contient ce texte (libellé du KPI).
Future<void> uneSurfaceAfficheLeTexte(WidgetTester tester, String text) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget, reason: 'une surface attendue');
  expect(
    find.ancestor(of: find.text(text), matching: find.byKey(kpi)),
    findsOneWidget,
    reason: 'la cellule surface-kpi doit contenir « $text »',
  );
}
