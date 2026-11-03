import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'generation-frame-crashes'} est en train de s'estomper
Future<void> lelementEstEnTrainDeSestomper(
  WidgetTester tester,
  String element,
) async {
  Fidelity.one(element);
  final double opacity = Fidelity.opacity(element);
  expect(
    opacity,
    allOf(greaterThan(0.02), lessThan(0.98)),
    reason:
        "l'élément « $element » devrait être en plein fondu : opacité $opacity",
  );
}
