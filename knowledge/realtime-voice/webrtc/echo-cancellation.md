---
id: rt-echo-cancellation
title: Annulation d'écho (AEC) — WebRTC vs pipeline PCM maison
tags: [webrtc, audio, aec, echo-cancellation, gemini, barge-in]
status: sourced
updated: 2026-10-26
sources: [https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/WebRTC/initialize.html, https://pub.dev/documentation/record_platform_interface/latest/record_platform_interface/RecordConfig-class.html, https://github.com/flutter-webrtc/flutter-webrtc/blob/main/android/src/main/java/com/cloudwebrtc/webrtc/MethodCallHandlerImpl.java, https://github.com/flutter-webrtc/flutter-webrtc/blob/main/android/src/main/java/com/cloudwebrtc/webrtc/GetUserMediaImpl.java, https://github.com/flutter-webrtc/flutter-webrtc/blob/main/ios/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCMediaStream.m]
links: [rt-flutter-webrtc-audio-routing, rt-barge-in, rt-gemini-audio-vad, proj-avw-risks, perf-audio-latency]
---
# AEC : clé d'un barge-in fiable

Sans AEC, la voix de l'IA qui sort du haut-parleur revient dans le micro. Le VAD serveur la prend pour l'utilisateur, d'où des **auto-interruptions**.

**WebRTC (`flutter_webrtc`)**, d'après le code source :
- `getUserMedia({'audio': true})` applique les contraintes par défaut (echoCancellation, noiseSuppression…) à l'APM logicielle de libwebrtc. Une map `{'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}` passe par le même chemin.
- iOS : les `settings` exposés de la piste locale indiquent `echoCancellation`, `noiseSuppression` et `autoGainControl` à `YES`.
- Android : l'AEC et le NS **matériels** se règlent **globalement** dans `WebRTC.initialize(options)` (clés documentées dans la dartdoc de `initialize`, lues dans `MethodCallHandlerImpl.java`) :
  - `bypassVoiceProcessing: true` les coupe (clé aussi lue sur iOS/macOS) ;
  - `androidUseHardwareAudioProcessing` vaut `true` par défaut (effectif seulement sur SDK ≥ Q) ; `false` laisse l'APM logicielle gérer l'écho.
- L'audio distant est joué par la même pile que celle qui capte, donc la référence d'écho est disponible.

**Pipeline PCM maison** (Gemini via `firebase_ai` : `record` pour la capture, puis un lecteur PCM comme `flutter_soloud`) :
- La capture et la lecture sont deux piles séparées : l'AEC n'est pas garanti.
- Options (opinion) :
  - mode casque ;
  - mute du micro pendant que l'IA parle (on perd le barge-in) ;
  - VAD client avec seuil d'énergie ;
  - `record` : `RecordConfig(echoCancel: true)` (défaut `false`, « may not be considered on all platforms ») — sans référence de lecture commune, efficacité à tester.

## ⚠️ Pièges
- Ne jamais lancer `record` **en parallèle** de `getUserMedia` : on obtient une double capture et des conflits de session audio (bug d'ai_voice_widget, [[proj-avw-risks]]).
- `bypassVoiceProcessing: true`, utile pour la musique, casse l'AEC.
