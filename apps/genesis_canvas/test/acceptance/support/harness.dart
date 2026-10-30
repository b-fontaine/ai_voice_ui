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
    if (scenario == null) {
      // Mode vivant : la page demande la remise à vide du backend au
      // démarrage (pdr-0064, D6). Le banc de test répond 400 à toute requête
      // HTTP : on laisse la réponse arriver (horloge réelle), puis on avance
      // l'horloge du test au-delà du délai pour qu'aucun minuteur du client ne
      // survive au test.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const GenesisConfig().canvasResetTimeout * 2);
    }
  }
}
