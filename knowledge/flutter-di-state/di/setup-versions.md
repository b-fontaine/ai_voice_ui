---
id: di-setup-versions
title: get_it + injectable — versions et mise en place
tags: [di, get_it, injectable, build_runner, versions]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/get_it, https://pub.dev/packages/injectable, https://pub.dev/packages/injectable_generator, https://pub.dev/packages/injectable/changelog]
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
- Après une montée de version majeure, régénérer tout le code (`*.config.dart`) plutôt que de garder l'ancien fichier généré (précaution, opinion).
