---
id: bloc-event-transformers
title: Event transformers (bloc_concurrency)
tags: [bloc, concurrency, transformer, voice, race-condition]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bloc_concurrency, https://engineering.verygood.ventures/development/state_management/bloc_event_transformers/, https://github.com/felangel/bloc/blob/master/packages/bloc/lib/src/bloc.dart]
links: [bloc-emit-foreach, bloc-no-cubit, test-bloc-test]
---
# Transformers : contrôler la concurrence des handlers

Par défaut, les events sont traités **en concurrence** (VGV : « handled concurrently by default », sans garantie d'ordre de fin). Le transformer s'applique **par `on<E>`** : chaque type d'event a son propre « bucket », et des types différents restent concurrents entre eux.

| Transformer (`bloc_concurrency` 0.3.0) | Comportement | Cas voix / GenUI (opinion) |
|---|---|---|
| `concurrent()` (défaut) | tout en parallèle | events indépendants et idempotents |
| `sequential()` | FIFO, un à la fois | file de tool calls à exécuter dans l'ordre, écritures d'état cumulatives |
| `droppable()` | ignore ce qui arrive pendant un traitement | double tap sur « démarrer la session », bouton connect |
| `restartable()` | annule le handler en cours et garde le dernier | `SessionStarted` (re)lancé, changement de voix ou de modèle, requête GenUI remplacée par une plus récente |

```dart
on<VoiceSessionStarted>(_onStarted, transformer: restartable());
on<VoiceToolCallReceived>(_onToolCall, transformer: sequential());
on<VoiceConnectPressed>(_onConnect, transformer: droppable());
```

Avec `restartable`, l'annulation passe par `emitter.cancel()`. Les `emit` suivants sont ignorés et un `emit.forEach` en cours est désabonné, ce qui en fait le bon couple pour les flux (→ [[bloc-emit-foreach]]).

Si aucun des quatre ne convient, écrire un `EventTransformer<E>` personnalisé (debounce, throttle via `stream_transform`/rxdart).

## ⚠️ Pièges
- `droppable` **perd** les données de l'event ignoré. Ne jamais l'utiliser pour des tool calls.
- `sequential` ajoute de la latence quand la concurrence aurait été sûre.
- Les tests deviennent non déterministes en mode concurrent. VGV conseille `await Future<void>.delayed(Duration.zero)` entre deux `add` dans `act`.
- Le code async après un `await` continue malgré l'annulation : tester `emit.isDone` avant tout effet de bord.
