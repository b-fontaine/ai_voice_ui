import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

import 'package:flutter/painting.dart';

/// Usage: le bord gauche de l'élément {'trend-breach'} est à {50} % de la largeur de l'élément {'trend-plot'} à {2} points près
Future<void> leBordGaucheDeLelementEstADeLaLargeurDeLelementAPointsPres(
  WidgetTester tester,
  String element,
  num percent,
  String reference,
  num tolerance,
) async {
  final Rect target = Fidelity.rect(tester, reference);
  final double actual =
      (Fidelity.rect(tester, element).left - target.left) / target.width * 100;
  Fidelity.expectNear(
    actual,
    percent,
    tolerance,
    what: "bord gauche de « $element » en % de la largeur de « $reference »",
  );
}
