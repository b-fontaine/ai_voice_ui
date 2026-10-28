---
id: ds-widgetbook-versions
title: Widgetbook — 3.25.0 stable, le projet épingle la 4.0.0-beta.14
tags: [widgetbook, versions, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/widgetbook/versions, https://pub.dev/packages/widgetbook/changelog, https://pub.dev/packages/widgetbook_annotation/changelog, https://pub.dev/api/packages/widgetbook_generator, https://pub.dev/api/packages/widgetbook]
links: [adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-setup, ds-widgetbook-4-beta, ds-widgetbook-setup, ds-widgetbook-api-history]
---
# Widgetbook : la stable est 3.25.0, le projet utilise la 4.0.0-beta.14

État sur pub.dev au 2026-10-28 :
- **stable (`latest`) : `widgetbook 3.25.0`** (2026-06-25, Flutter >=3.44) ;
- **préversion : `4.0.0-beta.14`** (2026-09-11, Dart >=3.10.0 <4.0.0, Flutter >=3.38.0), accompagnée de `widgetbook_cli 4.0.0-beta.14` (Dart >=3.11).

Packages compagnons de la 3.25.0 (Dart >=3.10, Flutter >=3.44) :
- `widgetbook_annotation 3.11.0` (2026-02-18, Dart >=3.10) ;
- `widgetbook_generator 3.24.0` (2026-06-08, Dart >=3.10, préversions 4.0.0-alpha.x) ;
- `widgetbook_cli 3.15.0` (2026-06-08, **Dart >=3.11**).
Ils ne servent pas en v4 : générateur et tests y sont fusionnés dans `widgetbook` ([[ds-widgetbook-4-setup]]).

## Règle du projet (décision du 2026-10-28)
- Le catalogue utilise **`widgetbook: 4.0.0-beta.14`, épinglé en version exacte** (sans `^`) ([[adr-0008-ds-widgetbook-4-beta]]). La CLI, si on l'utilise, suit le même numéro (opinion).
- Raison : le projet est une démo de talk Flutter GenUI, et la v4 documente le catalogue GenUI. Le porteur assume cette avance de phase.
- Chaque montée de bêta passe par une PR dédiée, après lecture du CHANGELOG de la branche `v4`.
- La **3.25.0 reste la stable** et sert de repli. Les notes 3.x (setup, knobs, addons, api-history) restent une référence.

## ⚠️ Pièges
- Beaucoup d'articles et d'exemples de 2023-2024 utilisent des API dépréciées depuis : DeviceFrameAddon, AccessibilityAddon, WidgetbookCloudIntegration. Voir [[ds-widgetbook-api-history]].
- Les exemples v4 antérieurs à la beta.7 ne compilent plus ([[ds-widgetbook-4-beta]]).
- Revérifier sur pub.dev avant chaque nouveau chantier : l'information est datée.
