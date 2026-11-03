import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le bord gauche de l'élément {'trend-area'} est celui de l'élément {'trend-plot'} à {2} points près
Future<void> leBordGaucheDeLelementEstCeluiDeLelementAPointsPres(
  WidgetTester tester,
  String element,
  String reference,
  num tolerance,
) async {
  Fidelity.expectNear(
    Fidelity.rect(tester, element).left,
    Fidelity.rect(tester, reference).left,
    tolerance,
    what: "bord gauche de « $element » et de « $reference »",
  );
}
