import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/replay_bar_harness.dart';

/// Usage: chaque commande de la barre de rejeu est atteignable
///
/// Lecture, Recommencer, glissière, « Direct » et les cinq vitesses : le clic
/// les atteint et leur rectangle ne recoupe pas celui du panneau.
Future<void> chaqueCommandeDeLaBarreDeRejeuEstAtteignable(
  WidgetTester tester,
) async {
  for (final key in ReplayBarHarness.controls) {
    ReplayBarHarness.expectReachable(tester, key);
  }
  final speedWidgets = find.byWidgetPredicate((widget) {
    final key = widget.key;
    // Hors visuels `replay-speed-<v>-visual` (019) : une cible par vitesse.
    return key is ValueKey<String> &&
        RegExp(r'^replay-speed-[\d.]+$').hasMatch(key.value);
  });
  expect(
    speedWidgets.evaluate().length,
    ReplayBarHarness.speeds.length,
    reason: 'la barre doit proposer exactement les vitesses attendues',
  );
}
