import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: la largeur de l'élément {'kpi-gauge-fill'} fait {43} % de celle de l'élément {'kpi-gauge'} à {2} points près
Future<void> laLargeurDeLelementFaitDeCelleDeLelementAPointsPres(
  WidgetTester tester,
  String element,
  num percent,
  String reference,
  num tolerance,
) async {
  final double actual =
      tester.getSize(Fidelity.one(element)).width /
      tester.getSize(Fidelity.one(reference)).width *
      100;
  Fidelity.expectNear(
    actual,
    percent,
    tolerance,
    what: "largeur de « $element » en % de « $reference »",
  );
}
