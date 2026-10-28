---
id: ds-color-dark-contrast
title: Couleur — mode sombre et contraste élevé
tags: [color, dark-mode, high-contrast, material-3, accessibility]
status: verified
updated: 2026-10-28
sources: [https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/dynamiccolor/material_dynamic_colors.dart, https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html, https://m3.material.io/styles/color/system/how-the-system-works, https://api.flutter.dev/flutter/widgets/MediaQueryData/highContrast.html]
links: [ds-color-from-seed, ds-color-m3-roles, ds-a11y-flutter-signals, ds-a11y-wcag-contrast, ux-desktop-platform-kits]
---
# Le sombre et le contraste élevé sont des variantes du même schéma, pas des palettes à part

## Mode sombre M3 (tons MCU, branche main au 2026-10-27)
- `surface` : ton **6** en sombre, **98** en clair. Pas de noir pur (ton 0).
- `primary` : ton **80** en sombre, **40** en clair.
- Exception : la variante `monochrome` met `primary` à 100 en sombre et 0 en clair.
- Certains containers peuvent atteindre le ton 0, par exemple `surfaceContainerLowest` en sombre à contraste élevé.

## Niveaux de contraste
- M3 gère trois niveaux : standard (défaut), medium, high. Ils s'appliquent en clair comme en sombre.
- Dans Flutter : `ColorScheme.fromSeed(contrastLevel: 0 | 0.5 | 1.0)` ([[ds-color-from-seed]]).
- Un composant custom n'en profite que s'il utilise les bons rôles ([[ds-color-m3-roles]]).

## Signal plateforme
- `MediaQuery.highContrastOf(context)` = « Increase Contrast » (iOS) ou « High contrast text » (Android).
- Le flag n'est mis à jour que sur **iOS 13+ et Android API 34+**. Sans ancêtre `MediaQuery`, il renvoie `false`.

## Recommandation (opinion)
Pour une app desktop ou web, on ne peut pas compter sur ce signal seul.
- Proposer un **réglage in-app** « Contraste : système / standard / moyen / élevé ».
- Le porter par un Bloc de préférences (DI par constructeur), combiné avec `highContrastOf`.

```dart
// (opinion) résolution du niveau effectif
double contrastFor(ContrastPref pref, bool platformHigh) => switch (pref) {
      ContrastPref.system => platformHigh ? 1.0 : 0.0,
      ContrastPref.standard => 0.0,
      ContrastPref.medium => 0.5,
      ContrastPref.high => 1.0,
    };
```

## ⚠️ Pièges
- Non vérifié : aucune page m3.material.io dédiée au thème sombre (« éviter le noir pur ») n'a été trouvée. La règle repose sur les tons MCU.
- L'absence de support de `highContrast` sur desktop et web est une **déduction** des notes de plateforme, pas une affirmation de la doc.
- Vérifier chaque niveau avec des goldens ([[ds-a11y-wcag-contrast]]) : 4 thèmes (clair/sombre × standard/élevé) au minimum.
