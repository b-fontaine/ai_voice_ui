import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;

/// Usage: une surface affiche le texte {'Sessions sans crash'}
///
/// Migration A8b (catalogue `genesis`) : la surface est la cellule
/// `surface-kpi` du contrat ; le texte (libellé du KPI) est rendu PAR le moteur
/// genui, donc sous le `Surface` de cette cellule.
Future<void> uneSurfaceAfficheLeTexte(WidgetTester tester, String text) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget, reason: 'une surface attendue');
  expect(
    find.descendant(
      of: find.descendant(of: find.byKey(kpi), matching: find.byType(Surface)),
      matching: find.text(text),
    ),
    findsOneWidget,
    reason: 'le moteur genui doit rendre « $text » dans la cellule surface-kpi',
  );
}
