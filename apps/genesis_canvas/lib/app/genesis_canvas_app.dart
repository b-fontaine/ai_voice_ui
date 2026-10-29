import 'dart:io' as io;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' show BasicCatalogItems, Catalog;
import 'package:shared_core/shared_core.dart'
    show ExitHandler, ReplayDelay, SnapshotService;

import '../pages/genesis_canvas/genesis_canvas.dart';
import 'config/genesis_config.dart';
import 'scenario/scenario_player.dart';

/// Racine de l'application : couche `app`, qui assemble la configuration, les
/// assets et la plateforme, puis les passe à la page par constructeur.
///
/// Fonction de sortie (`exit` de `dart:io`), destination des erreurs
/// (`stderr`), paquet d'assets (`rootBundle`) et attente du rejeu (réelle)
/// sont des frontières par défaut, remplaçables par les tests.
class GenesisCanvasApp extends StatelessWidget {
  const GenesisCanvasApp({
    super.key,
    this.config = const GenesisConfig(),
    this.exitHandler,
    this.errorSink,
    this.assetBundle,
    this.replayDelay,
  });

  final GenesisConfig config;
  final ExitHandler? exitHandler;
  final StringSink? errorSink;
  final AssetBundle? assetBundle;

  /// Attente entre deux messages du rejeu ; `null` : délai réel.
  final ReplayDelay? replayDelay;

  @override
  Widget build(BuildContext context) {
    final sink = errorSink ?? io.stderr;
    final scenario = config.scenario;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GenesisCanvasPage(
        catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
        replay: scenario == null
            ? null
            : ScenarioPlayer(
                bundle: assetBundle ?? rootBundle,
                delay: replayDelay,
              ).messages(scenario),
        snapshotFactory: (exitHandler) => SnapshotService(
          path: config.snapshotPath,
          exitHandler: exitHandler,
          errorSink: sink,
        ),
        exitHandler: exitHandler ?? io.exit,
        errorSink: sink,
      ),
    );
  }
}
