import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'remote_audio_switch.dart';
import 'web_rtc_platform.dart';

/// Seul fichier de la slice qui touche `flutter_webrtc`. Il n'a pas de test
/// unitaire (libwebrtc natif) : son exercice réel est l'essai de la tâche de
/// Vérification ; l'analyse et la compilation du plugin passent par la porte.
///
/// Pas de `audio.format`, pas de `session.start`, pas de rendu : l'audio
/// distant est joué nativement par la pile WebRTC.
class FlutterWebRtcPlatform implements WebRtcPlatform {
  const FlutterWebRtcPlatform();

  @override
  Future<RtcMic> openMic() async => _Mic(
    await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    }),
  );

  @override
  Future<RtcPeer> createPeer() async => _Peer(
    await createPeerConnection(<String, dynamic>{
      'sdpSemantics': 'unified-plan',
    }),
  );
}

class _Mic implements RtcMic {
  _Mic(this.stream);

  final MediaStream stream;

  @override
  Future<void> setEnabled(bool enabled) async {
    for (final track in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> stop() async {
    try {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
    } finally {
      await stream.dispose();
    }
  }
}

class _Peer implements RtcPeer {
  _Peer(this._connection) {
    // Piste distante : captée à son arrivée pour pouvoir la couper.
    _connection.onTrack = (event) {
      final track = event.track;
      if (track.kind != 'audio') return;
      _remoteAudio.attach((enabled) => track.enabled = enabled);
    };
  }

  final RTCPeerConnection _connection;
  final RemoteAudioSwitch _remoteAudio = RemoteAudioSwitch();
  RTCDataChannel? _channel;

  @override
  Future<void> addMic(RtcMic mic) async {
    final stream = (mic as _Mic).stream;
    for (final track in stream.getAudioTracks()) {
      await _connection.addTrack(track, stream);
    }
  }

  @override
  Future<void> createDataChannel(String label) async {
    _channel = await _connection.createDataChannel(label, RTCDataChannelInit());
  }

  @override
  Future<String> createOfferWithGatheredCandidates(Duration iceTimeout) async {
    final gathered = Completer<void>();
    _connection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathered.isCompleted) {
        gathered.complete();
      }
    };
    await _connection.setLocalDescription(await _connection.createOffer());
    if (await _connection.getIceGatheringState() !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await gathered.future.timeout(iceTimeout);
    }
    final local = await _connection.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null) throw StateError('Description locale absente.');
    return sdp;
  }

  @override
  Future<void> setRemoteAnswer(String sdp) =>
      _connection.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async =>
      _remoteAudio.setEnabled(enabled);

  @override
  Future<void> close() async {
    try {
      await _channel?.close();
    } finally {
      await _connection.close();
    }
  }

  @override
  Future<void> dispose() => _connection.dispose();
}
