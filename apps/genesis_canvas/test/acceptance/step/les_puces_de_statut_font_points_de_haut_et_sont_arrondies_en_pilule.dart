import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Usage: les puces de statut font {26} points de haut et sont arrondies en pilule
Future<void> lesPucesDeStatutFontPointsDeHautEtSontArrondiesEnPilule(
  WidgetTester tester,
  num height,
) async {
  final Finder chips = find.byType(DsStatusChip);
  expect(chips, findsWidgets, reason: 'aucune puce de statut affichée');
  final Set<Element> verdict = Fidelity.present('checklist-verdict')
      ? find
            .descendant(
              of: Fidelity.key('checklist-verdict'),
              matching: find.byType(DsStatusChip),
              matchRoot: true,
            )
            .evaluate()
            .toSet()
      : <Element>{};
  var counted = 0;
  for (var i = 0; i < chips.evaluate().length; i++) {
    final Finder chip = chips.at(i);
    if (verdict.contains(chip.evaluate().single)) continue;
    counted++;
    final String label = tester.widget<DsStatusChip>(chip).label;
    Fidelity.expectNear(
      tester.getSize(chip).height,
      height,
      0.5,
      what: "hauteur de la puce « $label »",
    );
    expect(
      Fidelity.cornerRadiusOf(chip),
      greaterThanOrEqualTo(height / 2),
      reason: "la puce « $label » doit être une pilule",
    );
  }
  expect(counted, greaterThan(0), reason: 'aucune puce hors verdict');
}
