import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

/// Usage: une surface affiche le texte {'Sessions sans crash'}
///
/// Migration A8b (catalogue `genesis`) : la surface est la cellule
/// `surface-kpi` du contrat ; le texte (libellé du KPI) est rendu PAR le moteur
/// A2UI, donc sous l'`A2uiSurface` de cette cellule.
Future<void> uneSurfaceAfficheLeTexte(WidgetTester tester, String text) async {
  const kpi = Key('surface-kpi');
  expect(find.byKey(kpi), findsOneWidget, reason: 'une surface attendue');
  expect(
    find.descendant(
      of: find.descendant(
        of: find.byKey(kpi),
        matching: find.byType(A2uiSurface),
      ),
      // L'étiquette du KPI s'affiche en capitales (pdr-0088 F3 et F6).
      matching: findTextIgnoringCase(text),
    ),
    findsOneWidget,
    reason: 'le moteur A2UI doit rendre « $text » dans la cellule surface-kpi',
  );
}
