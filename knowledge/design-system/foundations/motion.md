---
id: ds-motion
title: Mouvement M3 — Durations, Easing et ressorts Expressive
tags: [motion, animation, easing, material-3, design-system]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/material/Durations-class.html, https://m3.material.io/styles/motion/easing-and-duration/tokens-specs, https://api.flutter.dev/flutter/material/Easing/standard-constant.html]
links: [ds-a11y-flutter-signals, ds-tokens-theme-extension, ds-material-ui-decoupling, ux-genui-streaming-loading]
---
# Flutter fournit les tokens M3 easing + durée dans `Durations` et `Easing`, mais M3 Expressive passe aux ressorts

## Durations (material)
| Groupe | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| `short` | 50 | 100 | 150 | 200 ms |
| `medium` | 250 | 300 | 350 | 400 ms |
| `long` | 450 | 500 | 550 | 600 ms |
| `extralong` | 700 | 800 | 900 | 1000 ms |

## Easing (material)
- Constantes : `emphasizedAccelerate`, `emphasizedDecelerate`, `standard`, `standardAccelerate`, `standardDecelerate`, `legacy*`, `linear`.
- Valeurs : `standard` = `Cubic(0.2, 0.0, 0.0, 1.0)`, `emphasizedDecelerate` = `Cubic(0.05, 0.7, 0.1, 1.0)`, `emphasizedAccelerate` = `Cubic(0.3, 0.0, 0.8, 0.15)`.
- **Pas de `Easing.emphasized`** : la spec M3 désigne `Curves.easeInOutCubicEmphasized` (un `ThreePointCubic`).

```dart
AnimatedContainer(
  duration: Durations.medium2,               // 300 ms
  curve: Curves.easeInOutCubicEmphasized,    // emphasized M3
  // ...
);
```

## M3 Expressive : ressorts
- Composants et mouvement passent à un système physique à ressorts (springs).
- Le système easing + durée sert encore pour les transitions mais **n'est plus maintenu** ; la spec invite à migrer.
- Flutter n'avait pas livré M3 Expressive au 2026-09-09 : le billet officiel parle seulement d'implémentations en cours ([[ds-material-ui-decoupling]]).

## Recommandation (opinion)
- Le DS expose ses durées et courbes nommées (une `ThemeExtension` `DsMotion`, [[ds-tokens-theme-extension]]) qui pointent vers `Durations`/`Easing`, pour pouvoir basculer plus tard vers des ressorts sans toucher aux composants.
- Respecter la demande de réduction des animations de l'OS : voir [[ds-a11y-flutter-signals]]. Animations de streaming GenUI ou de voix : courtes (`short*`/`medium*`).

## ⚠️ Pièges
- Non vérifié : valeurs des springs Expressive (stiffness/damping, `md.sys.motion.spring.*`) et leur équivalent `SpringDescription` en Flutter.
- Ne pas chercher `Easing.emphasized` : la constante n'existe pas.
