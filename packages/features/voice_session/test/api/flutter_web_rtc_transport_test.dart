import 'dart:async';

import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:feature_voice_session/src/api/remote_audio_switch.dart';
import 'package:feature_voice_session/src/api/web_rtc_platform.dart';
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
  Object? peerDisposeError;
  Object? remoteAudioError;
  Object? micEnabledError;

  /// État de la piste locale du micro (`track.enabled`).
  bool micTrackEnabled = true;
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
  Future<void> setEnabled(bool enabled) async {
    _platform.log.add('mic.setEnabled($enabled)');
    if (_platform.micEnabledError != null) throw _platform.micEnabledError!;
    _platform.micTrackEnabled = enabled;
  }

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
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    _platform.log.add('peer.remoteAudio($enabled)');
    if (_platform.remoteAudioError != null) throw _platform.remoteAudioError!;
  }

  @override
  Future<void> close() async {
    _platform.log.add('peer.close');
    if (_platform.peerCloseError != null) throw _platform.peerCloseError!;
  }

  @override
  Future<void> dispose() async {
    _platform.log.add('peer.dispose');
    if (_platform.peerDisposeError != null) throw _platform.peerDisposeError!;
  }
}

Matcher _failure(VoiceTransportFailure kind) =>
    throwsA(isA<VoiceTransportException>().having((e) => e.kind, 'kind', kind));

void main() {
  group('RemoteAudioSwitch (piste distante captée par onTrack)', () {
    test('coupure après onTrack : la piste est coupée puis rétablie', () {
      final switcher = RemoteAudioSwitch();
      final track = <bool>[];
      switcher.attach(track.add);

      switcher.setEnabled(false);
      switcher.setEnabled(true);

      expect(track, <bool>[false, true]);
    });

    test('coupure avant onTrack : la piste qui arrive ensuite est coupée', () {
      final switcher = RemoteAudioSwitch();
      final track = <bool>[];

      switcher.setEnabled(false);
      expect(track, isEmpty);
      switcher.attach(track.add);

      expect(track, <bool>[false]);
    });

    test('rien à appliquer tant que le son n\'a pas été coupé', () {
      final switcher = RemoteAudioSwitch();
      final track = <bool>[];

      switcher.attach(track.add);

      expect(track, isEmpty);
    });

    test('un nouvel interrupteur repart de « son actif »', () {
      final first = RemoteAudioSwitch()..setEnabled(false);
      final second = RemoteAudioSwitch();
      final track = <bool>[];

      second.attach(track.add);

      expect(first.enabled, isFalse);
      expect(second.enabled, isTrue);
      expect(track, isEmpty);
    });
  });

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

    expect(platform.log, <String>['mic.stop', 'peer.close', 'peer.dispose']);
  });

  test('stop sans dispose n\'appelle pas peer.dispose', () async {
    await transport.createOfferSdp();
    platform.log.clear();

    await transport.stop();

    expect(platform.log, <String>['mic.stop', 'peer.close']);
  });

  test('dispose deux fois : un seul peer.dispose', () async {
    await transport.createOfferSdp();
    platform.log.clear();

    await transport.dispose();
    await transport.dispose();

    expect(platform.log.where((e) => e == 'peer.dispose'), hasLength(1));
  });

  test('une erreur de peer.dispose est absorbée', () async {
    await transport.createOfferSdp();
    platform.peerDisposeError = Exception('natif');

    await transport.dispose();

    expect(platform.log.last, 'peer.dispose');
  });

  test('dispose pendant la collecte ICE : le pair est aussi disposé', () async {
    final gate = Completer<void>();
    platform.offerGate = () => gate.future;
    final failed = expectLater(
      transport.createOfferSdp(),
      _failure(VoiceTransportFailure.failed),
    );
    await pumpEventQueue();

    await transport.dispose();
    gate.complete();
    await failed;

    expect(platform.log.skip(5), <String>[
      'mic.stop',
      'peer.close',
      'peer.dispose',
    ]);
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

    expect(platform.log, <String>['mic.stop', 'peer.close', 'peer.dispose']);
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

  group('setRemoteAudioEnabled', () {
    test('coupure puis rétablissement transmis au pair', () async {
      await transport.createOfferSdp();

      await transport.setRemoteAudioEnabled(false);
      await transport.setRemoteAudioEnabled(true);

      expect(
        platform.log.where((e) => e.startsWith('peer.remoteAudio')),
        <String>['peer.remoteAudio(false)', 'peer.remoteAudio(true)'],
      );
    });

    test('coupure demandée avant le pair : appliquée à sa création', () async {
      await transport.setRemoteAudioEnabled(false);
      expect(platform.log, isEmpty);

      await transport.createOfferSdp();

      expect(platform.log, contains('peer.remoteAudio(false)'));
      expect(
        platform.log.indexOf('peer.remoteAudio(false)'),
        lessThan(platform.log.indexOf('createOffer(50ms)')),
      );
    });

    test(
      'redémarrage : un nouveau transport repart avec le son actif',
      () async {
        await transport.setRemoteAudioEnabled(false);
        await transport.stop();
        final restarted = FlutterWebRtcTransport(platform: platform);
        platform.log.clear();

        await restarted.createOfferSdp();

        expect(
          platform.log.where((e) => e.startsWith('peer.remoteAudio')),
          isEmpty,
        );
      },
    );

    test('après stop : sans effet et sans erreur', () async {
      await transport.createOfferSdp();
      await transport.stop();
      platform.log.clear();

      await transport.setRemoteAudioEnabled(false);

      expect(platform.log, isEmpty);
    });

    test('l\'échec du pair est absorbé', () async {
      await transport.createOfferSdp();
      platform.remoteAudioError = Exception('boom');

      await transport.setRemoteAudioEnabled(false);
    });
  });

  group('setMicEnabled', () {
    test(
      'coupure puis rétablissement : la piste change, jamais arrêtée',
      () async {
        await transport.createOfferSdp();

        await transport.setMicEnabled(false);
        expect(platform.micTrackEnabled, isFalse);
        await transport.setMicEnabled(true);
        expect(platform.micTrackEnabled, isTrue);

        expect(platform.log.where((e) => e.startsWith('mic.')), <String>[
          'mic.setEnabled(false)',
          'mic.setEnabled(true)',
        ]);
        expect(platform.log, isNot(contains('mic.stop')));
        expect(platform.log, isNot(contains('peer.close')));
        expect(platform.openMicCalls, 1);
      },
    );

    test('avant l\'ouverture du micro : sans effet et sans erreur', () async {
      await transport.setMicEnabled(false);

      expect(platform.log, isEmpty);
      expect(platform.micTrackEnabled, isTrue);
    });

    test('après stop : sans effet et sans erreur', () async {
      await transport.createOfferSdp();
      await transport.stop();
      platform.log.clear();

      await transport.setMicEnabled(false);

      expect(platform.log, isEmpty);
      expect(platform.micTrackEnabled, isTrue);
    });

    test(
      'échec de la plateforme : ne lève pas, le micro reste non coupé',
      () async {
        await transport.createOfferSdp();
        platform.micEnabledError = Exception('SDP secret v=0');

        await transport.setMicEnabled(false);

        expect(platform.micTrackEnabled, isTrue);
        expect(platform.log, isNot(contains('mic.stop')));
      },
    );
  });
}
