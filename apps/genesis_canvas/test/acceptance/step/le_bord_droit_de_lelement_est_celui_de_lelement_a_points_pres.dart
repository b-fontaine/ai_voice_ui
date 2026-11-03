import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le bord droit de l'élément {'trend-breach'} est celui de l'élément {'trend-plot'} à {2} points près
Future<void> leBordDroitDeLelementEstCeluiDeLelementAPointsPres(
  WidgetTester tester,
  String element,
  String reference,
  num tolerance,
) async {
  Fidelity.expectNear(
    Fidelity.rect(tester, element).right,
    Fidelity.rect(tester, reference).right,
    tolerance,
    what: "bord droit de « $element » et de « $reference »",
  );
}
