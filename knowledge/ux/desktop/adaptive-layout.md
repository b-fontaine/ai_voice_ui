---
id: ux-desktop-adaptive-layout
title: Mise en page adaptative — classes de taille de fenêtre, densité, scrollbars
tags: [desktop, adaptive-layout, window-size-classes, visual-density, ux]
status: verified
updated: 2026-10-27
sources: [https://developer.android.com/develop/ui/compose/layouts/adaptive/window-size-classes, https://docs.flutter.dev/ui/adaptive-responsive/general, https://api.flutter.dev/flutter/widgets/MediaQuery/sizeOf.html, https://pub.dev/packages/flutter_adaptive_scaffold, https://api.flutter.dev/flutter/material/VisualDensity/adaptivePlatformDensity.html, https://docs.flutter.dev/ui/adaptive-responsive/input, https://api.flutter.dev/flutter/material/Scrollbar-class.html, https://api.flutter.dev/flutter/material/SelectionArea-class.html, https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics]
links: [ds-spacing-shape-elevation, ux-desktop-menus, perf-desktop-specifics, arch-recommended-structure]
---
# Choisir la mise en page selon la taille de fenêtre, jamais selon le type d'appareil

## Classes de largeur de fenêtre (au 2026-10-27)
| Classe | Largeur (dp) |
|---|---|
| compact | < 600 |
| medium | 600–839 |
| expanded | 840–1199 |
| large | 1200–1599 |
| extra-large | ≥ 1600 |

- Source : Android Developers. La page m3.material.io n'a pas pu être lue (404).
- Sur Android, large et extra-large demandent `supportLargeAndXLargeWidth = true`.
- Material : barre de navigation inférieure sous 600, `NavigationRail` à partir de 600. La page `NavigationRail` parle de « typically between three and five » destinations.

## Flutter
- `MediaQuery.sizeOf(context)` donne la taille de la fenêtre entière. `LayoutBuilder` donne les contraintes du parent (taille locale).
- Préférer `MediaQuery.sizeOf` à `MediaQuery.of(context).size` : le contexte ne se reconstruit que si la taille change.
- **`flutter_adaptive_scaffold` est discontinué** (dernière version 0.3.3+1). Ne pas l'adopter.
- `VisualDensity.adaptivePlatformDensity` renvoie `VisualDensity.compact`, soit `(-2, -2)`, sur desktop, et la densité par défaut ailleurs. Une unité ≈ 4 px logiques dans les composants Material (implémentation `baseSizeAdjustment`). L'exemple de la doc input prend 6 px.
- Desktop : la plupart des `Scrollable` reçoivent une `Scrollbar` via `ScrollBehavior.buildScrollbar`. `thumbVisibility: true` exige un `ScrollController` (le sien ou `PrimaryScrollController`).
- Les widgets ne sont pas sélectionnables par défaut. Envelopper le body de la route dans `SelectionArea` (barre d'outils via `contextMenuBuilder`).

## Recommandations (opinion)
- Le DS expose un `DsWindowClass` calculé depuis `MediaQuery.sizeOf`. Les slices choisissent leur layout (rail + transcript + surface GenUI en volets à partir d'expanded) sans connaître la plateforme.
- `ThemeData(visualDensity: VisualDensity.adaptivePlatformDensity)` dans le thème du DS et dans ceux de Widgetbook.
- Espacements Windows de référence : 8 epx entre boutons et entre un contrôle et son en-tête, 12 epx entre un contrôle et son libellé ([[ds-spacing-shape-elevation]]).

## ⚠️ Pièges
- Non vérifiés : `NavigationDrawer`, `SelectableText` et `SelectionContainer.disabled`.
- `thumbVisibility: true` sans `ScrollController` disponible ne respecte pas l'exigence de la doc `Scrollbar` : fournir le controller.
