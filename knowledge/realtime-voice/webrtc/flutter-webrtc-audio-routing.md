---
id: rt-flutter-webrtc-audio-routing
title: flutter_webrtc — routage audio (haut-parleur, Bluetooth, sessions iOS/Android)
tags: [webrtc, flutter, audio, speakerphone, ios, android]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/Helper-class.html, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/AndroidAudioConfiguration-class.html, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/AppleAudioConfiguration-class.html]
links: [rt-echo-cancellation, rt-flutter-webrtc-overview]
---
# Routage audio avec `Helper` (flutter_webrtc 1.6.3)

En mode « communication », le son sort par défaut dans l'**écouteur** du téléphone. Pour un assistant vocal, on veut le haut-parleur, ou le Bluetooth s'il est connecté.

```dart
if (WebRTC.platformIsAndroid) {
  await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.communication); // AVANT la session
}
// ... après getUserMedia / connexion
if (WebRTC.platformIsMobile) {
  await Helper.setSpeakerphoneOnButPreferBluetooth(); // ou setSpeakerphoneOn(true)
}
```

**Méthodes par plateforme :**
- `setSpeakerphoneOn(bool)` et `setSpeakerphoneOnButPreferBluetooth()` : **iOS et Android uniquement**.
- `setAndroidAudioConfiguration` (presets `communication` / `media`) : à appeler **avant** la session, non modifiable ensuite.
- `clearAndroidCommunicationDevice()` : à appeler en fin de session ou à la perte du focus audio.
- `setAppleAudioConfiguration(AppleAudioConfiguration(appleAudioCategory, appleAudioCategoryOptions, appleAudioMode))` et `setAppleAudioIOMode(mode, preferSpeakerOutput:)` : iOS.
- `ensureAudioSession()` : iOS.
- `selectAudioOutput(deviceId)` : iOS/Android/macOS/Windows (dartdoc ; iOS : seulement haut-parleur ↔ périphérique préféré). `selectAudioInput(deviceId)` : natif. Sur le web, `RTCVideoRenderer.audioOutput(deviceId)`.
- `setMicrophoneMute(bool, track)` : mute d'une piste. `setMicrophoneMuted(bool)` : mute au niveau de l'audio device module (iOS/macOS/Android ; no-op ailleurs).

## ⚠️ Pièges
- Presets Android (code source) : `communication` = `AudioMode.inCommunication`, stream `voiceCall`, usage `voiceCommunication` ; `media` = `AudioMode.normal`, stream `music`, usage `media`. Que `media` dégrade l'AEC matériel n'est pas documenté (à tester). Préférer `communication` avec le haut-parleur forcé.
- Sur iOS, la session audio n'est désactivée que lorsqu'il ne reste **ni piste locale ni PeerConnection ouverte** (code natif). Bien tout fermer, sinon l'indicateur micro reste allumé.
- Desktop / web : pas d'API haut-parleur. On passe par le choix du périphérique de sortie.
