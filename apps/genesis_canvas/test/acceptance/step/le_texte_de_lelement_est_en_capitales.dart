import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'checklist-head-0'} est en capitales
Future<void> leTexteDeLelementEstEnCapitales(
  WidgetTester tester,
  String element,
) async {
  final String actual = Fidelity.textOfKey(element).trim();
  expect(actual, isNotEmpty, reason: "« $element » n'affiche aucun texte");
  expect(
    actual,
    actual.toUpperCase(),
    reason:
        "« $element » doit être rendu en capitales (pdr-0088 F6) : « $actual »",
  );
}
