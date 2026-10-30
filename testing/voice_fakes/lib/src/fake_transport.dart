import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;

/// Faux transport : frontière WebRTC (micro, `RTCPeerConnection`).
///
/// Chaque appel est consigné dans [calls] et dans le journal commun
/// (`t<rang>.<appel>`), pour vérifier l'ordre de libération
/// ([rt-graceful-close]) et qu'un transport n'est jamais réutilisé.
class FakeTransport implements VoiceTransport {
  FakeTransport(this.index, this._journal, {String Function(int)? offerFor})
    : offerSdp = offerFor?.call(index) ?? 'offer-$index';

  /// Rang de création (à partir de 1).
  final int index;

  /// Offre SDP produite, propre à ce transport.
  final String offerSdp;
  final void Function(String event) _journal;

  /// Appels reçus, dans l'ordre : `createOfferSdp`, `applyAnswer`, `stop`,
  /// `dispose`.
  final List<String> calls = <String>[];
  final List<String> appliedAnswers = <String>[];

  /// État de la piste audio distante (lecture de la voix de l'IA) ; coupée
  /// par [setRemoteAudioEnabled] à `voice.interrupted` (spec 011).
  bool remoteAudioEnabled = true;

  /// Remplacent le comportement par défaut (retard, échec, attente).
  Future<String> Function()? offerHook;
  Future<void> Function(String sdp)? answerHook;
  Future<void> Function()? stopHook;

  /// `true` une fois `stop` puis `dispose` appelés, dans cet ordre, une fois.
  bool get isReleased =>
      calls.where((c) => c == 'dispose').length == 1 &&
      calls.contains('stop') &&
      calls.indexOf('stop') < calls.indexOf('dispose');

  void _record(String call) {
    calls.add(call);
    _journal('t$index.$call');
  }

  @override
  Future<String> createOfferSdp() async {
    _record('createOfferSdp');
    return offerHook != null ? offerHook!() : offerSdp;
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    _record('applyAnswer');
    appliedAnswers.add(sdp);
    await answerHook?.call(sdp);
  }

  /// Coupe ou rétablit la piste distante (frontière WebRTC, spec 011).
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    _record('setRemoteAudioEnabled($enabled)');
    remoteAudioEnabled = enabled;
  }

  @override
  Future<void> stop() async {
    _record('stop');
    await stopHook?.call();
  }

  @override
  Future<void> dispose() async => _record('dispose');
}

/// Fabrique `VoiceTransport Function()` : un **nouveau** transport par
/// démarrage, tous conservés pour les assertions.
class FakeTransportFactory {
  FakeTransportFactory(this._journal, {this.offerFor});

  final void Function(String event) _journal;

  /// Forme de l'offre SDP selon le rang du transport (défaut `offer-<rang>`).
  final String Function(int index)? offerFor;
  final List<FakeTransport> created = <FakeTransport>[];

  /// Appelé à chaque création, avant le retour du transport.
  void Function(FakeTransport transport)? onCreated;

  FakeTransport call() {
    final transport = FakeTransport(
      created.length + 1,
      _journal,
      offerFor: offerFor,
    );
    created.add(transport);
    onCreated?.call(transport);
    return transport;
  }
}
