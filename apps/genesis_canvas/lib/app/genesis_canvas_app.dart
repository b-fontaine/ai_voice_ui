import 'dart:async';
import 'dart:io' as io;

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:feature_canvas/feature_canvas.dart' show genesisCatalog;
import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:genui/genui.dart' show Catalog;
import 'package:get_it/get_it.dart';
import 'package:shared_core/shared_core.dart' show ExitHandler, ReplayDelay;

import '../pages/genesis_canvas/genesis_canvas.dart';
import '../pages/genesis_canvas/genesis_canvas_page_settings.dart';
import 'bootstrap/snapshot_service.dart';
import 'config/genesis_config.dart';
import 'di/injection.dart';
import 'scenario/scenario_player.dart';

/// Racine de l'application : couche `app`, qui assemble la configuration, les
/// assets et la plateforme, puis les passe à la page par constructeur.
///
/// Chaque instance crée son propre graphe `GetIt` (aucune variable globale,
/// aucun état résiduel d'un montage à l'autre) et le libère à sa fermeture,
/// une fois la page fermée.
///
/// Fonction de sortie (`exit` de `dart:io`), destination des erreurs
/// (`stderr`), paquet d'assets (`rootBundle`), attente du rejeu (réelle) et
/// fabrique de transport voix (WebRTC réel) sont des frontières par défaut,
/// remplaçables par les tests.
class GenesisCanvasApp extends StatefulWidget {
  const GenesisCanvasApp({
    super.key,
    this.config = const GenesisConfig(),
    this.exitHandler,
    this.errorSink,
    this.assetBundle,
    this.replayDelay,
    this.voiceTransportFactory,
  });

  final GenesisConfig config;
  final ExitHandler? exitHandler;
  final StringSink? errorSink;
  final AssetBundle? assetBundle;

  /// Attente entre deux messages du rejeu ; `null` : délai réel.
  final ReplayDelay? replayDelay;

  /// Un transport voix NEUF par démarrage de session ; `null` : WebRTC réel.
  final VoiceTransport Function()? voiceTransportFactory;

  @override
  State<GenesisCanvasApp> createState() => _GenesisCanvasAppState();
}

class _GenesisCanvasAppState extends State<GenesisCanvasApp> {
  late final GetIt _getIt = GetIt.asNewInstance();
  late final Stream<A2uiMessage>? _replay;
  late final StringSink _errorSink = widget.errorSink ?? io.stderr;
  Future<void>? _pageClosing;

  @override
  void initState() {
    super.initState();
    configureDependencies(
      _getIt,
      config: widget.config,
      errorSink: _errorSink,
      voiceTransportFactory: widget.voiceTransportFactory,
    );
    final scenario = widget.config.scenario;
    _replay = scenario == null
        ? null
        : ScenarioPlayer(
            bundle: widget.assetBundle ?? rootBundle,
            delay: widget.replayDelay,
          ).messages(scenario);
  }

  @override
  void dispose() {
    // La page (descendante) est déjà démontée et a lancé sa fermeture : le
    // graphe n'est libéré qu'après elle.
    final closing = _pageClosing ?? Future<void>.value();
    unawaited(closing.whenComplete(_getIt.reset));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sink = _errorSink;
    final config = widget.config;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      // `Material` transparent : fournit le style de texte du thème (sinon
      // repli rouge souligné) sans changer le fond de la page.
      home: Material(
        type: MaterialType.transparency,
        child: GenesisCanvasPage(
          getIt: _getIt,
          catalogs: <Catalog>[genesisCatalog(catalogId: config.catalogId)],
          catalogId: config.catalogId,
          replay: _replay,
          onClosing: (closing) => _pageClosing = closing,
          snapshotFactory: (exitHandler) => SnapshotService(
            path: widget.config.snapshotPath,
            exitHandler: exitHandler,
            errorSink: sink,
          ),
          exitHandler: widget.exitHandler ?? io.exit,
          errorSink: sink,
          settings: GenesisCanvasPageSettings(
            orbAttack: config.orbAttack,
            orbRelease: config.orbRelease,
            orbSilenceTimeout: config.orbSilenceTimeout,
            orbSpeakingThreshold: config.orbSpeakingThreshold,
            sessionCloseTimeout: config.sessionCloseTimeout,
            exitCloseTimeout: config.exitCloseTimeout,
          ),
        ),
      ),
    );
  }
}
