import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:entity_session/entity_session.dart';

/// Point de passage unique des messages A2UI avant le moteur (A2 du plan 007).
///
/// Il possède UNE instance de [GenesisMessageValidator] (à état par session),
/// appliquée au flux unique de `SessionEvent`, en direct comme en rejeu
/// (voir [replayEvents]). Pour chaque `A2uiEnvelopeReceived` :
///
/// - [validated] reçoit TOUS les messages avec leur verdict (futur panneau du
///   protocole), y compris les `ignored` ;
/// - [accepted] ne reçoit que les messages `accepted`, plus les
///   `deleteSurface` locaux de compensation ; c'est le flux du `CanvasBloc`.
///
/// Un message refusé est signalé à [onRejected] avec son code fermé : jamais
/// son contenu (il vient d'un modèle de langage).
///
/// [accepted] est à abonné unique et met en mémoire tant qu'il n'est pas
/// écouté (aucun message perdu si le Bloc s'abonne un peu plus tard) ;
/// [validated] est en diffusion : ses abonnés se branchent avant [attach].
/// La fin et les erreurs de la source sont relayées à [accepted] (le Bloc en
/// déduit « rejeu terminé » ou « rejeu impossible »).
class A2uiGate {
  A2uiGate({required String catalogId, this.onRejected})
    : _validator = GenesisMessageValidator(catalogId: catalogId);

  /// Reçoit le code de refus (valeur de [ValidationCodes]).
  final void Function(String code)? onRejected;

  final GenesisMessageValidator _validator;
  final StreamController<ValidatedEnvelope> _validated =
      StreamController<ValidatedEnvelope>.broadcast();
  final StreamController<a2ui.A2uiMessage> _accepted =
      StreamController<a2ui.A2uiMessage>();
  StreamSubscription<SessionEvent>? _subscription;
  bool _disposed = false;

  /// Tous les messages A2UI, avec leur verdict.
  Stream<ValidatedEnvelope> get validated => _validated.stream;

  /// Messages à appliquer au canevas, dans l'ordre.
  Stream<a2ui.A2uiMessage> get accepted => _accepted.stream;

  /// Adapte un flux de rejeu au flux unique de `SessionEvent` : `raw` est le
  /// JSON du message, sans agent ni tâche.
  static Stream<SessionEvent> replayEvents(Stream<a2ui.A2uiMessage> replay) =>
      replay.map(
        (message) => A2uiEnvelopeReceived(
          message: message,
          raw: Map<String, Object?>.from(message.toJson()),
        ),
      );

  /// Branche la source (une seule fois). Les événements qui ne sont pas des
  /// messages A2UI sont ignorés.
  void attach(Stream<SessionEvent> events) {
    if (_subscription != null) {
      throw StateError('A2uiGate.attach appelé deux fois.');
    }
    if (_disposed) return;
    _subscription = events.listen(
      _onEvent,
      onError: (Object error, StackTrace stack) {
        if (!_accepted.isClosed) _accepted.addError(error, stack);
      },
      onDone: () => unawaited(_closeStreams()),
    );
  }

  /// Remet le validateur à zéro (remise à vide de la scène).
  void reset() => _validator.reset();

  void _onEvent(SessionEvent event) {
    if (event is! A2uiEnvelopeReceived || _disposed) return;
    final ValidatedEnvelope envelope = _validator.check(
      event.raw,
      agent: event.agent,
      task: event.task,
    );
    _validated.add(envelope);
    switch (envelope.verdict) {
      case ValidationAccepted():
        _accepted.add(event.message);
      case ValidationRejected(:final code):
        onRejected?.call(code);
      case ValidationIgnored():
        break;
    }
    for (final String surfaceId in envelope.compensations) {
      _accepted.add(a2ui.DeleteSurfaceMessage(surfaceId: surfaceId));
    }
  }

  Future<void> _closeStreams() async {
    final Future<void> accepted = _accepted.isClosed
        ? Future<void>.value()
        : _accepted.close();
    final Future<void> validated = _validated.isClosed
        ? Future<void>.value()
        : _validated.close();
    // Sans abonné, la fin d'un flux à abonné unique n'est jamais notifiée.
    await validated;
    if (_accepted.hasListener) await accepted;
  }

  /// Se désabonne de la source et ferme les flux. Idempotent.
  Future<void> dispose() async {
    _disposed = true;
    final StreamSubscription<SessionEvent>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _closeStreams();
  }
}
