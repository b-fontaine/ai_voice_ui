---
id: ds-spacing-shape-elevation
title: Espacement, formes et élévation — échelles M3, Fluent et Windows
tags: [spacing, shape, elevation, material-3, fluent, design-system]
status: verified
updated: 2026-10-27
sources: [https://m3.material.io/styles/spacing/overview, https://fluent2.microsoft.design/layout, https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics, https://m3.material.io/styles/shape/corner-radius-scale, https://m3.material.io/styles/elevation/tokens, https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-elevation.scss, https://docs.flutter.dev/release/breaking-changes/new-color-scheme-roles, https://api.flutter.dev/flutter/material/Material/surfaceTintColor.html]
links: [ds-tokens-theme-extension, ds-typography, ds-color-m3-roles, ux-desktop-adaptive-layout, ux-desktop-platform-kits]
---
# M3 espace en 8dp, Fluent en 4px ; l'élévation M3 passe par des surfaces tonales

## Espacement
- **M3** : échelle de 8dp (`space100` = 8dp), pas de 4dp. Material ne donne que des valeurs recommandées, appliquées aux marges, paddings et gaps.
- **Fluent 2** : unité de base 4px, plus 2, 6 et 10 (`size20`, `size60`, `size100`) pour le padding des icônes Fluent.
- **Windows** (epx) : 8 entre boutons, 8 entre un bouton et son flyout, 8 entre un contrôle et son en-tête, 12 entre un contrôle et son libellé, 12 entre zones de contenu, 16 entre une surface et le texte en bordure.

## Formes (corner radius)
- Échelle M3 post-Expressive, 10 niveaux : none 0, extra-small 4, small 8, medium 12, large 16, large-increased 20, extra-large 28, extra-large-increased 32, extra-extra-large 48 (dp), full.
- Les tokens material-web v0_192 n'en ont que 7 (sans large-increased, extra-large-increased, extra-extra-large).
- **Arrondi optique** pour les formes imbriquées : rayon intérieur = rayon extérieur − padding (48 − 14 = 34dp). Ne pas réutiliser le rayon du parent.

## Élévation
- Niveaux 0 à 5 = 0, 1, 3, 6, 8, 12dp (confirmés par les tokens material-web, sans unité).
- Niveau 1 : cartes, boutons elevated, banner, bottom sheet modal, chips elevated, drawer modal. Niveau 3 : dialogues, FAB, extended FAB, pickers, search. Les niveaux 4 et 5 ne sont le niveau de repos d'aucun composant.
- Depuis Flutter 3.22 stable, `surfaceTintColor` vaut `null` par défaut partout. Le fond repose sur les rôles tonaux `surfaceContainer*` ([[ds-color-m3-roles]]), et non plus sur un overlay teinté proportionnel à l'élévation.
- `Material.surfaceTintColor` n'applique d'overlay que si `useMaterial3` est vrai et la couleur ni `null` ni `Colors.transparent`.

## Recommandation (opinion)
- Grille de **4** à l'intérieur des composants (paddings, icône/libellé, densité desktop), échelle de **8** pour la mise en page (gaps entre blocs, marges de surfaces).
- Exposer espacements et rayons nommés dans une `ThemeExtension` ([[ds-tokens-theme-extension]]) ; hiérarchie par rôle de surface plutôt que par ombre.

## ⚠️ Pièges
- Non vérifié : une « baseline grid » 4dp M3, les valeurs exactes des tokens d'espacement M3 (`space050`, `space150`…) et les marges par breakpoint.
- Non retenu : tailles Windows Standard 40×40 / Compact 32×32 epx (page source redirigée).
