---
id: proj-sk-patterns
title: septeo_saaster_kit — patterns réutilisables et pièges
tags: [project, di, routing, bdd, pattern, anti-pattern]
status: verified
updated: 2026-10-26
sources: ["~/septeo/septeo_saaster_kit (analyse locale du code, 2026-10-26)"]
links: [proj-sk-overview, di-setup-versions, test-bdd-widget-test, di-environments-order, test-bdd-app-running-fixture, arch-go-router, di-no-service-locator]
---
# Patterns réutilisables

- **DI par environnement** (`lib/injection.dart`, environnements `prod`, `preprod`, `dev`, `test`) :
  - une interface par service, des implémentations annotées `@prod @dev @preprod` ou `@test`, ordonnées par `@Order`
  - les stubs `@test` s'appuient sur `dio_mocked_responses`
  - → idéal pour stubber un runner voix ou un serveur de clés éphémères.
- **Routing modulaire :**
  - `AppRouter` est un `@singleton` qui encapsule `GoRouter.routingConfig` (`ValueNotifier<RoutingConfig>`).
  - Chaque `XxxModule` en `@singleton` appelle `addRoute` et utilise un import `deferred` en prod, un import direct en test.
- **Fixture BDD `myAppIsRunning`** :
  - fixe `Flavor.test`
  - appelle `configureDependencies(environment: test)` avec `allowReassignment`
  - nettoie `MockInterceptor` et fixe la taille de vue
- **Télémétrie :** façade OTel, navigation et lazy-load tracés.
- **Tests de `features/ai` :** fakes écrits à la main. Les classes de plateforme sont exclues via `// coverage:ignore-file`.

# Pièges
- Service locator dans le BLoC (`login_bloc.dart:14`) et `Future.delayed` utilisé pour séquencer.
- `FutureBuilder(future: initializer())` dans `build` : l'initialisation est relancée à chaque rebuild.
- `AppRouter.addRoute` ne notifie pas le `ValueNotifier`.
- `ConfigurationProd` annotée `@dev`.
- `make frontend` lance `pub upgrade --major-versions` (non déterministe).
- `.env` et `firebase-debug.log` commités à la racine.
