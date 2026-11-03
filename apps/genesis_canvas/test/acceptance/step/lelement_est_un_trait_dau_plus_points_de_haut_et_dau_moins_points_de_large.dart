import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/painting.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'trend-swatch-Android 3.4'} est un trait d'au plus {4} points de haut et d'au moins {12} points de large
Future<void> lelementEstUnTraitDauPlusPointsDeHautEtDauMoinsPointsDeLarge(
  WidgetTester tester,
  String element,
  num maxHeight,
  num minWidth,
) async {
  final Size size = tester.getSize(Fidelity.one(element));
  expect(
    size.height,
    lessThanOrEqualTo(maxHeight),
    reason:
        "« $element » doit être un trait (légende à traits), pas une pastille : $size",
  );
  expect(
    size.width,
    greaterThanOrEqualTo(minWidth),
    reason:
        "« $element » doit être un trait d'au moins $minWidth points : $size",
  );
}
