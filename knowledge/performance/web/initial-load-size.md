---
id: perf-web-initial-load
title: Flutter web — taille initiale, deferred imports, cache
tags: [web, deferred-loading, bundle-size, caching, startup]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/deferred-components
  - https://docs.flutter.dev/platform-integration/web/wasm
  - https://docs.flutter.dev/platform-integration/web/faq
  - https://docs.flutter.dev/platform-integration/web/initialization
  - https://docs.flutter.dev/deployment/web
  - https://docs.flutter.dev/perf/app-size
links: [perf-web-wasm-build, perf-web-renderers, perf-web-multi-view]
---
# Réduire le premier chargement : imports différés et cache par hash

Le premier chargement télécharge le code Dart compilé **plus** le moteur (CanvasKit ou skwasm). Pour l'alléger :

1. **Imports différés**. En JS, chaque bibliothèque différée devient un fichier `*.js` séparé.

```dart
import 'genui_surface.dart' deferred as genui;
Future<void> openGenUi() async {
  await genui.loadLibrary(); // appeler tôt pour précharger
  // utiliser genui.* seulement après
}
```

2. **Wasm différé** (expérimental, flag du canal main mentionné dans le blog 3.47) : `flutter build web --wasm --enable-wasm-deferred-loading`. On personnalise le chargement des modules via `wasmDeferredModulesLoader` dans le bootstrap.
3. **`canvasKitVariant: 'chromium'`** : variante plus légère, à réserver aux cibles 100 % Chromium.
4. **Cache** : `--web-content-hash` (doc « 3.50+ ») hashe les entrypoints et `assets/**`. Les fichiers hashés passent en `immutable`, tandis que `index.html` et `flutter_bootstrap.js` sont en `max-age=0, must-revalidate`.
5. Le service worker de cache n'est plus généré par défaut. Pour du offline, utiliser Workbox par exemple, alimenté par `build/web/precache_manifest.json` (généré avec `--web-content-hash`).

Candidats au différé dans notre app : le catalogue GenUI et les écrans rarement ouverts. Le **runner voix** doit être prêt dès le premier geste utilisateur (opinion).

## ⚠️ Pièges
- `--web-content-hash` ne supporte **pas encore** les imports différés (`deferred as`), ni en dart2js ni en dart2wasm : les points 1-2 et 4 sont pour l'instant incompatibles (doc deployment/web).
- `--analyze-size` ne couvre pas le web (apk/appbundle/ios/desktop uniquement).
- Ne pas coder `main.dart.js` en dur dans un bootstrap custom : utiliser `{{flutter_build_config}}`.
