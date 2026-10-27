---
id: rt-flutter-webrtc-permissions
title: flutter_webrtc — permissions micro par plateforme
tags: [webrtc, flutter, permissions, ios, android, macos, web]
status: sourced
updated: 2026-10-26
sources: [https://pub.dev/packages/flutter_webrtc, https://docs.flutter.dev/platform-integration/macos/building]
links: [rt-flutter-webrtc-overview]
---
# Permissions micro (voix seule)

Configuration par plateforme pour une app voix seule, sans caméra.

| Plateforme | À déclarer |
|---|---|
| iOS | `NSMicrophoneUsageDescription` dans `Info.plist`. Ajouter `NSCameraUsageDescription` seulement si on utilise la vidéo. |
| Android | `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`. Pour le Bluetooth : `BLUETOOTH` / `BLUETOOTH_ADMIN` avec `maxSdkVersion="30"`. |
| macOS | `NSMicrophoneUsageDescription`. Entitlements `com.apple.security.device.audio-input` (Hardened Runtime) et `com.apple.security.network.client`. Ajouter `com.apple.security.device.microphone` sous App Sandbox. Mettre les mêmes entrées dans `DebugProfile` **et** `Release`. |
| Web | Contexte sécurisé (HTTPS) ; c'est le navigateur qui affiche la demande d'accès au micro lors de `getUserMedia`. |
| Windows / Linux | Pas de manifeste spécifique relevé dans la doc. |

Statut : la partie iOS/Android vient du README officiel. La partie macOS vient de la doc Flutter desktop et de guides tiers (LiveKit, Metered) : le README de flutter_webrtc ne la détaille pas.

## ⚠️ Pièges
- Sans `network.client`, l'app macOS échoue avec « Connection failed » : ni signalisation HTTP ni ICE.
- Sur Android, demander `RECORD_AUDIO` à l'exécution (par exemple avec `permission_handler`) **avant** `getUserMedia` améliore l'UX (opinion).
- Web : Safari exige souvent un geste utilisateur avant de lancer la lecture audio. Démarrer la session depuis un bouton (opinion).
