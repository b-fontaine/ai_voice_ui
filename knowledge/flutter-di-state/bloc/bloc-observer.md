---
id: bloc-observer
title: BlocObserver — journal global des events et transitions
tags: [bloc, observability, logging, debugging]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bloc, https://bloclibrary.dev/bloc-concepts/, https://pub.dev/packages/bloc/changelog]
links: [bloc-no-cubit, bloc-naming, bloc-event-transformers, ma-otel-genai-spans]
---
# `BlocObserver` : observer tous les blocs depuis un seul endroit

Un `BlocObserver` global reçoit les hooks de cycle de vie de tous les blocs. C'est le point d'entrée naturel pour les logs, les traces OTel et le debug multi-agents.

| Hook | Paramètres | Bloc uniquement |
|---|---|---|
| `onCreate` | `BlocBase bloc` | |
| `onEvent` | `Bloc bloc, Object? event` | ✓ |
| `onChange` | `BlocBase bloc, Change change` | |
| `onTransition` | `Bloc bloc, Transition transition` (current, **event**, next) | ✓ |
| `onDone` | `Bloc bloc, Object? event, [Object? error, StackTrace? st]` | ✓ (handler terminé) |
| `onError` | `BlocBase bloc, Object error, StackTrace st` | |
| `onClose` | `BlocBase bloc` | |

```dart
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver(this._log);
  final Logger _log; // package:logging, pas debugPrint

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    _log.fine('${bloc.runtimeType} ${transition.event.runtimeType} '
        '${transition.currentState.runtimeType} -> ${transition.nextState.runtimeType}');
  }
}

void main() {
  Bloc.observer = MultiBlocObserver(observers: [AppBlocObserver(log), OtelBlocObserver()]);
}
```
- `onTransition` est appelé **avant** `onChange` et contient l'event déclencheur.
- `onDone` permet de mesurer la durée d'un handler (latence d'un tool call, par exemple).

## ⚠️ Pièges
- Logger les `runtimeType`, pas `toString()` des états : les états GenUI ou audio peuvent être énormes ou contenir des secrets (clés éphémères).
- `onDone` existe depuis bloc 9.1.0 et `MultiBlocObserver` depuis bloc 9.2.0 (exporté par `package:bloc/bloc.dart`, notifie les observers dans l'ordre de la liste).
- ai_voice_widget utilisait `debugPrint` partout (proj-avw-risks #9).
