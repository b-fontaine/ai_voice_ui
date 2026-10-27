---
id: test-bdd-app-running-fixture
title: Fixture « the app is running » (myAppIsRunning)
tags: [bdd, fixture, di, injectable]
status: opinion
updated: 2026-10-26
sources: []
links: [proj-sk-patterns, test-bdd-hooks-steps, test-mock-boundaries-only, test-realtime-fake-runner, di-environments-order, di-testing]
---
# Un seul step d'amorçage qui démarre l'app réelle avec la DI de test

Repris de septeo_saaster_kit (`proj-sk-patterns`) : le step généré `the_app_is_running.dart` remplace le step prédéfini et démarre la **vraie** app, avec les frontières remplacées par des fakes.

```dart
Future<void> theAppIsRunning(WidgetTester tester) async {
  FlavorConfig.set(Flavor.test);
  getIt.allowReassignment = true;
  await configureDependencies(environment: Environment.test);
  // frontières : fakes réutilisés par les steps métier
  getIt.registerSingleton<IAiRunner>(FakeAiRunner());
  getIt.registerSingleton<A2uiTransport>(FakeA2uiTransport.fromFixtures());
  MockInterceptor.clear();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}
```

## Points clés
- **DI :** l'environnement `@test` d'injectable fournit les stubs, comme `dio_mocked_responses` dans saaster-kit.
- **Récupération des fakes :** les steps métier les relisent via `getIt<IAiRunner>() as FakeAiRunner`.
- **Taille de vue fixe :** garantit des goldens et des layouts déterministes.

## ⚠️ Pièges
- Sans `getIt.reset()` dans `Hooks.afterEach` (cf. `test-bdd-hooks-steps`), l'état fuit d'un scénario à l'autre.
- Avec un fake runner qui émet en continu (onde audio), `pumpAndSettle` ne se stabilise jamais. Utiliser `pump(duration)`.
- `FlavorConfig`, `MockInterceptor` et `configureDependencies` viennent de saaster-kit : à adapter aux noms du projet.
