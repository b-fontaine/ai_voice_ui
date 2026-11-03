import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: le nombre affiché par l'élément {'kpi-value'} est compris entre {99.58} et {100}
Future<void> leNombreAfficheParLelementEstComprisEntreEt(
  WidgetTester tester,
  String element,
  num min,
  num max,
) async {
  final double value = Fidelity.numberOf(element);
  expect(
    value,
    allOf(greaterThanOrEqualTo(min), lessThanOrEqualTo(max)),
    reason:
        "nombre affiché par « $element » : $value, attendu entre $min et $max (compteur de 100 vers la valeur)",
  );
}
