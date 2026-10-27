---
id: rt-gemini-firebase-ai-dart
title: firebase_ai (Dart) — API Live
tags: [gemini, firebase-ai-logic, dart, flutter, websocket, packages]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/firebase_ai, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/LiveSession-class.html, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/LiveGenerationConfig-class.html, https://firebase.google.com/docs/ai-logic/live-api?hl=en, https://pub.dev/packages/firebase_ai/changelog]
links: [rt-gemini-live-models, rt-gemini-function-calling, rt-gemini-session-limits, rt-gemini-audio-vad]
---
# `firebase_ai` : Live API en Dart

**Version :** `firebase_ai` 5.1.0 sur pub.dev, au 2026-10-26.
**Plateformes :** Android, iOS, macOS, web. **Pas de Windows ni de Linux.**
**Transport :** WebSocket avec état (pas de WebRTC).
**Fabriques :** `FirebaseAI.googleAI()` (Developer API) et `FirebaseAI.agentPlatform()` (ex-`vertexAI`, renommée en 3.15.0).

```dart
final model = FirebaseAI.googleAI().liveGenerativeModel(
  model: 'gemini-3.1-flash-live-preview',
  liveGenerationConfig: LiveGenerationConfig(
    responseModalities: [ResponseModalities.audio],
    inputAudioTranscription: AudioTranscriptionConfig(),
    outputAudioTranscription: AudioTranscriptionConfig(),
    contextWindowCompression: ContextWindowCompressionConfig(/* slidingWindow */),
    // realtimeInputConfig: RealtimeInputConfig(automaticActivityDetection: ActivityDetectionConfig(...)),
  ),
  tools: [...],            // fixés à la création du modèle
);
final session = await model.connect(/* sessionResumption: SessionResumptionConfig(...) */);
unawaited(_listen(session.receive()));   // boucle de réception EN PARALLÈLE
await session.sendAudioRealtime(InlineDataPart('audio/pcm', chunk));
```

**`LiveSession` :**
- envoi temps réel : `sendAudioRealtime`, `sendVideoRealtime`, `sendTextRealtime`
- VAD manuel : `sendStartActivityRealtime`, `sendStopActivityRealtime`
- `send(input:, turnComplete:)`, `sendToolResponse(List<FunctionResponse>)`
- `receive()`, `resumeSession(sessionResumption:)`, `close()`

**Messages reçus :**
- `LiveServerContent` : `modelTurn`, `turnComplete`, `interrupted`, `inputTranscription`, `outputTranscription`
- `LiveServerToolCall`, `LiveServerToolCallCancellation`
- `GoingAwayNotice`, `SessionResumptionUpdate`

## ⚠️ Pièges
- L'exemple officiel enchaîne deux `await for` : la réception ne démarre qu'à la fin de l'enregistrement. Il faut lancer `receive()` en parallèle.
- La v5.1.0 n'expose ni `behavior: NON_BLOCKING` sur `FunctionDeclaration`, ni `scheduling` sur `FunctionResponse` (voir [[rt-gemini-function-calling]]).
- Pas de `UsageMetadata` côté Firebase pour le Live, et pas de Count Tokens.
- À partir du 2026-11-02, Firebase App Check sera **obligatoire** pour Firebase AI Logic.
- Le micro et le haut-parleur sont hors du SDK : `record` + lecteur PCM, avec un AEC à gérer soi-même ([[rt-echo-cancellation]]).
