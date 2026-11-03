import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: les éléments {'checklist-head-2'} et {'checklist-cell-0-2'} sont alignés à gauche
Future<void> lesElementsEtSontAlignesAGauche(
  WidgetTester tester,
  String first,
  String second,
) async {
  Fidelity.expectNear(
    Fidelity.rect(tester, first).left,
    Fidelity.rect(tester, second).left,
    0.5,
    what: "bord gauche de « $first » et de « $second »",
  );
}
