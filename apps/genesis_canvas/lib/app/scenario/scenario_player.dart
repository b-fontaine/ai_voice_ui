import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_core/shared_core.dart';

/// Rejoue un scénario embarqué : lit l'asset `assets/replays/<scénario>.jsonl` et
/// expose chaque message A2UI v0.9 dans un flux, dans l'ordre.
///
/// Le paquet d'assets et l'attente sont injectés (frontières remplaçables).
class ScenarioPlayer {
  ScenarioPlayer({required this.bundle, this.delay});

  final AssetBundle bundle;
  final ReplayDelay? delay;

  /// Flux des messages de [scenario], paresseux : la lecture démarre à
  /// l'abonnement et s'arrête à l'annulation. Les erreurs de lecture
  /// (asset absent, ligne invalide) sont des erreurs du flux.
  Stream<A2uiMessage> messages(String scenario) async* {
    final text = await bundle.loadString(
      'assets/replays/$scenario.jsonl',
      cache: false,
    );
    final lines = Stream<String>.fromIterable(
      const LineSplitter().convert(text),
    );
    final source = delay == null
        ? A2uiReplaySource(lines: lines)
        : A2uiReplaySource(lines: lines, delay: delay!);
    yield* source.messages();
  }
}
