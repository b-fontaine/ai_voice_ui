import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'checklist-head-2'} ne contient pas {'3.4'}
Future<void> leTexteDeLelementNeContientPas(
  WidgetTester tester,
  String element,
  String forbidden,
) async {
  final String actual = Fidelity.textOfKey(element);
  expect(
    Fidelity.containsText(actual, forbidden),
    isFalse,
    reason:
        "texte de « $element » : « $actual », ne devrait pas contenir « $forbidden »",
  );
}
