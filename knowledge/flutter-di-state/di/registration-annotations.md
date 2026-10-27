---
id: di-registration-annotations
title: injectable — @injectable, @singleton, @lazySingleton
tags: [di, injectable, lifecycle]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable, https://pub.dev/documentation/get_it/latest/get_it/GetIt-class.html, https://pub.dev/packages/get_it/changelog]
links: [di-setup-versions, di-factory-method-module, di-dispose-method, di-get-it-scopes]
---
# Annotations d'enregistrement : factory, singleton, lazy singleton

L'annotation choisie fixe la durée de vie de l'instance dans get_it.

| Annotation | Enregistrement get_it | Usage typique |
|---|---|---|
| `@injectable` / `@Injectable(as: I)` | `registerFactory` (nouvelle instance à chaque `get`) | Blocs, use cases |
| `@Injectable(cache: true)` | `registerCachedFactory` (get_it ≥ 8, injectable ≥ 2.7.0) : garde une référence faible sur la dernière instance | objets coûteux et sans état |
| `@singleton` / `@Singleton(as: I)` | `registerSingleton`, créé dès `init` | config, logger |
| `@lazySingleton` / `@LazySingleton(as: I)` | `registerLazySingleton`, créé au 1er accès | repositories, clients HTTP |

```dart
@LazySingleton(as: IAiRunner)
class OpenAiRealtimeRunner implements IAiRunner {
  OpenAiRealtimeRunner(this._keys); // dépendances résolues par le constructeur
  final EphemeralKeyClient _keys;
}

@injectable // un Bloc = toujours une factory
class VoiceSessionBloc extends Bloc<VoiceEvent, VoiceState> { ... }
```

- Toujours enregistrer **l'interface** (`as:`) pour pouvoir substituer un fake en test.
- Les dépendances passent par le constructeur. `@factoryParam` couvre au plus 2 paramètres runtime (→ [[di-factory-method-module]]).

## ⚠️ Pièges
- **Un Bloc ne doit jamais être un singleton.** `BlocProvider` le ferme au démontage, et un `add()` sur un Bloc fermé lève un `StateError`.
- Pour un service à état de session (runner voix), un singleton dont `dispose()` ferme ses StreamControllers ne redémarre pas (proj-avw-risks #2). Préférer une factory ou un scope ([[di-get-it-scopes]]).
- Depuis get_it 9.3.0, une auto-résolution circulaire d'un lazy singleton (ou d'une cached factory) lève un `StateError` explicite au lieu d'un `StackOverflowError`.
