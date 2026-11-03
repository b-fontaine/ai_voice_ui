import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: la fraction visible de l'élément {'trend-reveal'} est comprise entre {5} et {95} %
Future<void> laFractionVisibleDeLelementEstCompriseEntreEt(
  WidgetTester tester,
  String element,
  num min,
  num max,
) async {
  final double fraction = Fidelity.visibleFraction(element) * 100;
  expect(
    fraction,
    allOf(greaterThanOrEqualTo(min), lessThanOrEqualTo(max)),
    reason:
        "fraction visible de « $element » : $fraction %, attendue entre $min et $max %",
  );
}
