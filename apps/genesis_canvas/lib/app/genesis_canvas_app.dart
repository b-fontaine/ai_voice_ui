import 'dart:io' as io;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart';

import '../pages/genesis_canvas/genesis_canvas.dart';
import 'config/genesis_config.dart';

/// Racine de l'application.
///
/// Les paramètres fixent le contrat de lancement : scénario de rejeu, chemin
/// de la capture PNG, fonction de sortie (frontière plateforme, `exit` de
/// `dart:io` par défaut) et paquet d'assets (`rootBundle` par défaut), tous
/// remplaçables par les tests.
class GenesisCanvasApp extends StatelessWidget {
  const GenesisCanvasApp({
    super.key,
    this.scenario,
    this.snapshotPath,
    this.exitHandler,
    this.assetBundle,
  });

  /// Construit l'app depuis la configuration lue dans `main()`.
  GenesisCanvasApp.fromConfig(GenesisConfig config, {Key? key})
    : this(
        key: key,
        scenario: config.scenario,
        snapshotPath: config.snapshotPath,
      );

  final String? scenario;
  final String? snapshotPath;
  final void Function(int code)? exitHandler;
  final AssetBundle? assetBundle;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: GenesisCanvasPage(
      config: GenesisConfig(scenario: scenario, snapshotPath: snapshotPath),
      assetBundle: assetBundle ?? rootBundle,
      exitHandler: exitHandler ?? io.exit,
      errorSink: io.stderr,
    ),
  );
}
