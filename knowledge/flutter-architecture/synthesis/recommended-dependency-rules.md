---
id: arch-recommended-dependency-rules
title: Graphe de dépendances autorisé et garde-fous CI
tags: [architecture, imports, lint, ci, workspace]
status: opinion
updated: 2026-10-26
sources: [https://feature-sliced.design/docs/reference/layers, https://pub.dev/packages/import_lint, https://pub.dev/packages/dependency_validator]
links: [arch-recommended-structure, arch-import-lint, arch-dependency-validator, arch-analyzer-plugins, arch-fsd-public-api]
---
# Qui peut dépendre de qui

```
assistant_app ──► features/* ──► entities ──► shared/core
      │               │                       ▲
      └──► shared/design_system ◄─────────────┤ (ui seulement)
features/voice_agent ──► shared/realtime_transport
features/X ─╳─► features/Y        (interdit : passer par les ports d'entities)
entities ─╳─► flutter, dio, flutter_webrtc, firebase_ai, genui
```

**Règles :**
1. Une feature ne déclare jamais une autre feature dans son pubspec. La revue de PR vérifie la section `dependencies:`.
2. `entities` et `shared/core` restent en **pur Dart**, sans `flutter` (exception possible : `meta`).
3. Dans une feature :
   - `model/domain` n'importe pas `api`, `ui` ni `package:flutter` ;
   - `ui` n'importe pas `api`.
4. Aucun import de `package:x/src/...` depuis l'extérieur de `x`.
5. Dans l'app : `app → pages → widgets`, jamais à l'envers. `pages/A` n'importe pas `pages/B` : on navigue par route.

**Garde-fous, du moins cher au plus cher :**
- `analysis_options.yaml` partagé à la racine, avec `depend_on_referenced_packages`, `implementation_imports` et `always_use_package_imports` (ou `prefer_relative_imports` dans une slice : choisir l'un des deux).
- `import_lint` (plugin natif Dart 3.10+) pour les règles 2, 3 et 5.
- `dependency_validator` en CI : il détecte les imports non déclarés et les dépendances inutiles.
- Optionnel : un plugin analyzer maison `no_cross_feature_import` (`arch-analyzer-plugins`).

**CI minimale :** `dart pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `dart run import_lint` → `dependency_validator` → tests. Les projets Septeo n'exécutent aucun test en CI (`proj-sk-overview`) : c'est à corriger dès le départ.
