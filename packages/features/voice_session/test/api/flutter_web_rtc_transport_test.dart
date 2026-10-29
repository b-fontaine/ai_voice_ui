import 'dart:async';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux de plateforme (frontière libwebrtc) : journalise chaque appel et
/// laisse chaque étape asynchrone sous le contrôle du test.
class _FakePlatform implements WebRtcPlatform {
  final List<String> log = <String>[];
  Future<void> Function()? openMicGate;
  Object? openMicError;
  Object? createPeerError;
  Object? addMicError;
  Object? offerError;
  Future<void> Function()? offerGate;
  Object? answerError;
  Object? micStopError;
  Object? peerCloseError;
  int openMicCalls = 0;

  @override
  Future<RtcMic> openMic() async {
    openMicCalls++;
    log.add('openMic');
    await openMicGate?.call();
    if (openMicError != null) throw openMicError!;
    return _FakeMic(this);
  }

  @override
  Future<RtcPeer> createPeer() async {
    log.add('createPeer');
    if (createPeerError != null) throw createPeerError!;
    return _FakePeer(this);
  }
}

class _FakeMic implements RtcMic {
  _FakeMic(this._platform);
  final _FakePlatform _platform;

  @override
  Future<void> stop() async {
    _platform.log.add('mic.stop');
    if (_platform.micStopError != null) throw _platform.micStopError!;
  }
}

class _FakePeer implements RtcPeer {
  _FakePeer(this._platform);
  final _FakePlatform _platform;

  @override
  Future<void> addMic(RtcMic mic) async {
    _platform.log.add('addMic');
    if (_platform.addMicError != null) throw _platform.addMicError!;
  }

  @override
  Future<void> createDataChannel(String label) async {
    _platform.log.add('createDataChannel($label)');
  }

  @override
  Future<String> createOfferWithGatheredCandidates(Duration iceTimeout) async {
    _platform.log.add('createOffer(${iceTimeout.inMilliseconds}ms)');
    await _platform.offerGate?.call();
    if (_platform.offerError != null) throw _platform.offerError!;
    return 'v=0 offer';
  }

  @override
  Future<void> setRemoteAnswer(String sdp) async {
    _platform.log.add('setRemoteAnswer($sdp)');
    if (_platform.answerError != null) throw _platform.answerError!;
  }

  @override
  Future<void> close() async {
    _platform.log.add('peer.close');
    if (_platform.peerCloseError != null) throw _platform.peerCloseError!;
  }
}

Matcher _failure(VoiceTransportFailure kind) =>
    throwsA(isA<VoiceTransportException>().having((e) => e.kind, 'kind', kind));

void main() {
  late _FakePlatform platform;
  late FlutterWebRtcTransport transport;

  setUp(() {
    platform = _FakePlatform();
    transport = FlutterWebRtcTransport(
      platform: platform,
      iceTimeout: const Duration(milliseconds: 50),
    );
  });

  test(
    'crée le canal avant l\'offre, dans l\'ordre, avec un seul micro',
    () async {
      final sdp = await transport.createOfferSdp();

      expect(sdp, 'v=0 offer');
      expect(platform.log, <String>[
        'openMic',
        'createPeer',
        'addMic',
        'createDataChannel(oai-events)',
        'createOffer(50ms)',
      ]);
      expect(platform.openMicCalls, 1);
    },
  );

  test('le délai ICE par défaut est de 10 secondes', () async {
    final defaults = FlutterWebRtcTransport(platform: platform);
    await defaults.createOfferSdp();
    expect(platform.log.last, 'createOffer(10000ms)');
  });

  test(
    'micro indisponible : micUnavailable et rien d\'autre n\'est créé',
    () async {
      platform.openMicError = Exception('NotAllowedError');

      await expectLater(
        transport.createOfferSdp(),
        _failure(VoiceTransportFailure.micUnavailable),
      );
      expect(platform.log, <String>['openMic']);
    },
  );

  test('délai ICE dépassé : iceTimeout puis libération complète', () async {
    platform.offerError = TimeoutException('ice');

    await expectLater(
      transport.createOfferSdp(),
      _failure(VoiceTransportFailure.iceTimeout),
    );
    expect(platform.log.skip(5), <String>['mic.stop', 'peer.close']);
  });

  test('autre échec de l\'offre : failed et libération', () async {
    platform.offerError = StateError('sdp');

    await expectLater(
      transport.createOfferSdp(),
      _failure(VoiceTransportFailure.failed),
    );
    expect(platform.log.skip(5), <String>['mic.stop', 'peer.close']);
  });

  test('échec de createPeer : failed et le micro est libéré', () async {
    platform.createPeerError = Exception('boom');

    await expectLater(
      transport.createOfferSdp(),
      _failure(VoiceTransportFailure.failed),
    );
    expect(platform.log, <String>['openMic', 'createPeer', 'mic.stop']);
  });

  test('échec de addMic : failed et libération', () async {
    platform.addMicError = Exception('boom');

    await expectLater(
      transport.createOfferSdp(),
      _failure(VoiceTransportFailure.failed),
    );
    expect(platform.log.skip(3), <String>['mic.stop', 'peer.close']);
  });

  test('applyAnswer avant l\'offre : StateError', () async {
    await expectLater(transport.applyAnswer('a'), throwsStateError);
    expect(platform.log, isEmpty);
  });

  test('applyAnswer pendant la création de l\'offre : StateError', () async {
    final gate = Completer<void>();
    platform.offerGate = () => gate.future;
    final offer = transport.createOfferSdp();
    await pumpEventQueue();

    await expectLater(transport.applyAnswer('a'), throwsStateError);

    gate.complete();
    await offer;
  });

  test('second createOfferSdp : StateError, un seul micro', () async {
    await transport.createOfferSdp();

    await expectLater(transport.createOfferSdp(), throwsStateError);
    expect(platform.openMicCalls, 1);
  });

  test('applyAnswer transmet l\'answer ; une erreur donne failed', () async {
    await transport.createOfferSdp();
    await transport.applyAnswer('answer-sdp');
    expect(platform.log.last, 'setRemoteAnswer(answer-sdp)');

    platform.answerError = Exception('refusée');
    await expectLater(
      transport.applyAnswer('autre'),
      _failure(VoiceTransportFailure.failed),
    );
  });

  test('stop libère le micro puis la connexion, et reste idempotent', () async {
    await transport.createOfferSdp();
    platform.log.clear();

    await transport.stop();
    await transport.stop();
    await transport.dispose();
    await transport.dispose();

    expect(platform.log, <String>['mic.stop', 'peer.close']);
  });

  test('stop avant tout appel ne crée rien et interdit la suite', () async {
    await transport.stop();

    expect(platform.log, isEmpty);
    await expectLater(transport.createOfferSdp(), throwsStateError);
  });

  test('dispose sans stop préalable libère tout', () async {
    await transport.createOfferSdp();
    platform.log.clear();

    await transport.dispose();

    expect(platform.log, <String>['mic.stop', 'peer.close']);
    await expectLater(transport.createOfferSdp(), throwsStateError);
    await expectLater(transport.applyAnswer('a'), throwsStateError);
  });

  test('chaque étape de libération tolère l\'échec de la précédente', () async {
    await transport.createOfferSdp();
    platform
      ..micStopError = Exception('mic')
      ..peerCloseError = Exception('peer')
      ..log.clear();

    await transport.stop();

    expect(platform.log, <String>['mic.stop', 'peer.close']);
  });

  test(
    'stop pendant l\'ouverture du micro : le micro est libéré à son arrivée',
    () async {
      final gate = Completer<void>();
      platform.openMicGate = () => gate.future;
      final offer = transport.createOfferSdp();
      final failed = expectLater(offer, _failure(VoiceTransportFailure.failed));
      await pumpEventQueue();

      await transport.stop();
      gate.complete();
      await failed;

      expect(platform.log, <String>['openMic', 'mic.stop']);
    },
  );

  test('stop pendant la collecte ICE : micro et connexion libérés', () async {
    final gate = Completer<void>();
    platform.offerGate = () => gate.future;
    final offer = transport.createOfferSdp();
    final failed = expectLater(offer, _failure(VoiceTransportFailure.failed));
    await pumpEventQueue();

    await transport.stop();
    expect(platform.log.skip(5), <String>['mic.stop', 'peer.close']);
    gate.complete();
    await failed;

    expect(platform.log.where((e) => e == 'mic.stop'), hasLength(1));
    expect(platform.log.where((e) => e == 'peer.close'), hasLength(1));
  });
}
