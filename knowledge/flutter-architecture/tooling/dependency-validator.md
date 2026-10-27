---
id: arch-dependency-validator
title: dependency_validator — hygiène des pubspec en CI
tags: [tooling, pubspec, ci, workspace]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/dependency_validator]
links: [arch-pub-workspaces, arch-fsd-dart-mapping]
---
# Détecter les dépendances manquantes, inutiles ou mal classées

`dependency_validator` (v5.1.0, observée le 2026-10-26) vérifie quatre choses :

| Problème | Signification |
|---|---|
| missing | package importé mais non déclaré |
| unused | dépendance déclarée mais jamais importée |
| under-promoted | dev_dependency utilisée dans `lib/`, `bin/` ou `hook/` |
| over-promoted | dependency utilisée seulement hors de `lib/`, `bin/` et `hook/` |

Les packages qui fournissent un exécutable ou un builder auto-appliqué comptent comme utilisés.

**Lancement :**
```bash
dart pub global activate dependency_validator
dart pub global run dependency_validator          # racine : tout le workspace
dart run dependency_validator -C packages/core    # un seul membre
```

**Configuration :** fichier `dart_dependency_validator.yaml` à la racine du package, avec les clés `exclude` (globs), `ignore` (packages) et `allow_pins`. La config dans `pubspec.yaml` est dépréciée.

**Intérêt architectural (opinion) :**
- Dans un workspace FSD, la ligne `missing` est le garde-fou contre une feature qui importe une autre feature sans la déclarer.
- La ligne `unused` aurait signalé `dartz`, `retrofit` et `google_generative_ai` dans ai_voice_widget (`proj-avw-risks`).
- → À lancer en CI. Les projets Septeo n'en ont pas (`proj-sk-overview`).
