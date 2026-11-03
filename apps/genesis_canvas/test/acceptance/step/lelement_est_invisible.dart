import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'trend-head'} est invisible
Future<void> lelementEstInvisible(WidgetTester tester, String element) async {
  Fidelity.one(element);
  expect(
    Fidelity.opacity(element),
    lessThan(0.05),
    reason: "l'élément « $element » devrait être invisible à ce stade",
  );
}
