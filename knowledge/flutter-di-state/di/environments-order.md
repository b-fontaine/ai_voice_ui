---
id: di-environments-order
title: injectable — @Environment et @Order
tags: [di, injectable, environment, testing]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/injectable]
links: [di-testing, di-named-implementations, proj-sk-patterns]
---
# `@Environment` et `@Order`

`@Environment('x')` (ou `env: [...]`) n'enregistre une classe que si l'environnement passé à `init` correspond. `@Order(n)` fixe l'ordre d'enregistrement.

```dart
// Constantes d'environnement : Environment.dev / .test / .prod (utilisées dans le README).
// On peut déclarer ses propres annotations : const preprod = Environment('preprod');

@prod @dev
@LazySingleton(as: EphemeralKeyClient)
class HttpEphemeralKeyClient implements EphemeralKeyClient {...}

@test
@LazySingleton(as: EphemeralKeyClient)
class FakeEphemeralKeyClient implements EphemeralKeyClient {...}

getIt.init(environment: Environment.test);
```

- Une classe **sans** environnement est enregistrée partout.
- Filtres : `NoEnvOrContainsAll`, `NoEnvOrContainsAny`, `SimpleEnvironmentFilter`, passés via `environmentFilter`.
- `generateForEnvironments` (option de `@InjectableInit`, injectable ≥ 2.5.1) limite le code généré à certains environnements.
- **`@Order(n)`** ou `@Injectable(order: n)` : valeur négative = enregistré avant tout le reste, positive = après tout le reste, 0 par défaut (sinon injectable trie selon les dépendances). Sert à forcer l'ordre d'enregistrement quand le tri automatique ne suffit pas.

Le saaster kit utilise ce pattern (prod / preprod / dev / test + `@Order`) pour ses stubs `@test` (proj-sk-patterns). C'est le modèle à reprendre pour stubber un runner voix ou le serveur de clés éphémères.

## ⚠️ Pièges
- Une annotation d'environnement erronée passe la compilation sans erreur, par exemple `ConfigurationProd` annotée `@dev` dans le saaster kit. Ajouter un test qui vérifie `getIt<Config>() is ConfigurationProd` en prod.
