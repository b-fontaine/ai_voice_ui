import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';
import '../support/replay_bar_harness.dart';

/// Usage: les commandes hors du panneau restent atteignables
///
/// Les clics hors du rectangle du panneau le traversent : la surface `kpi`, les
/// boutons de la barre du haut et un bouton d'action de gauche reçoivent le clic.
Future<void> lesCommandesHorsDuPanneauRestentAtteignables(
  WidgetTester tester,
) async {
  final keys = <Key>[
    AcceptanceKeys.surface('kpi'),
    AcceptanceKeys.resetButton,
    const Key('mic-button'),
    AcceptanceKeys.actionButton('block_release'),
  ];
  for (final key in keys) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'le widget $key est introuvable');
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason:
          'le clic sur $key ne traverse pas le panneau : $key est recouvert',
    );
  }
  // `reset-button` et `mic-button` sont hors du Stack du panneau : on mesure
  // aussi un point du canevas au ras du bord gauche du panneau.
  final panel = DesignHarness.rectOf(tester, AcceptanceKeys.protocolPanel);
  ReplayBarHarness.expectHit(
    tester,
    AcceptanceKeys.canvasBoard,
    panel.centerLeft - const Offset(4, 0),
  );
}
