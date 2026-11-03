import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: la fraction visible de l'élément {'trend-reveal'} est de {100} %
Future<void> laFractionVisibleDeLelementEstDe(
  WidgetTester tester,
  String element,
  num percent,
) async {
  Fidelity.expectNear(
    Fidelity.visibleFraction(element) * 100,
    percent,
    0.5,
    what: "fraction visible de « $element » en %",
  );
}
