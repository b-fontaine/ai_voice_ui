import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'kpi-value'} est {'99,43 %'}
Future<void> leTexteDeLelementEst(
  WidgetTester tester,
  String element,
  String expected,
) async {
  final String actual = Fidelity.textOfKey(element);
  expect(
    Fidelity.sameText(actual, expected),
    isTrue,
    reason: "texte de « $element » : « $actual », attendu « $expected »",
  );
}
