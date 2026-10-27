---
id: test-realtime-fake-runner
title: Tester le temps réel — fake du runner voix
tags: [realtime-voice, webrtc, fake, streams, voice]
status: opinion
updated: 2026-10-26
sources: []
links: [proj-avw-voice-runners, proj-avw-risks, test-mock-boundaries-only, test-fake-async-streams, test-bdd-app-running-fixture, rt-provider-abstraction, test-bloc-test]
---
# Le WebRTC reste hors des tests unitaires : on teste contre un fake de `IAiRunner`

- **Pourquoi :** `flutter_webrtc`, `record` et `flutter_soloud` passent par des plugins de plateforme, absents sous `flutter test`.
- **Principe :** tout ce qui est au-dessus de l'interface runner (orchestrateur, BLoC, outil `show_screen` vers GenUI) se teste avec un fake piloté par `StreamController`.

```dart
class FakeAiRunner implements IAiRunner {
  final _audio = StreamController<Uint8List>.broadcast();
  final _speaking = StreamController<bool>.broadcast();
  final _tools = StreamController<ToolCall>.broadcast();
  final toolResults = <String, Object?>{};
  int startCalls = 0;

  @override Stream<Uint8List> get onAudioReceived => _audio.stream;
  @override Stream<bool> get onAiSpeakingChanged => _speaking.stream;
  @override Stream<ToolCall> get onToolCall => _tools.stream;
  @override Future<void> start(String prompt, Stream<Uint8List> mic) async => startCalls++;
  // + setKey, visualizationStream (cf. contrat dans proj-avw-voice-runners) ;
  // types et signatures à aligner sur le vrai IAiRunner
  // pilotage depuis le test
  void emitSpeaking(bool v) => _speaking.add(v);
  void emitToolCall(ToolCall c) => _tools.add(c);
  @override Future<void> dispose() async {
    await Future.wait([_audio.close(), _speaking.close(), _tools.close()]);
  }
}
```

## Deux niveaux de test
1. **Au-dessus du runner :** le fake, réutilisé en unit, en widget et en BDD.
2. **Le runner lui-même :** on extrait la logique pure et on la teste en unitaire.
   - parseur d'événements (`response.output_audio.delta` et anciens noms)
   - file `session.update` tant que le DataChannel est fermé
   - construction de `function_call_output`
   - le transport (DataChannel ou WebSocket) est injecté comme `Stream<String>` en entrée et `void Function(String)` en sortie.

## Micro
On injecte un `Stream<Uint8List>` de PCM synthétique, par exemple du silence ou un fichier `.pcm` de fixture, au lieu de `getUserMedia` ou `record`.

## ⚠️ Pièges
- Les StreamController doivent être `broadcast` si plusieurs écouteurs existent (`MergeStream` du domaine).
- Ne pas oublier `dispose()` en `tearDown`, sinon les tests pendent.
- Les bugs listés dans `proj-avw-risks` sont des cas de test de régression à écrire d'abord (TDD).
