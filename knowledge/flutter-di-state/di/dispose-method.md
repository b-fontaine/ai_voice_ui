---
id: di-dispose-method
title: injectable — @disposeMethod et cycle de vie
tags: [di, injectable, dispose, lifecycle]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable, https://pub.dev/documentation/get_it/latest/get_it/GetIt-class.html]
links: [di-registration-annotations, di-get-it-scopes, proj-avw-risks, rt-graceful-close]
---
# `@disposeMethod` : libérer les singletons

`@disposeMethod` sur une méthode d'instance indique à get_it ce qu'il doit appeler quand le singleton est retiré. Cela arrive avec `unregister`, `reset`, `popScope` ou `resetLazySingleton`.

```dart
@LazySingleton(as: IAiRunner)
class GeminiLiveRunner implements IAiRunner {
  @disposeMethod
  Future<void> dispose() async { await _session?.close(); await _audioOut.close(); }
}
// variante : @Singleton(dispose: disposeDataSource) avec une fonction top-level
```

- Dans get_it, `registerSingleton` et `registerLazySingleton` acceptent `DisposingFunc<T>? dispose`.
- `reset({bool dispose = true})` et `popScope()` appellent ces fonctions.

**Règle projet (opinion) :** séparer **`stop()`** (fin de session : micro, peer connection et socket fermés, objet réutilisable) de **`dispose()`** (fin de vie : StreamControllers fermés). Le Bloc appelle `stop()`, get_it appelle `dispose()`.

## ⚠️ Pièges
- ai_voice_widget a deux bugs ici (proj-avw-risks #1 et #2) :
  - `VoiceAi.stop()` ne fermait pas le runner.
  - `dispose()` sur un singleton empêchait tout redémarrage.
- Ne jamais disposer un objet partagé depuis `Bloc.close()` : c'est au conteneur ou au scope de le faire.
