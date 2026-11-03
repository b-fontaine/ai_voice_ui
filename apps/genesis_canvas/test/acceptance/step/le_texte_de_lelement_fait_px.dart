import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'kpi-value'} fait {76} px
Future<void> leTexteDeLelementFaitPx(
  WidgetTester tester,
  String element,
  num size,
) async {
  Fidelity.expectNear(
    Fidelity.styleOf(tester, element).fontSize ?? 0,
    size,
    0.01,
    what: "taille du texte de « $element »",
  );
}
