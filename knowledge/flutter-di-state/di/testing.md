---
id: di-testing
title: Tester avec get_it / injectable
tags: [di, testing, get_it, injectable, mocktail]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/get_it, https://pub.dev/documentation/get_it/latest/get_it/GetIt-class.html, https://flutter-it.dev/documentation/get_it/scopes]
links: [di-environments-order, di-no-service-locator, test-bloc-test, proj-sk-patterns, test-bdd-app-running-fixture, test-mock-boundaries-only]
---
# Tests et DI

**Principe :** un test unitaire de Bloc ou de service **n'utilise pas get_it**. On construit l'objet avec ses fakes ou mocks via le constructeur. get_it n'intervient que dans les tests d'intégration et de widget de l'app complète.

**Outils get_it 9.x :**
- `await getIt.reset({bool dispose = true})` dans `tearDown` vide tout et appelle les dispose.
- `getIt.allowReassignment = true` permet de réenregistrer un type déjà présent, pour remplacer une implémentation par un mock.
- `resetLazySingleton<T>()` recrée un lazy singleton au prochain accès.
- `pushNewScope(init: (g) => g.registerSingleton<IAiRunner>(FakeRunner()))` **masque** l'implémentation réelle le temps du test, puis `popScope()` la restaure. C'est plus propre que `allowReassignment`.

**Environnement de test injectable :**
```dart
setUp(() async {
  await getIt.reset();
  configureDependencies(Environment.test); // charge les @test (fakes)
});
```
C'est le pattern de la fixture BDD `myAppIsRunning` du saaster kit (proj-sk-patterns).

## ⚠️ Pièges
- Laisser `allowReassignment = true` en permanence masque les doubles enregistrements accidentels. Ne l'activer qu'en test.
- Oublier `reset()` entre deux tests fait fuiter l'état (singletons) d'un test à l'autre.
- Un Bloc qui appelle `getIt` en interne ne se teste qu'avec un conteneur configuré (→ [[di-no-service-locator]]).
