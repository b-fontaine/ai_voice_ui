---
id: perf-web-renderers
title: Flutter web — renderers CanvasKit et skwasm
tags: [web, renderer, canvaskit, skwasm, wasm]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/platform-integration/web/renderers
  - https://docs.flutter.dev/platform-integration/web/wasm
  - https://docs.flutter.dev/platform-integration/web/initialization
  - https://github.com/flutter/flutter/issues/190039
links: [perf-web-wasm-build, perf-web-coop-coep, perf-web-initial-load, perf-impeller-status]
---
# Deux renderers : CanvasKit (JS) et skwasm (Wasm)

Flutter web dessine via CanvasKit ou skwasm, sur WebGL/WebGPU. Le renderer HTML n'existe plus. Un `flutter build web` classique (dart2js) utilise **toujours CanvasKit**. Un build `--wasm` choisit **skwasm** à l'exécution et retombe sur dart2js + CanvasKit si le navigateur ne convient pas.

Ces infos datent du 2026-10-26 (stable 3.47).

- Impeller **n'est pas** utilisé sur le web : le web reste sur Skia (CanvasKit/skwasm).
- skwasm peut rendre sur un thread dédié (web worker), mais seulement avec les en-têtes COOP/COEP (voir [[perf-web-coop-coep]]).
- Pour forcer un renderer, dans `flutter_bootstrap.js` :

```js
_flutter.loader.load({
  config: {
    renderer: 'canvaskit',          // ou 'skwasm'
    canvasKitVariant: 'auto',       // 'full' | 'chromium' (plus léger, Chromium seul)
    forceSingleThreadedSkwasm: false,
  },
});
```

- `verboseBuildSelection: true` affiche dans la console pourquoi un build (JS ou Wasm) a été retenu.
- À l'exécution, on détecte le build Wasm avec `const isWasm = bool.fromEnvironment('dart.tool.dart2wasm');`.

## ⚠️ Pièges
- Avec un `onEntrypointLoaded` custom, le `config` **n'est pas transmis** : il faut passer les options à `initializeEngine({...})`.
- Bug skwasm multi-thread : corruption du heap Wasm lors de layout de texte et rasterisation concurrents, puis CPU à 100 % ([flutter#190039](https://github.com/flutter/flutter/issues/190039), fermé le 2026-08-05). Présence du correctif dans 3.47.x **non vérifiée** ; une source secondaire (startdebugging.net, 2026-09) conseille le single-thread jusqu'à la 3.48. Garder `forceSingleThreadedSkwasm` comme levier de repli.
