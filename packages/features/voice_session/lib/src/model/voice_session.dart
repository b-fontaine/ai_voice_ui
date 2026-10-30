import 'dart:async';

import 'package:shared_backend_channel/shared_backend_channel.dart';

import 'voice_failure.dart';
import 'voice_session_status.dart';
import 'voice_transport.dart';

/// Unique machine à états de la session voix :
/// `Idle → Connecting → Active → Stopping → Idle | Failed`.
///
/// Elle possède, pour la durée d'une session, le transport (neuf à chaque
/// démarrage), le canal WSS et le journal. Un compteur de génération,
/// incrémenté à chaque [start], écarte tout événement d'une session
/// précédente.
///
/// Ordre de libération ([rt-graceful-close]) : `DELETE` (borné, toute erreur
/// absorbée), annulation du canal, fermeture du journal, `transport.stop()`
/// puis `transport.dispose()`. Chaque étape tolère l'échec de la précédente.
class VoiceSession {
  VoiceSession({
    required this._transportFactory,
    required this._relay,
    required this._channel,
    required this._logFactory,
    this._closeTimeout = const Duration(seconds: 8),
  });

  final VoiceTransport Function() _transportFactory;
  final VoiceRelay _relay;
  final AppChannel _channel;
  final EnvelopeLog Function() _logFactory;
  final Duration _closeTimeout;

  final StreamController<VoiceSessionStatus> _statusController =
      StreamController<VoiceSessionStatus>.broadcast();
  final StreamController<AppChannelEnvelope> _envelopeController =
      StreamController<AppChannelEnvelope>.broadcast();

  VoiceSessionStatus _current = const Idle();
  int _generation = 0;
  bool _stopRequested = false;
  bool _releasing = false;
  bool _disposed = false;

  // Ressources de la session courante.
  VoiceTransport? _transport;
  String? _sessionId;
  EnvelopeLog? _log;
  StreamSubscription<AppChannelEnvelope>? _subscription;

  // Opération en cours (démarrage ou libération), partagée par les `stop`.
  Future<void>? _running;

  /// Statut courant, sans attendre le flux.
  VoiceSessionStatus get current => _current;

  /// Statuts, en diffusion : le statut courant est rejoué à chaque nouvel
  /// abonné. N'émet jamais d'erreur.
  Stream<VoiceSessionStatus> get status =>
      Stream<VoiceSessionStatus>.multi((controller) {
        controller.add(_current);
        final subscription = _statusController.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      }, isBroadcast: true);

  /// Enveloppes de la session courante seulement, en diffusion, sans erreur.
  Stream<AppChannelEnvelope> get envelopes => _envelopeController.stream;

  /// Démarre une session. Sans effet hors `Idle`/`Failed`. Se termine quand
  /// la session est `Active`, ou en échec / annulée, ressources libérées.
  Future<void> start() {
    if (_disposed || !(_current is Idle || _current is Failed)) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    _stopRequested = false;
    _releasing = false;
    _set(const Connecting());
    return _running = _connect(generation);
  }

  /// Arrête la session et libère tout ; la session reste réutilisable.
  /// Idempotent. Sans effet depuis `Failed` (déjà libérée).
  Future<void> stop() {
    switch (_current) {
      case Idle() || Failed():
        return Future<void>.value();
      case Stopping():
        return _running ?? Future<void>.value();
      case Connecting():
        // Le démarrage se replie à l'étape suivante et libère lui-même.
        _stopRequested = true;
        _set(const Stopping());
        return _running ?? Future<void>.value();
      case Active():
        _stopRequested = true;
        return _beginRelease(deleteRemote: true, failure: null);
    }
  }

  /// [stop] (borné), puis ferme les flux. Plus aucun état ensuite.
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _running;
    await _statusController.close();
    await _envelopeController.close();
  }

  bool _isStale(int generation) =>
      generation != _generation || _stopRequested || _releasing;

  void _set(VoiceSessionStatus status) {
    _current = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> _connect(int generation) async {
    VoiceFailure? failure;
    try {
      final transport = _transport = _transportFactory();
      final String offer;
      try {
        offer = await transport.createOfferSdp();
      } on Object catch (error) {
        throw _StartFailure(_fromTransport(error, const MicUnavailable()));
      }
      _checkStart(generation);

      final RelayAnswer answer;
      try {
        answer = await _relay.createSession(offer);
      } on Object catch (error) {
        throw _StartFailure(_fromRelay(error));
      }
      _sessionId = answer.sessionId;
      _checkStart(generation);

      try {
        await transport.applyAnswer(answer.answerSdp);
      } on Object catch (error) {
        throw _StartFailure(_fromTransport(error, const RelayFailed()));
      }
      _checkStart(generation);

      final log = _logFactory();
      _log = log;
      await log.open();
      _checkStart(generation);

      try {
        _subscription = _channel
            .open(answer.sessionId)
            .listen(
              (envelope) => _onEnvelope(generation, envelope),
              onError: (Object error) => _onChannelError(generation, error),
              onDone: () => _onChannelDone(generation),
            );
      } on Object {
        throw const _StartFailure(ConnectionLost());
      }
      _set(const Active());
      return;
    } on _StartAborted {
      // Arrêt demandé : libération ci-dessous.
    } on _StartFailure catch (error) {
      failure = error.failure;
    } on Object {
      // Imprévu (fabrique, journal…) : jamais d'état bloqué, on libère.
      failure = const RelayFailed();
    }
    await _release(deleteRemote: true);
    if (generation != _generation) return;
    _set(_stopRequested || failure == null ? const Idle() : Failed(failure));
  }

  void _checkStart(int generation) {
    if (generation != _generation || _stopRequested) {
      throw const _StartAborted();
    }
  }

  void _onEnvelope(int generation, AppChannelEnvelope envelope) {
    if (generation != _generation) return;
    // Journal : toute enveloppe de la session courante, même pendant la
    // libération (dernier `usage`, `closed`, derniers transcripts).
    _log?.append(envelope);
    if (_isStale(generation)) return;
    _envelopeController.add(envelope);
    if (envelope.type == AppChannelTypes.sessionState &&
        envelope.session == _sessionId &&
        envelope.data['state'] == 'closed') {
      final reason = envelope.data['reason'];
      unawaited(
        _beginRelease(
          deleteRemote: false,
          failure: SessionClosed(reason is String ? reason : null),
        ),
      );
    }
  }

  void _onChannelError(int generation, Object error) {
    if (_isStale(generation)) return;
    final notFound =
        error is AppChannelFailure &&
        error.kind == AppChannelFailureKind.sessionNotFound;
    unawaited(
      _beginRelease(
        deleteRemote: !notFound,
        failure: notFound ? const SessionClosed(null) : const ConnectionLost(),
      ),
    );
  }

  void _onChannelDone(int generation) {
    if (_isStale(generation)) return;
    unawaited(
      _beginRelease(deleteRemote: true, failure: const ConnectionLost()),
    );
  }

  /// Libération d'une session `Active`. [failure] nul : arrêt demandé.
  Future<void> _beginRelease({
    required bool deleteRemote,
    required VoiceFailure? failure,
  }) {
    _releasing = true;
    _set(const Stopping());
    return _running = () async {
      await _release(deleteRemote: deleteRemote);
      _set(_stopRequested || failure == null ? const Idle() : Failed(failure));
    }();
  }

  Future<void> _release({required bool deleteRemote}) async {
    final sessionId = _sessionId;
    final subscription = _subscription;
    final log = _log;
    final transport = _transport;
    _sessionId = null;
    _subscription = null;
    _transport = null;

    if (deleteRemote && sessionId != null) {
      try {
        // Filet de sécurité : le relais borne déjà son `DELETE` par son propre
        // délai (plus court) ; ce `.timeout` externe n'agit que si ce
        // délai n'est pas respecté.
        await _relay.deleteSession(sessionId).timeout(_closeTimeout);
      } on Object {
        // 204, 404, 504, délai, réseau : on libère quand même.
      }
    }
    try {
      await subscription?.cancel();
    } on Object {
      // Le canal est abandonné de toute façon.
    }
    try {
      // Le journal reste branché pendant le `DELETE` (cf. [_onEnvelope]).
      await log?.close();
    } on Object {
      // Le journal ne casse jamais la session.
    }
    if (identical(_log, log)) _log = null;
    try {
      await transport?.stop();
    } on Object {
      // dispose suit malgré tout.
    }
    try {
      await transport?.dispose();
    } on Object {
      // Rien de plus à libérer.
    }
  }

  VoiceFailure _fromTransport(Object error, VoiceFailure fallback) {
    if (error is VoiceTransportException) {
      return switch (error.kind) {
        VoiceTransportFailure.micUnavailable => const MicUnavailable(),
        VoiceTransportFailure.iceTimeout => const IceTimeout(),
        VoiceTransportFailure.failed => const RelayFailed(),
      };
    }
    return fallback;
  }

  VoiceFailure _fromRelay(Object error) {
    if (error is RelayFailure) {
      return switch (error.kind) {
        RelayFailureKind.unreachable ||
        RelayFailureKind.timeout => const BackendUnreachable(),
        RelayFailureKind.rateLimited => RateLimited(error.retryAfter),
        _ => const RelayFailed(),
      };
    }
    return const RelayFailed();
  }
}

/// Démarrage annulé par `stop` ou périmé : libération sans échec.
class _StartAborted implements Exception {
  const _StartAborted();
}

/// Échec du démarrage, avec sa cause fermée.
class _StartFailure implements Exception {
  const _StartFailure(this.failure);

  final VoiceFailure failure;
}
