---
id: ds-package-structure
title: Structure du package design system dans le workspace
tags: [design-system, package-structure, monorepo, fsd, widgetbook]
status: opinion
updated: 2026-10-28
sources: [https://dart.dev/tools/pub/workspaces, https://docs.widgetbook.io/quick-start]
links: [arch-recommended-structure, arch-pub-workspaces, arch-fsd-public-api, ds-atomic-design, ds-widgetbook-monorepo]
---
# Un seul package `design_system` dans `shared`, rangé par niveau atomique, avec son catalogue Widgetbook à côté

`arch-recommended-structure` place déjà le DS dans `packages/shared/design_system/` (« DS*, thème, Widgetbook »). On s'y conforme et on garde **un seul package** tant qu'aucun besoin concret n'impose de le scinder.

```
packages/shared/design_system/
├── pubspec.yaml            # resolution: workspace ; dépend de material_ui
├── lib/
│   ├── design_system.dart  # barrel public : export ... show
│   └── src/
│       ├── tokens/         # généré (DTCG → Dart), jamais édité à la main
│       ├── foundations/    # ThemeData, ThemeExtension, TextTheme, motion
│       ├── atoms/
│       ├── molecules/
│       ├── organisms/
│       └── templates/      # scaffolds et layouts adaptatifs
├── test/                   # widget tests + goldens alchemist
└── widgetbook/             # app catalogue, membre du workspace
    └── lib/                # main.dart (runWidgetbook), widgetbook.config.dart, *.stories.dart (v4, adr-0008)
```

## Règles
- **Place FSD** : couche `shared`, segment `ui`. Le DS ne dépend d'**aucune** feature, entité ni de l'app ; seuls `apps/` et `packages/features/*` le consomment.
- **API publique** : seul `design_system.dart` est importable ([[arch-fsd-public-api]]) ; `lib/src/` reste privé.
- **Tokens générés** dans `src/tokens/` ; le pipeline est hors du package Dart.
- **Pas de Bloc, pas de `get_it`, pas d'`injectable`** dans le DS : widgets de présentation purs ([[ds-atomic-design]]).
- **Widgetbook** : app Flutter séparée, comme le préconise le quick start (`flutter create widgetbook --empty`, lancé dans le répertoire de l'app ; ici, dans celui du package), déclarée membre du workspace ([[arch-pub-workspaces]]). Elle dépend du DS, jamais l'inverse. Détails : [[ds-widgetbook-monorepo]].
- Les items du catalogue GenUI restent dans `packages/features/genui_agent` et **composent** les widgets du DS.

## Quand scinder
Seulement si un consommateur a besoin des tokens sans Flutter (backend Go, web non Flutter) : extraire alors un package `ds_tokens` pur Dart. Pas avant.

## ⚠️ Pièges
- Lister le `widgetbook/` imbriqué dans le `workspace:` racine et lui donner `resolution: workspace`, comme tout membre. Non vérifié : le comportement exact de `pub get` si on l'oublie.
- Ne pas exporter tout `src/` depuis le barrel : on perd la maîtrise de l'API publique et du semver ([[ds-governance-versioning]]).
