import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_core/shared_core.dart';

/// Rejoue un scénario embarqué : lit l'asset `assets/replays/<scénario>.jsonl` et
/// expose chaque message A2UI v0.9 dans un flux, dans l'ordre, avec sa ligne
/// brute (`raw`, que le validateur contrôle) et son message décodé.
///
/// Le paquet d'assets et l'attente sont injectés (frontières remplaçables).
class ScenarioPlayer {
  ScenarioPlayer({required this.bundle, this.delay});

  final AssetBundle bundle;
  final ReplayDelay? delay;

  /// Flux des messages (bruts et décodés) de [scenario], paresseux : la lecture démarre à
  /// l'abonnement et s'arrête à l'annulation. Les erreurs de lecture
  /// (asset absent, ligne invalide) sont des erreurs du flux.
  Stream<ReplayedMessage> entries(String scenario) async* {
    final text = await bundle.loadString(
      'assets/replays/$scenario.jsonl',
      cache: false,
    );
    final lines = Stream<String>.fromIterable(
      const LineSplitter().convert(text),
    );
    yield* A2uiReplaySource(lines: lines, delay: delay).entries();
  }
}
