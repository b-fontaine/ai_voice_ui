---
id: di-factory-method-module
title: injectable — @module, @factoryMethod, @preResolve, @factoryParam
tags: [di, injectable, third-party, async]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable]
links: [di-registration-annotations, di-setup-versions]
---
# Construire ce qu'on ne peut pas annoter

Ces annotations servent à construire les types tiers, les objets asynchrones et les constructeurs non standard.

- **`@module`** : classe abstraite dont chaque getter ou méthode devient un enregistrement. On y place les types tiers (Dio, SharedPreferences, `FirebaseAI`, `AudioRecorder`…).
- **`@preResolve`** : attend le `Future` pendant `init` et enregistre la valeur résolue. `init` devient alors `Future`, il faut donc `await configureDependencies()`.
- **`@factoryMethod`** : désigne le constructeur nommé, la factory ou la méthode statique à utiliser. Une méthode statique qui renvoie un `Future` donne une factory async.
- **`@factoryParam`** : paramètre fourni à l'appel (au plus 2), via `getIt<T>(param1: ...)`.
- **`@PostConstruct()`** : méthode appelée après la construction (sync ou async).

```dart
@module
abstract class ThirdPartyModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @lazySingleton
  Dio dio(AppConfig c) => Dio(BaseOptions(baseUrl: c.apiBaseUrl));
}

@injectable
class Repo {
  @factoryMethod
  Repo.from(Service s);
}
```

## ⚠️ Pièges
- `@preResolve` retarde le premier frame. Le réserver à ce qui est indispensable au démarrage, et charger le reste en lazy.
- `@factoryParam` pour un Bloc pousse à appeler `getIt` dans le widget. Préférer un événement `Started(param)`.
