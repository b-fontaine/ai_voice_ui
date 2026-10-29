---
id: test-bloc-test
title: bloc_test — blocTest (build, seed, act, expect, verify)
tags: [bloc, bloc_test, unit, mocktail, testing]
status: verified
updated: 2026-10-29
sources: [https://pub.dev/packages/bloc_test, https://bloclibrary.dev/testing/, https://engineering.verygood.ventures/development/state_management/bloc_event_transformers/]
links: [test-bloc-mockbloc-whenlisten, test-mocktail-essentials, test-fake-async-streams, test-realtime-fake-runner, bloc-event-transformers, bloc-emit-foreach, bloc-no-cubit, di-testing, proj-avw-overview]
---
# blocTest : décrire les états émis en réponse à des events

Version observée sur pub.dev le 2026-10-26 : `bloc_test` 10.0.0, publiée le 2025-01-12. Règle recommandée : **un `blocTest` par handler** ; le Bloc est construit **directement** avec des fakes ou mocks mocktail, sans get_it ([[di-testing]]). Bloc uniquement, pas de Cubit ([[bloc-no-cubit]]).

```dart
class _MockRunner extends Mock implements IAiRunner {}
late _MockRunner runner;
setUp(() => runner = _MockRunner());

blocTest<VoiceSessionBloc, VoiceState>(
  'émet listening puis speaking quand le runner signale la parole',
  build: () {
    when(() => runner.start(any())).thenAnswer((_) async {});
    when(() => runner.events).thenAnswer((_) => Stream.fromIterable([
          const MicLevel(0.2), const AiSpeakingChanged(true)]));
    return VoiceSessionBloc(runner);
  },
  act: (b) => b.add(const VoiceEvent.started(prompt: 'p')),
  expect: () => [const VoiceState.connecting(),
                 const VoiceState.listening(level: 0.2), const VoiceState.speaking()],
  verify: (_) => verify(() => runner.start('p')).called(1),
);
```

## Paramètres
- **`build` :** crée le bloc, neuf à chaque test.
- **`setUp` / `tearDown` :** propres au test (le commun va dans ceux de `package:test`).
- **`seed` :** état de départ, appliqué avant `act`.
- **`act` :** ajoute des events.
- **`wait` :** laisse passer du temps (debounce, timers).
- **`skip` :** nombre d'états ignorés (0 par défaut).
- **`expect` :** liste ordonnée des états attendus. Le stream est fermé avant la comparaison : tout état en trop fait échouer.
- **`verify` :** assertions après `expect`, reçoit le bloc construit.
- **`errors` :** matcher des erreurs attendues après `act`.
- **`tags` :** filtrage en ligne de commande.

L'état initial se teste avec un simple `test` : `expect(bloc.state, ...)`. Les **flux** se testent avec un `StreamController` piloté dans `act`, ce qui permet de vérifier l'annulation par `restartable` ([[bloc-event-transformers]]). Côté widget : `MockBloc` + `whenListen` ([[test-bloc-mockbloc-whenlisten]]).

## ⚠️ Pièges
- Sans `==` (Equatable ou freezed), utiliser des matchers `isA<State>()`.
- En concurrence (défaut), l'ordre des états peut varier : insérer `await Future<void>.delayed(Duration.zero)` entre deux `add` (VGV).
- Un `StreamSubscription` non annulé dans `close()` laisse le test ouvert.
- **Conflit de résolution (vérifié le 2026-10-29, Flutter 3.47.8) :** `bloc_test` 10.0.0 et 9.1.7 sont inutilisables dans un workspace qui contient `build_runner` 2.16.2 (donc `bdd_widget_test`). Le SDK épingle `test_api` 0.7.12, ce qui impose `test` 1.31.x, qui exige `analyzer` < 14, alors que `build_runner` 2.16.2 exige `analyzer` ^14.3 : `flutter pub get` échoue. Repli : un helper maison qui joue les events, ferme le Bloc et renvoie les états émis (`await bloc.close()` traite les events déjà postés). À revérifier à chaque montée de SDK ou de `build_runner`.
- ai_voice_widget n'avait **aucun** test de Bloc ([[proj-avw-overview]]).
