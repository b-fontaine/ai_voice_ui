import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'replay-speed-1-visual'} fait {26} points de haut
Future<void> lelementFaitPointsDeHaut(
  WidgetTester tester,
  String element,
  num height,
) async {
  Fidelity.expectNear(
    tester.getSize(Fidelity.one(element)).height,
    height,
    0.5,
    what: "hauteur de « $element »",
  );
}
