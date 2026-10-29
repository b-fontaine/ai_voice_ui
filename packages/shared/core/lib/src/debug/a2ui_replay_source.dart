import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage, A2uiValidationError;

/// Attente injectable entre deux messages (remplaçable dans les tests).
typedef ReplayDelay = Future<void> Function(Duration duration);

/// Ligne de rejeu invalide : JSON illisible, `t_ms` absent ou décroissant,
/// message absent ou refusé par le décodeur A2UI v0.9 (version, corps).
class A2uiReplayFormatException implements Exception {
  const A2uiReplayFormatException(this.lineNumber, this.message);

  /// Numéro de ligne (à partir de 1) dans le flux source.
  final int lineNumber;
  final String message;

  @override
  String toString() =>
      'A2uiReplayFormatException(ligne $lineNumber) : $message';
}

/// Rejoue un JSONL de messages A2UI v0.9.
///
/// Chaque ligne est `{"t_ms": <délai depuis le début>, "message": {…}}`.
/// Les messages sont émis dans l'ordre, après avoir attendu l'écart entre
/// leur `t_ms` et celui du message précédent.
class A2uiReplaySource {
  A2uiReplaySource({required this.lines, this.delay = _realDelay});

  /// Lignes JSONL à rejouer.
  final Stream<String> lines;

  /// Attente entre deux messages.
  final ReplayDelay delay;

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Flux des messages décodés, à consommer une seule fois.
  Stream<A2uiMessage> messages() async* {
    var lineNumber = 0;
    var previousMs = 0;
    await for (final raw in lines) {
      lineNumber++;
      if (raw.trim().isEmpty) continue;
      final entry = _parse(raw, lineNumber);
      if (entry.tMs < previousMs) {
        throw A2uiReplayFormatException(
          lineNumber,
          't_ms décroissant (${entry.tMs} après $previousMs)',
        );
      }
      final wait = entry.tMs - previousMs;
      if (wait > 0) await delay(Duration(milliseconds: wait));
      previousMs = entry.tMs;
      yield entry.message;
    }
  }

  static ({int tMs, A2uiMessage message}) _parse(String raw, int lineNumber) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw A2uiReplayFormatException(
        lineNumber,
        'JSON invalide : ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw A2uiReplayFormatException(lineNumber, 'objet JSON attendu');
    }
    final tMs = decoded['t_ms'];
    if (tMs is! int || tMs < 0) {
      throw A2uiReplayFormatException(
        lineNumber,
        't_ms manquant ou invalide (entier >= 0 attendu)',
      );
    }
    final message = decoded['message'];
    if (message is! Map<String, dynamic>) {
      throw A2uiReplayFormatException(lineNumber, 'message manquant');
    }
    try {
      return (tMs: tMs, message: A2uiMessage.fromJson(message));
    } on A2uiValidationError catch (e) {
      throw A2uiReplayFormatException(lineNumber, e.message);
    } on TypeError catch (e) {
      throw A2uiReplayFormatException(
        lineNumber,
        'corps de message A2UI mal formé : $e',
      );
    }
  }
}
