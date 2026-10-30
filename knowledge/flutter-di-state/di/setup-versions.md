---
id: di-setup-versions
title: get_it + injectable — versions et mise en place
tags: [di, get_it, injectable, build_runner, versions]
status: verified
updated: 2026-10-30
sources: [https://pub.dev/packages/get_it, https://pub.dev/packages/injectable, https://pub.dev/packages/injectable_generator, https://pub.dev/packages/injectable/changelog, https://pub.dev/packages/build_runner/versions]
links: [di-registration-annotations, di-micro-packages, di-testing, proj-avw-overview, proj-sk-patterns]
---
# get_it + injectable : versions et mise en place

La DI du projet repose sur **get_it** (conteneur) et **injectable** (génération du code d'enregistrement par annotations, via `build_runner`).

**Versions observées sur pub.dev (2026-10-26) :**
- `get_it` **9.3.0**. Le README affiche encore `^8.0.2` dans son exemple d'installation, il est donc obsolète.
- `injectable` **3.0.0** (Dart SDK ≥ 3.8)
- `injectable_generator` **3.1.3** (dev, Dart SDK ≥ 3.12). Il dépend de `build ^4.0.4` et `source_gen ^4.1.1`.
- injectable 2.7.0 a passé la contrainte get_it à `>=8.3.0 <10.0.0`.

```dart
// lib/di/injection.dart
final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies(String env) => getIt.init(environment: env);

// main.dart, avant runApp
configureDependencies(Environment.prod);
```
Générer le code : `dart run build_runner build -d`.

**Changements cassants de la v3 :**
- `includeMicroPackages` est supprimé. Il faut lister les modules dans `externalPackageModulesBefore/After` (→ [[di-micro-packages]]).
- `usesNullSafety` est supprimé.

**Nouveautés 2.7.x / 3.0 :**
- 2.7.0 : factories en cache (`cache: true`), qui exigent get_it ≥ 8.
- 2.7.1 : `generateAccessors` génère des getters d'extension sur GetIt.
- 3.0.0 : `allowMultipleRegistrations` autorise plusieurs enregistrements d'un même type.

## ⚠️ Pièges
- Un seul `getIt` par application. `features/ai` du saaster kit avait son propre `getIt`, ce qui crée un risque de conflit (voir proj-sk-overview).
- **`injectable_generator` 3.1.3 impose `build_runner` ≤ 2.16.1 (vérifié le 2026-10-30, Flutter 3.47.8 / Dart 3.13.7).** `injectable_generator` ≥ 3.1.3 dépend de `lean_builder ^1.2.2`, qui borne `_fe_analyzer_shared` < 106 ; `build_runner` ≥ 2.16.2 exige `analyzer ^14.3`, donc `_fe_analyzer_shared` ≥ 107 : `pub get` échoue (« injectable_generator >=3.1.3 is incompatible with build_runner >=2.16.2 »). `build_runner` 2.16.1 (avec `analyzer` 14.1.0) résout ; avec lui, `bdd_widget_test` 3.0.4 et `injectable_generator` génèrent ensemble (`dart run build_runner build`). À reprendre quand `lean_builder` suit `analyzer` 14.
- **`injectable` ne sait pas enregistrer un type fonction** (`VoiceTransport Function()`) : erreur « is not a class element » pour un retour de type fonction et « Can not resolve function type » pour un paramètre non aliasé. Utiliser un `typedef` pour le paramètre d'une factory du module et enregistrer la fabrique à la main (`registerLazySingleton`) après l'`init` généré.
- Après une montée de version majeure, régénérer tout le code (`*.config.dart`) plutôt que de garder l'ancien fichier généré (précaution, opinion).
