import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart'
    show A2uiRendererError, EventSource, Subscription;

/// Écoute les erreurs que le moteur A2UI signale sur `model.onError`.
///
/// Le `MessageProcessor` de la page ne lève pas d'exception pour un message
/// refusé (`reportErrorsOnly`) : il publie l'erreur, comme celles que les
/// surfaces signalent au rendu, sur `model.onError`. Sans écoute, un rejeu
/// invalide passerait pour réussi. Le compteur [count] permet à l'appelant de
/// sortir avec le code 1.
class EngineErrorWatcher {
  EngineErrorWatcher({
    required EventSource<A2uiRendererError> errors,
    required this.errorSink,
  }) {
    _subscription = errors.subscribe(_onError);
  }

  /// Destination des messages d'erreur (`stderr` en prod).
  final StringSink errorSink;

  late final Subscription _subscription;
  int _count = 0;

  /// Nombre d'erreurs du moteur vues depuis la création.
  int get count => _count;

  void _onError(A2uiRendererError error) {
    _count++;
    errorSink.writeln('Erreur du moteur A2UI : ${jsonEncode(error.toJson())}');
  }

  Future<void> dispose() async => _subscription.unsubscribe();
}
