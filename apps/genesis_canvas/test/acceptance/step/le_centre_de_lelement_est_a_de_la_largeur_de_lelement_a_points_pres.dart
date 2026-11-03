import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

import 'package:flutter/painting.dart';

/// Usage: le centre de l'élément {'kpi-gauge-ref'} est à {71} % de la largeur de l'élément {'kpi-gauge'} à {2} points près
Future<void> leCentreDeLelementEstADeLaLargeurDeLelementAPointsPres(
  WidgetTester tester,
  String element,
  num percent,
  String reference,
  num tolerance,
) async {
  final Rect target = Fidelity.rect(tester, reference);
  final double actual =
      (Fidelity.rect(tester, element).center.dx - target.left) /
      target.width *
      100;
  Fidelity.expectNear(
    actual,
    percent,
    tolerance,
    what: "centre de « $element » en % de la largeur de « $reference »",
  );
}
