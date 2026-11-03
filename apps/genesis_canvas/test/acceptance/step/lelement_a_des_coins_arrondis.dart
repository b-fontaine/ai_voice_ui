import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'checklist-row-0'} a des coins arrondis
Future<void> lelementADesCoinsArrondis(
  WidgetTester tester,
  String element,
) async {
  expect(
    Fidelity.cornerRadiusOf(Fidelity.one(element)),
    greaterThan(0),
    reason: "« $element » doit avoir des coins arrondis",
  );
}
