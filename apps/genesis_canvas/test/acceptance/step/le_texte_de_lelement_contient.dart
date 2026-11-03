import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'checklist-head-1'} contient {'seuil'}
Future<void> leTexteDeLelementContient(
  WidgetTester tester,
  String element,
  String expected,
) async {
  final String actual = Fidelity.textOfKey(element);
  expect(
    Fidelity.containsText(actual, expected),
    isTrue,
    reason:
        "texte de « $element » : « $actual », devrait contenir « $expected »",
  );
}
