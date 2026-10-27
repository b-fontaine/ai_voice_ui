---
id: rt-provider-abstraction
title: Abstraction fournisseur voix (runner)
tags: [pattern, architecture, clean-architecture, openai, gemini, interface]
status: opinion
updated: 2026-10-26
sources: []
links: [proj-avw-voice-runners, proj-avw-risks, rt-openai-realtime-vs-live, rt-gemini-firebase-ai-dart, rt-transcription, rt-graceful-close, test-realtime-fake-runner, di-named-implementations, arch-clean-flutter-layers, ma-flutter-event-bus]
---
# Un port `VoiceSession` commun, des adaptateurs par fournisseur

Les fournisseurs diffèrent par le transport (WebRTC ou WebSocket), le pipeline audio (géré par WebRTC ou PCM maison), l'auth et le modèle d'outils. Le domaine ne doit voir que des **événements normalisés**.

```dart
abstract interface class VoiceSession {
  Stream<VoiceEvent> get events; // Started, Transcript, Speaking(bool), Interrupted,
                                 // ToolRequest, Usage, Closed(reason), Error
  Future<void> start(VoiceSessionConfig config); // profil agent, voix, langue
  Future<void> sendToolResult(String callId, Object? result);
  Future<void> appendContext(String text, {bool speak = false});
  Future<void> setMicMuted(bool muted);
  Future<void> stop();   // graceful, réutilisable
  Future<void> dispose();
}
```

**Adaptateurs :**
- `GptLiveWebRtcSession` : flutter_webrtc, relais backend.
- `OpenAiRealtimeWebRtcSession` : legacy.
- `GeminiLiveFirebaseSession` : firebase_ai ; pas de Windows ni de Linux.
- `GeminiLiveDirectSession` : WebSocket + jeton éphémère ; nécessaire pour 3.8 et pour le desktop.

**Corrections par rapport à ai_voice_widget :**
- Config injectée (modèle, voix, région), au lieu d'être codée en dur.
- Un seul `Stream` d'événements typé, au lieu de quatre flux fusionnés à chaque accès.
- `stop()` distinct de `dispose()`.
- Une seule source micro par adaptateur.

## ⚠️ Pièges
- Ne pas trop abstraire les outils : GPT-Live délègue, Gemini appelle des fonctions. Le port expose `ToolRequest` / `sendToolResult`, et `appendContext` couvre le commentary et le thinking de GPT-Live.
