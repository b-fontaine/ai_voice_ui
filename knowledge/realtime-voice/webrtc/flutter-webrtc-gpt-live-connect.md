---
id: rt-flutter-webrtc-gpt-live-connect
title: Connecter flutter_webrtc à GPT-Live (squelette)
tags: [webrtc, flutter, gpt-live, openai, code]
status: opinion
updated: 2026-10-28
sources: [https://developers.openai.com/api/docs/guides/voice-webrtc, https://pub.dev/packages/flutter_webrtc]
links: [rt-gpt-live-webrtc-session, rt-gpt-live-lifecycle, rt-flutter-webrtc-audio-routing, rt-graceful-close]
---
# Squelette Dart : GPT-Live via flutter_webrtc

Ce squelette transpose le flux officiel du navigateur. Il n'a pas été testé : les API `flutter_webrtc` sont réelles, mais l'assemblage est une recommandation interne (opinion).

```dart
final pc = await createPeerConnection({'sdpSemantics': 'unified-plan'});
final mic = await navigator.mediaDevices.getUserMedia({
  'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
});
for (final t in mic.getAudioTracks()) { await pc.addTrack(t, mic); }
final dc = await pc.createDataChannel('oai-events', RTCDataChannelInit()); // AVANT l'offre
dc.onMessage = (m) => _onEvent(jsonDecode(m.text));   // attendre session.started
pc.onTrack = (e) { if (e.track.kind == 'audio') _remote = e.streams.first; };

final offer = await pc.createOffer();
await pc.setLocalDescription(offer);
await _waitIceComplete(pc); // onIceGatheringState == RTCIceGatheringStateComplete, timeout 10 s
final local = await pc.getLocalDescription();
final answerSdp = await backend.createLiveSession(local!.sdp!); // relais SDP du backend applicatif
await pc.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
```

**Lecture de l'audio distant :**
- Natif : la piste distante est jouée par la pile WebRTC.
- Web : rattacher le flux à un `RTCVideoRenderer` (`srcObject`), comme dans ai_voice_widget ([[proj-avw-voice-runners]]).

**Envoi d'événements :** `dc.send(RTCDataChannelMessage(jsonEncode({...})))`. Mettre en file tant que le canal n'est pas `open` **et** que `session.started` n'est pas reçu.

## ⚠️ Pièges
- Le SDP est échangé en un seul aller-retour HTTP (pas de trickle ICE) : la doc OpenAI demande d'**attendre la fin de la collecte ICE** avant d'envoyer l'offre, et d'envoyer `localDescription` (qui contient les candidats), pas l'`offer` initiale. Le délai réel sur mobile reste à mesurer.
- Pas de `audio.format` ni de `session.start` (cf. [[rt-gpt-live-webrtc-session]]).
- Fermer dans l'ordre : `session.close`, `session.closed`, puis arrêt des pistes, `pc.close()` **puis `pc.dispose()`** (deux appels natifs distincts, [[rt-graceful-close]]), `dispose()` des renderers.
