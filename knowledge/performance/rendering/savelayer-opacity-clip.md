---
id: perf-savelayer
title: saveLayer, Opacity et clipping — coûts raster
tags: [raster, savelayer, opacity, clip, gpu]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/best-practices
  - https://docs.flutter.dev/tools/devtools/performance
links: [perf-repaint-boundary, perf-profile-mode-devtools]
---
# Un raster lent vient presque toujours de saveLayer, de l'opacité ou des clips

`saveLayer()` alloue un buffer hors écran et peut forcer un changement de render target GPU, ce qui coûte cher sur mobile.

- Widgets qui peuvent déclencher `saveLayer` : `ShaderMask`, `ColorFilter`, `Chip` (si `disabledColorAlpha != 0xff`), `Text` avec `overflowShader`.
- `Opacity` dans une animation : la doc conseille `AnimatedOpacity` ou `FadeInImage` ; pour une forme simple, une couleur semi-transparente (si pas de recouvrement).
- Le clip par défaut est `Clip.none`. `Clip.antiAliasWithSaveLayer` est le plus cher. Pour des coins arrondis, préférer `borderRadius` à un `ClipRRect`.
- Les ombres et l'élévation (« physical shape ») coûtent aussi ; les réserver aux feuilles plutôt qu'à de grands groupes (opinion).

**Diagnostic DevTools :** dans Performance > *More debugging options*, désactiver *Render Clip / Opacity / Physical Shape layers* ; si le temps raster chute, la cause est trouvée. Le switch `PerformanceOverlayLayer.checkerboardOffscreenLayers` (vue Performance) montre les `saveLayer`. Éviter aussi le clip dans une animation : pré-clipper l'image.

## ⚠️ Pièges
- Un halo flou (`BackdropFilter`/`ImageFilter.blur`) animé derrière l'orbe vocal est typiquement très coûteux. À profiler sur un Android bas de gamme et sur le web (opinion).
