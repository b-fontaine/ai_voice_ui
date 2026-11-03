import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'replay-track-knob'} fait {14} points de large
Future<void> lelementFaitPointsDeLarge(
  WidgetTester tester,
  String element,
  num width,
) async {
  Fidelity.expectNear(
    tester.getSize(Fidelity.one(element)).width,
    width,
    0.5,
    what: "largeur de « $element »",
  );
}
