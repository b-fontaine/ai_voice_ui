import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le texte de l'élément {'protocol-entry-0-no'} est un numéro de message de la forme {'#nn'}
Future<void> leTexteDeLelementEstUnNumeroDeMessageDeLaForme(
  WidgetTester tester,
  String element,
  String form,
) async {
  expect(form, '#nn', reason: "seule la forme « #nn » est connue");
  final String actual = Fidelity.textOfKey(element).trim();
  expect(
    RegExp(r'^#\d{2,}$').hasMatch(actual),
    isTrue,
    reason: "« $element » : « $actual », attendu un numéro « #nn »",
  );
}
