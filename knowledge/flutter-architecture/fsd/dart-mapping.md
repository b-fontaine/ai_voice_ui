---
id: arch-fsd-dart-mapping
title: Adapter FSD à Flutter/Dart — packages, barrels, lints
tags: [fsd, flutter, dart, workspace, lint]
status: opinion
updated: 2026-10-26
sources: [https://feature-sliced.design/docs/reference/layers, https://dart.dev/tools/pub/workspaces, https://pub.dev/packages/import_lint]
links: [arch-fsd-layers, arch-fsd-public-api, arch-pub-workspaces, arch-import-lint, arch-dependency-validator, arch-clean-fsd-combo]
---
# Trois niveaux d'application de la règle d'import en Dart

Il n'existe pas d'outillage FSD officiel pour Dart : Steiger cible JS/TS, et aucun guide Flutter-FSD officiel n'a été trouvé le 2026-10-26. On compose donc trois mécanismes.

| Frontière FSD | Mécanisme Dart | Garde-fou |
|---|---|---|
| couche / slice importante | **package** d'un pub workspace | `dependencies:` du pubspec + lint `depend_on_referenced_packages` + `dependency_validator` |
| public API de slice | fichier de librairie + `lib/src/` privé | lint `implementation_imports`, `export ... show` |
| segments dans une slice et couches dans un même package | dossiers | `import_lint` (règles `target`/`from`/`except`) |

**Mapping des couches :**
- `app` : le package Flutter exécutable (`apps/<app>`) : `main_*.dart`, DI racine, `GoRouter`, thème.
- `pages` et `widgets` : dans le package app (pages first), ou en packages si réutilisés par plusieurs apps.
- `features` : un package par feature à fort enjeu (agent voix, agent GenUI…).
- `entities` : un package `domain` (une slice = un dossier), en pur Dart.
- `shared` : les packages `core` (Result, logging, config) et `design_system`.

**Noms :** les slices s'écrivent en `snake_case` (convention de nommage Dart des packages et fichiers), pas en kebab-case.

⚠️ Pièges
- Dans un workspace, un seul `package_config.json` est partagé : un import vers un package non déclaré peut donc se **résoudre quand même**. C'est une déduction de la doc pub, à vérifier. Activer `depend_on_referenced_packages` et lancer `dependency_validator` en CI.
- Trop de packages, c'est de la friction (codegen, versions). Viser 5 à 10 packages, pas un par slice.
