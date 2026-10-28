---
id: ux-desktop-platform-kits
title: Kits UI par OS (fluent_ui, macos_ui) contre DS maison + conventions
tags: [desktop, fluent-ui, macos-ui, design-system, ux]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/fluent_ui, https://pub.dev/packages/macos_ui/versions, https://fluent2.microsoft.design/layout, https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics]
links: [ds-material-ui-decoupling, ux-desktop-shortcuts, ux-desktop-menus, ds-spacing-shape-elevation]
---
# Pas de kit UI par OS : un DS maison qui respecte les conventions de chaque plateforme (opinion)

## État des kits (pub.dev, au 2026-10-27)
- **fluent_ui 4.17.0** : publiée le 2026-10-19 par bdlukaa.dev (éditeur vérifié). Requiert Dart ≥ 3.8.0 et Flutter ≥ 3.32.0. **Un seul mainteneur actif.**
- **macos_ui 2.2.2** : publiée le 2025-10-19, donc environ **12 mois sans release**. Requiert Dart ≥ 3.9.2 et Flutter ≥ 3.35.0. Seule préversion : 2.0.0-beta.11, plus ancienne (environ 3 ans).

## Repères Fluent utiles sans adopter le kit
- Fluent 2 : échelle d'espacement sur une base de **4 px**. Exceptions : 2, 6 et 10 (size20, size60, size100), qui tiennent compte du padding des icônes.
- Windows : 8 epx entre boutons, et entre un bouton et son flyout. 8 epx entre un contrôle et son en-tête, 12 epx entre un contrôle et son libellé. 12 epx entre zones de contenu, 16 epx entre une surface et le texte en bordure.

## Recommandation (opinion)
- Cas visé : **un seul** DS maison (par exemple construit sur `material_ui`, découplé de Material : [[ds-material-ui-decoupling]]), catalogué dans Widgetbook et réutilisé par le catalogue GenUI.
- Deux kits par OS signifient trois rendus à maintenir et tester (goldens, Widgetbook, catalogue A2UI), avec un risque de dépendance (mainteneur unique, kit inactif).
- L'adaptation plateforme passe par le **comportement**, pas par le look :
  - raccourcis `Ctrl`/`Cmd` et ordre des modificateurs ([[ux-desktop-shortcuts]]) ;
  - `PlatformMenuBar` sur macOS, `MenuBar` ailleurs ([[ux-desktop-menus]]) ;
  - densité `adaptivePlatformDensity`, focus visuals, ordre de focus.
- À réexaminer si un client exige un rendu natif Windows 11 ou macOS strict.

## ⚠️ Pièges
- Non vérifié : l'activité du dépôt GitHub de macos_ui (issues, commits) au-delà de la date de dernière version.
- Les pages composants de Fluent 2 (Menu, Tooltip, Toolbar) n'ont pas été lues. Leurs détails ne sont pas couverts ici.
