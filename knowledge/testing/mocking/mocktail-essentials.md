---
id: test-mocktail-essentials
title: mocktail — API essentielle
tags: [mocktail, mock, api]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/mocktail]
links: [test-mocktail-vs-mockito, test-bloc-test]
---
# Stubber, vérifier, capturer avec mocktail 1.0.5

```dart
class MockKeyRepository extends Mock implements EphemeralKeyRepository {}
class FakeSessionConfig extends Fake implements SessionConfig {}

setUpAll(() => registerFallbackValue(FakeSessionConfig())); // une fois par type

test('demande une clé avec la config de session', () async {
  final repo = MockKeyRepository();
  when(() => repo.fetchKey(any(), model: any(named: 'model')))
      .thenAnswer((_) async => 'ek_test');

  await VoiceSession(repo).start();

  final captured = verify(() => repo.fetchKey(captureAny(), model: 'gpt-live-1'))
      .captured;
  expect(captured.single, isA<SessionConfig>());
});
```

- **`when(() => ...)` :**
  - `thenReturn` pour une valeur synchrone
  - `thenAnswer((_) async => ...)` pour un `Future` ou un `Stream`
  - `thenThrow` pour une erreur
- **`any()` / `any(named: 'x')` :** matchers d'arguments. Un argument nommé exige `named:`.
- **`registerFallbackValue` :** obligatoire pour utiliser `any()` sur un type non primitif. On l'appelle une fois par type, dans `setUpAll`.
- **`verify(...).called(n)` :** une interaction vérifiée est exclue des vérifications suivantes (README). `verifyNever` pour l'absence d'appel.
- **`captureAny()` :** récupère les arguments via `.captured`.

## ⚠️ Pièges
- `thenReturn` avec un `Future` ou un `Stream` lève une `ArgumentError` : utiliser `thenAnswer`.
- Une méthode non stubbée renvoie `null` : avec un type de retour non nullable (ex. `Future<void>`), on obtient `type 'Null' is not a subtype of ...`.
- Méthodes d'extension : impossibles à stubber ou vérifier (appel direct de l'extension réelle).
- Le nom de modèle `gpt-live-1` reprend les notes `rt-` ; ai_voice_widget utilise `gpt-realtime-1.5` (`proj-avw-voice-runners`). En vrai code, le modèle vient de la configuration, pas d'un littéral.
