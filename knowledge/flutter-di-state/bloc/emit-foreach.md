---
id: bloc-emit-foreach
title: emit.forEach / emit.onEach pour les flux (audio, voix)
tags: [bloc, streams, audio, realtime-voice, emitter]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/documentation/bloc/latest/bloc/Emitter-class.html, https://bloclibrary.dev/tutorials/flutter-todos/, https://bloclibrary.dev/faqs/, https://github.com/felangel/bloc/blob/master/packages/bloc/lib/src/emitter.dart, https://github.com/felangel/bloc/blob/master/docs/src/content/docs/migration.mdx, https://github.com/felangel/bloc/blob/master/packages/bloc/lib/src/bloc.dart]
links: [bloc-event-transformers, bloc-no-non-serializable-state, proj-avw-voice-runners, proj-avw-risks, test-fake-async-streams, test-bloc-test]
---
# S'abonner à un `Stream` depuis un handler

Pour consommer un flux (niveau micro, état « l'IA parle », transcription, tool calls), on utilise `await emit.forEach` ou `await emit.onEach` dans un handler. On n'écrit jamais `stream.listen` à la main : le Bloc gère alors l'abonnement et l'annule à la fermeture ou quand un transformer annule le handler.

```dart
Future<void> forEach<T>(Stream<T> s,
    {required State onData(T data), State onError(Object e, StackTrace st)?});
Future<void> onEach<T>(Stream<T> s,
    {required void onData(T data), void onError(Object e, StackTrace st)?});
```
- `forEach` : chaque donnée est **mappée en un état émis**.
- `onEach` : callback libre, sans émission automatique. Utile pour plusieurs `emit` ou pour un `add` d'un autre event.

```dart
on<VoiceSessionStarted>((e, emit) async {
  emit(const VoiceState.connecting());
  await _runner.start(e.prompt);
  await emit.forEach<RunnerEvent>(
    _runner.events,                       // flux fusionné UNE fois, pas à chaque accès
    onData: (ev) => switch (ev) {
      AiSpeakingChanged(:final speaking) => speaking ? const VoiceState.speaking() : const VoiceState.listening(level: 0),
      MicLevel(:final level) => VoiceState.listening(level: level),
    },
    onError: (err, st) => VoiceState.failure('$err'),
  );
}, transformer: restartable());
```

**Pourquoi c'est crucial pour la voix :** dans ai_voice_widget, les abonnements n'étaient pas annulés et le `MergeStream` était recréé à chaque accès (proj-avw-risks #7). `emit.forEach` combiné à `restartable()` règle ces deux problèmes.

## ⚠️ Pièges
- **Ne jamais faire transiter les octets audio PCM par l'état.** Seuls des dérivés légers passent par l'état (niveau, booléens), et il faut les échantillonner (throttle à environ 30 Hz) pour ne pas reconstruire l'UI à 50–100 Hz.
- Le handler reste « en cours » tant que le flux est ouvert. En mode `sequential`, il bloque donc les events suivants du même type.
- Limites citées par la FAQ bloc : pas de pause/resume simple, un event public `Started` est nécessaire, et pas de transformer personnalisé sur les données du flux.
- Dans un handler, un `emit` après `close()` est **ignoré silencieusement** (l'emitter est annulé). C'est `add()` sur un Bloc fermé qui lève un `StateError`.
