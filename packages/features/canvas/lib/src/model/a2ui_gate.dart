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
/// - les [validatedBranch] reçoivent TOUS les messages avec leur verdict
///   (panneau du protocole, étagère), y compris les `ignored` ;
/// - [accepted] ne reçoit que les messages `accepted`, plus les
///   `deleteSurface` locaux de compensation ; c'est le flux du `CanvasBloc`.
///
/// Un message refusé est signalé à [onRejected] avec son code fermé : jamais
/// son contenu (il vient d'un modèle de langage).
///
/// [accepted] est à abonné unique et met en mémoire tant qu'il n'est pas
/// écouté (aucun message perdu si le Bloc s'abonne un peu plus tard) ;
/// un Bloc s'abonne quelques tours de boucle après son `add` : il prend donc
/// une [validatedBranch], à abonné unique, qui garde en mémoire ce qui arrive
/// avant son écoute.
/// La fin et les erreurs de la source sont relayées à [accepted] (le Bloc en
/// déduit « rejeu terminé » ou « rejeu impossible »).
class A2uiGate {
  A2uiGate({required String catalogId, this.onRejected})
    : _validator = GenesisMessageValidator(catalogId: catalogId);

  /// Reçoit le code de refus (valeur de [ValidationCodes]).
  final void Function(String code)? onRejected;

  final GenesisMessageValidator _validator;
  final StreamController<a2ui.A2uiMessage> _accepted =
      StreamController<a2ui.A2uiMessage>();
  final List<StreamController<ValidatedEnvelope>> _branches =
      <StreamController<ValidatedEnvelope>>[];
  StreamSubscription<SessionEvent>? _subscription;
  bool _disposed = false;

  /// Nouvelle branche des messages A2UI avec leur verdict, à abonné unique : les messages validés
  /// depuis cet appel sont mis en mémoire jusqu'à son écoute (aucun n'est
  /// perdu si le consommateur s'abonne un peu plus tard) ; elle se termine
  /// avec le gate. Déjà terminée si le gate est fermé.
  Stream<ValidatedEnvelope> validatedBranch() {
    final StreamController<ValidatedEnvelope> branch =
        StreamController<ValidatedEnvelope>();
    if (_disposed) {
      unawaited(branch.close());
    } else {
      _branches.add(branch);
    }
    return branch.stream;
  }

  /// Messages à appliquer au canevas, dans l'ordre.
  Stream<a2ui.A2uiMessage> get accepted => _accepted.stream;

  /// Adapte un flux de rejeu au flux unique de `SessionEvent`. `raw` est le
  /// JSON **brut** du message, tel qu'il a été lu (sans agent ni tâche) : c'est
  /// lui que le validateur contrôle, jamais le JSON reconstruit depuis le
  /// message décodé (le décodeur peut écarter ou normaliser une propriété).
  static Stream<SessionEvent> replayEvents(
    Stream<({Map<String, Object?> raw, a2ui.A2uiMessage message})> replay,
  ) => replay.map(
    (entry) => A2uiEnvelopeReceived(
      message: entry.message,
      raw: Map<String, Object?>.from(entry.raw),
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
    for (final StreamController<ValidatedEnvelope> branch in _branches) {
      if (!branch.isClosed) branch.add(envelope);
    }
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
    // Sans abonné, la fin d'un flux à abonné unique n'est jamais notifiée :
    // les branches se ferment sans être attendues.
    for (final StreamController<ValidatedEnvelope> branch in _branches) {
      if (!branch.isClosed) unawaited(branch.close());
    }
    _branches.clear();
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
