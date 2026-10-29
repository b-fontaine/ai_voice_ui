import 'dart:async';
import 'dart:convert';

import 'package:genui/genui.dart'
    show ChatMessage, UiInteractionPart, UiPartListExtension;

/// Écoute les erreurs que le moteur genui signale par `reportError`.
///
/// `SurfaceController.handleMessage` n'échoue jamais : il avale les erreurs
/// d'état et de validation et les pousse dans `onSubmit` sous la forme
/// `{"version":"v0.9","error":{…}}`. Sans écoute, un rejeu invalide
/// passerait pour réussi. Le compteur [count] permet à l'appelant de sortir
/// avec le code 1.
class EngineErrorWatcher {
  EngineErrorWatcher({
    required Stream<ChatMessage> onSubmit,
    required this.errorSink,
  }) {
    _subscription = onSubmit.listen(_onMessage);
  }

  /// Destination des messages d'erreur (`stderr` en prod).
  final StringSink errorSink;

  late final StreamSubscription<ChatMessage> _subscription;
  int _count = 0;

  /// Nombre d'erreurs du moteur vues depuis la création.
  int get count => _count;

  void _onMessage(ChatMessage message) {
    for (final UiInteractionPart part in message.parts.uiInteractionParts) {
      final Object? decoded = _tryDecode(part.interaction);
      if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
        _count++;
        errorSink.writeln(
          'Erreur du moteur genui : ${jsonEncode(decoded['error'])}',
        );
      }
    }
  }

  static Object? _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
