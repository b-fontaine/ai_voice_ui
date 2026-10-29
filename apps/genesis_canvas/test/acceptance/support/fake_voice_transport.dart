import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;

/// Faux `VoiceTransport` : frontière WebRTC (micro, `RTCPeerConnection`).
///
/// Il enregistre l'ordre des appels reçus de `VoiceSession` pour vérifier la
/// libération ([rt-graceful-close]) et qu'un transport n'est jamais réutilisé.
class FakeVoiceTransport implements VoiceTransport {
  FakeVoiceTransport(this.index, this._journal);

  /// Rang de création (à partir de 1), dans l'offre SDP.
  final int index;
  final void Function(String event) _journal;

  /// Appels reçus, dans l'ordre : `createOfferSdp`, `applyAnswer`, `stop`,
  /// `dispose`.
  final List<String> calls = <String>[];
  final List<String> appliedAnswers = <String>[];

  /// Offre SDP produite, propre à ce transport.
  String get offerSdp =>
      'v=0\r\no=fake-transport-$index 0 0 IN IP4 0.0.0.0\r\n';

  /// `true` une fois `stop` puis `dispose` appelés, dans cet ordre, une fois.
  bool get isReleased =>
      calls.where((c) => c == 'dispose').length == 1 &&
      calls.contains('stop') &&
      calls.indexOf('stop') < calls.indexOf('dispose');

  void _record(String call) {
    calls.add(call);
    _journal('transport#$index $call');
  }

  @override
  Future<String> createOfferSdp() async {
    _record('createOfferSdp');
    return offerSdp;
  }

  @override
  Future<void> applyAnswer(String sdp) async {
    _record('applyAnswer');
    appliedAnswers.add(sdp);
  }

  @override
  Future<void> stop() async => _record('stop');

  @override
  Future<void> dispose() async => _record('dispose');
}

/// Fabrique injectée dans l'app (`VoiceTransport Function()`) : un **nouveau**
/// transport par démarrage, tous conservés pour les assertions.
class FakeVoiceTransportFactory {
  FakeVoiceTransportFactory(this._journal);

  final void Function(String event) _journal;
  final List<FakeVoiceTransport> created = <FakeVoiceTransport>[];

  VoiceTransport call() {
    final transport = FakeVoiceTransport(created.length + 1, _journal);
    created.add(transport);
    return transport;
  }
}
