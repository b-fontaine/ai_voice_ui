import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/acte2_harness.dart';
import '../support/keys.dart';

/// Usage: la ligne de comparaison de la surface {'kpi'} n'a pas de couleur de statut
///
/// La couleur d'un statut vient de son code `ok|risk|blocking` (RG-09), jamais
/// du texte d'un écart : la ligne, même négative (« −0,28 pt »), est neutre.
Future<void> laLigneDeComparaisonDeLaSurfaceNaPasDeCouleurDeStatut(
  WidgetTester tester,
  String surface,
) async {
  final line = Acte2Harness.comparisonLine(tester, surface);
  expect(
    line,
    isNotNull,
    reason: 'ligne de comparaison absente (clé comparison-$surface)',
  );
  final context = tester.element(
    find.descendant(
      of: find.byKey(AcceptanceKeys.surface(surface)),
      matching: find.byKey(AcceptanceKeys.comparison(surface)),
    ),
  );
  final theme = SceneTheme.of(context);
  final color = line!.style?.color ?? DefaultTextStyle.of(context).style.color;
  expect(
    <Color?>[
      theme.okForeground,
      theme.riskForeground,
      theme.blockingForeground,
      theme.okBackground,
      theme.riskBackground,
      theme.blockingBackground,
    ],
    isNot(contains(color)),
    reason: 'la ligne de comparaison porte une couleur de statut',
  );
}
