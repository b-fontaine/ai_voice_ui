---
id: rt-flutter-webrtc-overview
title: flutter_webrtc — version et support plateformes
tags: [webrtc, flutter, packages, platforms]
status: verified
updated: 2026-10-29
sources: [https://pub.dev/packages/flutter_webrtc, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/WebRTC-class.html, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/WebRTC/initialize.html]
links: [rt-flutter-webrtc-permissions, rt-flutter-webrtc-audio-routing, rt-flutter-webrtc-gpt-live-connect, rt-echo-cancellation, proto-rtc-flutter-packages, perf-audio-packages]
---
# `flutter_webrtc`

`flutter_webrtc` est le plugin WebRTC de référence pour Flutter.
- **Version :** 1.6.3 sur pub.dev, au 2026-10-26.
- **Éditeur :** flutter-webrtc.org (vérifié).
- **Licence :** MIT.

**Plateformes :** Android, iOS, macOS, Windows, Linux et Web. Audio/vidéo, data channels et Unified-Plan sont marqués supportés partout.

**Observé le 2026-10-29 sur Linux x86_64** (Flutter 3.47.8, Impeller OpenGLES) : `flutter_webrtc` 1.6.3 compile, énumère les périphériques audio (`enumerateDevices`), capture le micro (`getUserMedia`, 1 piste audio) et produit une offre SDP Opus (`createOffer`).

C'est donc la seule brique qui couvre **les six plateformes** pour GPT-Live. À l'inverse, `firebase_ai` ne couvre ni Windows ni Linux.

**API utiles :**
- `createPeerConnection(config)`
- `navigator.mediaDevices.getUserMedia({'audio': {...}})`
- `pc.addTrack`
- `pc.createDataChannel(label, RTCDataChannelInit())`
- `createOffer` / `setLocalDescription` / `setRemoteDescription`
- `onTrack`, `onConnectionState`

**Initialisation :**
- `WebRTC.initialize({Map<String, dynamic>? options})` est facultatif ; à défaut, les réglages par défaut s'appliquent.
- Les clés d'`options` sont décrites dans la dartdoc de `initialize` : `networkIgnoreMask`, `bypassVoiceProcessing`, `androidUseHardwareAudioProcessing`, `androidAudioConfiguration`, `audioSampleRate`, `enableWARP`, `zeroPlayoutDelay`… ([[rt-echo-cancellation]]).
- `WebRTC.platformIsWeb`, `platformIsMobile`, `platformIsDesktop`… permettent de brancher les comportements par plateforme.

**Build :**
- iOS / macOS : Swift Package Manager par défaut depuis Flutter 3.44, CocoaPods sinon.
- Android : le plugin déclare `minSdkVersion` 21 ; le README conseille de monter à 23 « si nécessaire ». Java 8, règles ProGuard du plugin en release.

## ⚠️ Pièges
- iOS avec CocoaPods : ajouter `ONLY_ACTIVE_ARCH = YES` dans le `post_install` du Podfile. Le README précise que le WebRTC.xframework compilé après m104 ne supporte plus les « iOS arm devices ».
- `openai_webrtc` épingle 0.14.x, très en retard sur 1.6.x ([[rt-openai-webrtc-package]]).
