import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'trend-head'} est pleinement visible
Future<void> lelementEstPleinementVisible(
  WidgetTester tester,
  String element,
) async {
  Fidelity.one(element);
  expect(
    Fidelity.opacity(element),
    greaterThanOrEqualTo(0.99),
    reason: "l'élément « $element » devrait être pleinement visible",
  );
}
