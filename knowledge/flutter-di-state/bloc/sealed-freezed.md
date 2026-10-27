---
id: bloc-sealed-freezed
title: Events et states scellés avec freezed
tags: [bloc, freezed, sealed, pattern-matching]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/freezed, https://bloclibrary.dev/naming-conventions/]
links: [bloc-state-modeling, bloc-naming, bloc-no-cubit, proj-avw-overview, arch-freezed]
---
# Events et states en `sealed class` + `@freezed`

Events et states sont des **unions scellées** freezed (freezed 4.0.3). Le compilateur vérifie l'exhaustivité des `switch`, et `==`/`copyWith` sont générés.

```dart
@freezed
sealed class VoiceEvent with _$VoiceEvent {
  const factory VoiceEvent.started({required String sessionId}) = VoiceStarted;
  const factory VoiceEvent.micToggled() = VoiceMicToggled;
  const factory VoiceEvent.stopRequested() = VoiceStopRequested;
}

@freezed
sealed class VoiceState with _$VoiceState {
  const factory VoiceState.idle() = VoiceIdle;
  const factory VoiceState.listening({required double level}) = VoiceListening;
  const factory VoiceState.speaking() = VoiceSpeaking;
  const factory VoiceState.failure(String message) = VoiceFailure;
}

on<VoiceStarted>(_onStarted);   // un handler par sous-type

// UI : switch exhaustif (pattern matching Dart 3)
return switch (state) {
  VoiceIdle() => const MicButton(),
  VoiceListening(:final level) => Waveform(level),
  VoiceSpeaking() => const SpeakingIndicator(),
  VoiceFailure(:final message) => ErrorBanner(message),
};
```

- Le README freezed recommande `switch` plutôt que `when`/`map` (helpers hérités).
- `on<VoiceStarted>` repose sur les sous-types nommés (`= VoiceStarted`).

## ⚠️ Pièges
- Sans `sealed`, le `switch` n'est plus exhaustif et un nouvel état passe inaperçu.
- Ne pas mettre de logique dans les events : ce sont des données immuables.
- `==` profond sur de gros payloads (buffers audio) coûte cher et ces données n'ont rien à faire dans l'état (→ [[bloc-no-non-serializable-state]]).
