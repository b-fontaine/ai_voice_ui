import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/app.dart';

/// État partagé entre les étapes d'un scénario de l'outillage de boucle.
///
/// La sortie du processus est une frontière plateforme : l'app reçoit une
/// fonction de sortie qui enregistre le code au lieu de fermer le test.
class Harness {
  Harness._();

  static final List<int> exitCodes = <int>[];
  static File? snapshotFile;

  static void reset() {
    exitCodes.clear();
    snapshotFile = null;
  }

  /// Lance l'app réelle avec la configuration donnée, puis laisse un cadre.
  static Future<void> launch(
    WidgetTester tester, {
    String? scenario,
    String? snapshotPath,
  }) async {
    reset();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GenesisCanvasApp(
        config: GenesisConfig(scenario: scenario, snapshotPath: snapshotPath),
        exitHandler: exitCodes.add,
        // Frontière « temps » : le rejeu enchaîne ses douze messages sans
        // attente réelle (le rythme de l'asset est celui d'une démonstration ;
        // `pumpAndSettle` s'arrêterait entre deux messages espacés de 500 ms).
        replayDelay: (_) async {},
      ),
    );
    await tester.pump();
  }
}
