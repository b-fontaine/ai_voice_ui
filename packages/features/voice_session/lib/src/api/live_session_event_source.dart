import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

import '../model/voice_failure.dart';
import '../model/voice_session.dart';
import '../model/voice_session_status.dart';
import 'session_event_converter.dart';

/// [SessionEventSource] alimentée par une [VoiceSession] réelle.
///
/// Fusionne les enveloppes du canal (converties) et les transitions de statut
/// de la session en un seul flux de [SessionEvent]. Les abonnements internes
/// sont posés dès la construction : les abonnés externes peuvent se brancher
/// avant tout démarrage.
///
/// Le flux est en diffusion, vit autant que la source, n'émet jamais d'erreur
/// et ne se termine qu'à [dispose].
class LiveSessionEventSource implements SessionEventSource {
  /// Si [converter] est fourni, [onIgnored] est sans effet : le convertisseur
  /// porte son propre rappel.
  LiveSessionEventSource(
    VoiceSession session, {
    SessionEventConverter? converter,
    void Function(String reason)? onIgnored,
  }) : _converter = converter ?? SessionEventConverter(onIgnored: onIgnored),
       _previous = session.current {
    _envelopeSubscription = session.envelopes.listen(_onEnvelope);
    _statusSubscription = session.status.listen(_onStatus);
  }

  final SessionEventConverter _converter;
  final StreamController<SessionEvent> _controller =
      StreamController<SessionEvent>.broadcast();

  late final StreamSubscription<AppChannelEnvelope> _envelopeSubscription;
  late final StreamSubscription<VoiceSessionStatus> _statusSubscription;

  VoiceSessionStatus _previous;
  // La session a été `Active` et n'a pas encore émis son `closed`.
  bool _wasActive = false;
  // Le `closed` du backend a déjà été relayé pour la session courante.
  bool _closedRelayed = false;
  int _ignoredCount = 0;

  /// Nombre de messages ignorés (type inconnu, champ invalide…), pour le
  /// diagnostic.
  int get ignoredCount => _ignoredCount;

  @override
  Stream<SessionEvent> get events => _controller.stream;

  void _onEnvelope(AppChannelEnvelope envelope) {
    final SessionEvent? event = _converter.convert(envelope);
    if (event == null) {
      _ignoredCount++;
      return;
    }
    if (event is SessionStateChanged && event.state == SessionState.closed) {
      _closedRelayed = true;
    }
    _emit(event);
  }

  void _onStatus(VoiceSessionStatus status) {
    final VoiceSessionStatus previous = _previous;
    _previous = status;
    switch (status) {
      case Connecting():
        if (previous is! Connecting) {
          _wasActive = false;
          _closedRelayed = false;
          _emit(const SessionStateChanged(state: SessionState.connecting));
        }
      case Active():
        _wasActive = true;
      case Stopping():
        break;
      case Idle():
        _emitClosed('local_stop');
      case Failed(:final failure):
        switch (failure) {
          case ConnectionLost():
            _emitClosed('connection_lost');
            _emit(const ChannelLost('connection_lost'));
          case SessionClosed(:final reason):
            _emitClosed(reason);
          default:
            _emitClosed(null);
        }
    }
  }

  /// Émet le `closed` de la session qui vient de quitter `Active`, une seule
  /// fois, sauf si le backend l'a déjà relayé.
  void _emitClosed(String? reason) {
    if (!_wasActive) return;
    _wasActive = false;
    if (_closedRelayed) return;
    _emit(SessionStateChanged(state: SessionState.closed, reason: reason));
  }

  void _emit(SessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Annule les abonnements et ferme le flux. Idempotent.
  Future<void> dispose() async {
    if (_controller.isClosed) return;
    final Future<void> closing = _controller.close();
    await _envelopeSubscription.cancel();
    await _statusSubscription.cancel();
    await closing;
  }
}
