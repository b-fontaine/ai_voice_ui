import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_core/shared_core.dart';

/// Rejoue un scénario embarqué : lit l'asset `assets/replays/<scénario>.jsonl` et
/// remet chaque message A2UI v0.9 à [onMessage], dans l'ordre.
///
/// Le paquet d'assets et l'attente sont injectés (frontières remplaçables).
class ScenarioPlayer {
  ScenarioPlayer({required this.bundle, required this.onMessage, this.delay});

  final AssetBundle bundle;
  final void Function(Map<String, dynamic> message) onMessage;
  final ReplayDelay? delay;

  /// Joue [scenario] jusqu'à la fin du flux. Les erreurs de lecture
  /// (asset absent, ligne invalide) remontent à l'appelant.
  Future<void> play(String scenario) async {
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
    await for (final message in source.messages()) {
      onMessage(message);
    }
  }
}
