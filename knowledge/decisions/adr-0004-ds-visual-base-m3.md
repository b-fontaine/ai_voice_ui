---
id: adr-0004-ds-visual-base-m3
title: "ADR-0004 — Base visuelle du design system : Material 3 via material_ui"
tags: [adr, decision, design-system, material-3, desktop]
status: opinion
updated: 2026-10-28
sources: []
links: [ds-material-ui-decoupling, ux-desktop-platform-kits, ds-color-from-seed, ds-component-api, ux-desktop-shortcuts, ux-desktop-menus]
---
# ADR-0004 — Design system maison sur Material 3 (`material_ui`) et conventions de plateforme

- **Statut :** acceptée le 2026-10-28.
- **Décideur :** porteur du projet, qui retient la recommandation de l'assistant (« Ta reco est la bonne »).
- **Portée :** générique, avec contexte d'origine propre au projet (voir « Contexte d'origine (non générique) »).

## Contexte d'origine (non générique)
Les raisons techniques (une base M3 pour desktop, web et surfaces GenUI ; rôles de couleur accessibles ; fragilité des kits par OS) sont réutilisables. Sont propres au projet d'origine : « L'app cible desktop et web » et « démo pour un talk Flutter GenUI » (Contexte), « trop coûteux pour une démo » (Options écartées), « pour la démo » et « retours du talk » (Quand réexaminer).

## Contexte
- L'app cible desktop et web avec Flutter 3.47. C'est une démo pour un talk Flutter GenUI.
- Flutter 3.47 sort Material dans le package `material_ui` (1.8.0 au 2026-10-20) [[ds-material-ui-decoupling]].
- Il existe des kits par OS : `fluent_ui` 4.17.0 (un seul mainteneur) et `macos_ui` 2.2.2 (sans release depuis 12 mois) [[ux-desktop-platform-kits]].

## Options
1. Design system maison sur M3 via `material_ui`, avec les conventions desktop de chaque plateforme (raccourcis, menus, focus).
2. Un kit par OS (`fluent_ui` sur Windows, `macos_ui` sur macOS).
3. Un design system entièrement custom, sans Material.

## Décision
Option 1. Les composants `Ds*` reposent sur `material_ui`, avec des thèmes `ColorScheme.fromSeed` + `ThemeExtension`. Le comportement desktop suit les conventions Windows et macOS : raccourcis Ctrl ou Cmd, `PlatformMenuBar` sur macOS, F6 entre régions.

## Raisons
- Une seule base pour desktop, web et les surfaces GenUI : le catalogue A2UI enveloppe les mêmes `Ds*` [[ux-genui-catalog-as-ds]].
- M3 fournit les rôles de couleur accessibles, les niveaux de contraste et des tokens de typographie, de forme et de motion.
- Un kit par OS doublerait le catalogue et ne couvre pas le web. Ces kits ont aussi un risque de maintenance.

## Options écartées
- **Kits par OS :** maintenance fragile, deux catalogues, pas de web.
- **Design system sans Material :** trop coûteux pour une démo, et on perd les composants accessibles déjà faits.

## Quand réexaminer
- M3 Expressive livré officiellement dans `material_ui` (aujourd'hui seulement « en cours ») : évaluer son adoption pour la démo.
- Les retours du talk réclament un rendu natif par OS.

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
