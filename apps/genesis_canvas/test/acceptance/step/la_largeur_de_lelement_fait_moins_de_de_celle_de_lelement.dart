import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: la largeur de l'élément {'reviews-split-pos'} fait moins de {50} % de celle de l'élément {'reviews-split'}
Future<void> laLargeurDeLelementFaitMoinsDeDeCelleDeLelement(
  WidgetTester tester,
  String element,
  num percent,
  String reference,
) async {
  final double actual =
      tester.getSize(Fidelity.one(element)).width /
      tester.getSize(Fidelity.one(reference)).width *
      100;
  expect(
    actual,
    lessThan(percent),
    reason:
        "largeur de « $element » en % de « $reference » : $actual, attendu moins de $percent (remplissage animé)",
  );
}
