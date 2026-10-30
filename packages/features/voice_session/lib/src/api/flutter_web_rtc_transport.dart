import 'dart:async';

import '../model/voice_transport.dart';
import 'web_rtc_platform.dart';

/// [VoiceTransport] WebRTC au-dessus d'une [WebRtcPlatform].
///
/// Une instance sert à **un seul** démarrage et n'ouvre qu'**un** micro
/// (une seule source de capture). [stop] est valable à tout moment, même
/// pendant [createOfferSdp] : ce qui est acquis est alors libéré, et
/// [createOfferSdp] échoue avec `failed`. La libération se fait dans l'ordre
/// micro (pistes puis flux) puis connexion (canal puis connexion) ; chaque
/// étape tolère l'échec de la précédente. [stop] ferme le pair sans le
/// libérer ; [dispose] libère en plus l'objet natif, une seule fois.
class FlutterWebRtcTransport implements VoiceTransport {
  FlutterWebRtcTransport({
    required this._platform,
    this._iceTimeout = const Duration(seconds: 10),
  });

  static const String _eventsChannel = 'oai-events';

  final WebRtcPlatform _platform;
  final Duration _iceTimeout;

  RtcMic? _mic;
  RtcPeer? _peer;
  RtcPeer? _closedPeer;
  bool _offerStarted = false;
  bool _offerCreated = false;
  bool _remoteAudioEnabled = true;
  bool _stopped = false;
  bool _disposed = false;

  @override
  Future<String> createOfferSdp() async {
    if (_offerStarted || _stopped) {
      throw StateError('Ce transport ne sert qu\'à un seul démarrage.');
    }
    _offerStarted = true;
    try {
      final mic = await _guard(
        _platform.openMic,
        VoiceTransportFailure.micUnavailable,
      );
      _mic = mic;
      await _abortIfStopped();
      final peer = await _guard(
        _platform.createPeer,
        VoiceTransportFailure.failed,
      );
      _peer = peer;
      await _abortIfStopped();
      if (!_remoteAudioEnabled) await _applyRemoteAudio(peer, false);
      await _guard(() => peer.addMic(mic), VoiceTransportFailure.failed);
      await _abortIfStopped();
      await _guard(
        () => peer.createDataChannel(_eventsChannel),
        VoiceTransportFailure.failed,
      );
      await _abortIfStopped();
      final sdp = await _guard(
        () => peer.createOfferWithGatheredCandidates(_iceTimeout),
        VoiceTransportFailure.failed,
        timeout: VoiceTransportFailure.iceTimeout,
      );
      await _abortIfStopped();
      _offerCreated = true;
      return sdp;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    final peer = _peer;
    if (!_offerCreated || _stopped || _disposed || peer == null) {
      throw StateError('Aucune offre à compléter.');
    }
    await _abortIfStopped();
    await _guard(() => peer.setRemoteAnswer(sdp), VoiceTransportFailure.failed);
  }

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    if (_stopped) return;
    _remoteAudioEnabled = enabled;
    final peer = _peer;
    if (peer != null) await _applyRemoteAudio(peer, enabled);
  }

  /// Applique l'état au pair ; l'échec est absorbé (la voix continue, au pire).
  Future<void> _applyRemoteAudio(RtcPeer peer, bool enabled) async {
    try {
      await peer.setRemoteAudioEnabled(enabled);
    } catch (_) {
      // Coupure au mieux : ne doit pas faire échouer la session.
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final mic = _mic;
    final peer = _peer;
    _mic = null;
    try {
      await mic?.stop();
    } catch (_) {
      // Libération au mieux : l'étape suivante doit avoir lieu.
    }
    if (peer == null || identical(peer, _closedPeer)) return;
    _closedPeer = peer;
    try {
      await peer.close();
    } catch (_) {
      // Idem.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _disposePeer();
  }

  /// Libère l'objet natif du pair, une seule fois, erreurs absorbées.
  Future<void> _disposePeer() async {
    final peer = _peer;
    _peer = null;
    try {
      await peer?.dispose();
    } catch (_) {
      // Rien de plus à libérer.
    }
  }

  /// Après une étape asynchrone : si [stop] est passé entre-temps, libère ce
  /// que l'étape vient d'acquérir et abandonne.
  Future<void> _abortIfStopped() async {
    if (!_stopped) return;
    await stop();
    if (_disposed) await _disposePeer();
    throw const VoiceTransportException(VoiceTransportFailure.failed);
  }

  /// Exécute [step] ; toute erreur devient une [VoiceTransportException]
  /// sans détail de la plateforme.
  Future<T> _guard<T>(
    Future<T> Function() step,
    VoiceTransportFailure failure, {
    VoiceTransportFailure? timeout,
  }) async {
    try {
      return await step();
    } on VoiceTransportException {
      rethrow;
    } on TimeoutException {
      throw VoiceTransportException(timeout ?? failure);
    } catch (_) {
      throw VoiceTransportException(failure);
    }
  }
}
