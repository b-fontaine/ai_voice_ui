import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'action-block_release-visual'} a un rayon de {10} points
Future<void> lelementAUnRayonDePoints(
  WidgetTester tester,
  String element,
  num radius,
) async {
  Fidelity.expectNear(
    Fidelity.cornerRadiusOf(Fidelity.one(element)),
    radius,
    0.5,
    what: "rayon des coins de « $element »",
  );
}
