---
id: ds-color-harmony
title: Couleur — harmonies, HCT et harmonize
tags: [color, color-harmony, hct, material-color-utilities, oklch]
status: sourced
updated: 2026-10-28
sources: [https://en.wikipedia.org/wiki/Harmony_(color), https://m3.material.io/styles/color/system/how-the-system-works, https://m3.material.io/styles/color/advanced/adjust-existing-colors, https://github.com/material-foundation/material-color-utilities, https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/scheme/scheme_tonal_spot.dart, https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/blend/blend.dart, https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/temperature/temperature_cache.dart, https://www.w3.org/TR/css-color-4/]
links: [ds-color-from-seed, ds-color-m3-roles, ds-tokens-dtcg-theming, ds-tokens-figma-sources]
---
# M3 ne choisit pas une harmonie sur le cercle : il dérive les accents d'une graine en HCT

## Harmonies classiques (source secondaire : Wikipedia)
- **Complémentaires :** opposées sur le cercle, contraste maximal.
- **Triade :** trois couleurs équidistantes.
- **Split-complémentaire :** une complémentaire remplacée par ses deux voisines analogues.
- **Analogue :** une racine et deux voisines ou plus. C'est l'harmonie la plus stable.

## Ce que fait M3 (Material Color Utilities)
- **HCT** (hue, chroma, tone) repose sur CAM16 et L*. Ton 0 (noir) à 100 (blanc), teinte 0-360, chroma plafonnée vers 120 en pratique.
- `SchemeTonalSpot` (branche main au 2026-10-27) : primaire = teinte de la graine, chroma 36 ; secondaire = même teinte, chroma 16 ; tertiaire = teinte +60°, chroma 24 ; neutral chroma 6 ; neutralVariant chroma 8.
- `TemperatureCache.analogous({count = 5, divisions = 12})` et `complement` raisonnent en température (chaud/froid), pas en simple rotation de teinte.
- MCU est publié en Dart sur pub.dev (`material_color_utilities`). Modules : blend, contrast, dislike, dynamiccolor, hct, palettes, quantize, scheme, score, temperature, utilities.

## Couleurs statiques et marque
- **harmonize** (optionnel) rapproche la teinte d'une couleur statique (succès, avertissement…) de la primaire. L'amplitude reste limitée : un rouge reste rouge.
- `Blend.harmonize(designColor, sourceColor)` limite la rotation à `min(différence × 0.5, 15°)`.
- M3 déconseille d'harmoniser ce qui doit rester strictement constant, comme une marque.
- Pour des couleurs statiques de marque, M3 propose de définir son **propre schéma de base** dans le Theme Builder : primary, secondary, tertiary, neutral, neutral variant.

```dart
// (opinion) exemple d'usage ; seule la signature Blend.harmonize est sourcée
import 'package:material_color_utilities/material_color_utilities.dart';
final success = Color(Blend.harmonize(0xFF2E7D32, seed.toARGB32()));
```

## OKLCH pour concevoir une palette (CSS Color 4)
`oklch(L C H)` : L de 0 % à 100 % (0.0 à 1.0) ; pour C, 100 % = 0.4 et C ne dépasse pas 0.5 en pratique. Oklab est plus uniforme que CIE Lab. En HSL, changer la teinte change la luminosité perçue.

## Recommandation (opinion)
- Marque figée → schéma de base custom ; couleurs métier → `harmonize` vers la primaire, exposées en `ThemeExtension`.
- Pour les rampes conçues à la main (tokens Figma), raisonner en OKLCH ou HCT, jamais en HSL.

## ⚠️ Pièges
- Constantes MCU lues sur la branche main : les versions récentes (spec 2025) peuvent déléguer ailleurs. Revérifier avant de figer des chiffres.
- Non vérifié : la version de `material_color_utilities` embarquée par Flutter 3.47, et un équivalent natif de `harmonize` dans le SDK Flutter.