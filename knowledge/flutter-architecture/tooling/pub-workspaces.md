---
id: arch-pub-workspaces
title: Pub workspaces (Dart 3.6+) pour un monorepo Flutter
tags: [dart, pub, workspace, monorepo, melos]
status: verified
updated: 2026-10-28
sources: [https://dart.dev/tools/pub/workspaces, https://pub.dev/packages/melos]
links: [arch-fsd-dart-mapping, arch-dependency-validator, arch-recommended-structure, proj-avw-overview, proj-sk-overview, di-micro-packages, ds-widgetbook-monorepo, ds-package-structure]
---
# Une seule résolution de dépendances pour N packages

Les pub workspaces existent depuis **Dart 3.6**. Ils donnent :
- **un seul** `pubspec.lock` et un seul `.dart_tool/package_config.json` à la racine ;
- des versions cohérentes entre packages ;
- moins de mémoire consommée par l'analyzer.

```yaml
# pubspec.yaml racine
name: _
publish_to: none
environment: {sdk: ^3.6.0}
workspace:
  - apps/<app>
  - packages/core
  # globs (packages/*) uniquement à partir de Dart 3.11
---
# pubspec.yaml d'un membre
environment: {sdk: ^3.6.0}
resolution: workspace
```

**Fonctionnement :**
- `dart pub get` se lance depuis n'importe où dans le dépôt.
- Pour viser un package : `dart pub -C <path> publish`.
- `dart pub workspace list` liste les membres.
- Les workspaces peuvent être imbriqués : un membre peut déclarer son propre `workspace:`.
- Un membre qui dépend d'un autre membre utilise la copie locale, qui doit respecter la contrainte de version.

**Melos (8.9.0 sur pub.dev le 2026-10-26) :**
- Depuis la 7.x, Melos s'appuie sur les pub workspaces, et sa config va sous la clé `melos:` du `pubspec.yaml` racine.
- On l'utilise uniquement pour les scripts (`test`, `analyze`, codegen par package) et le versioning.

⚠️ Pièges
- Un `pubspec.yaml` « orphelin » entre la racine et un membre fait échouer `pub get`.
- Une seule version par package dans tout le workspace : les conflits apparaissent tôt. Garder les `dependency_overrides` à la racine.
- Côté Flutter, aucune doc officielle ne donne de minimum. Déduction : Dart 3.6 est livré avec Flutter 3.27, minimum théorique ; un guide tiers conseille Flutter ≥ 3.38. Les projets Septeo l'utilisent déjà avec SDK `^3.9.2` (`proj-avw-overview`).
