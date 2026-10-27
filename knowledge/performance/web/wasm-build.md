---
id: perf-web-wasm-build
title: Flutter web — build WebAssembly (--wasm), état fin 2026
tags: [web, wasm, dart2wasm, js-interop, browser-support]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/platform-integration/web/wasm
  - https://flutter.dev/blog/whats-new-in-flutter-3-47
links: [perf-web-renderers, perf-web-coop-coep, perf-web-initial-load, proj-avw-overview]
---
# `flutter build web --wasm` : opt-in, avec fallback JS automatique

En octobre 2026, Wasm **n'est pas encore le défaut**. Le blog 3.47 dit que l'équipe y travaille. `--wasm` produit deux builds : dart2wasm + skwasm, et dart2js + CanvasKit. `flutter_bootstrap.js` choisit selon le navigateur.

```bash
flutter run -d chrome --wasm
flutter build web --wasm --source-maps   # source maps pour symboliser en prod
flutter build web --wasm --no-strip-wasm # noms de fonctions gardés, binaire ~+47 %
```

**Navigateurs, selon la doc (versions ≥ 3.50) :** Wasm exige WasmGC, les JS String Builtins et l'Exception Handling phase 4.

| Moteur | Minimum | Par défaut |
|---|---|---|
| Chromium | 137+ | activé (`wasmAllowList.blink: true`) |
| Safari / tout iOS | 26.2+ | désactivé, opt-in `webkit: true` |
| Firefox | 147+ | désactivé, opt-in `gecko: true` |

Conséquence : sans opt-in, **iOS et Safari tournent en JS + CanvasKit**. Il faut tester les deux chemins.

**Interop obligatoire :** `package:web` et `dart:js_interop`. Ne sont pas supportés : `dart:html`, `dart:js`, `dart:js_util`, `dart:web_audio`, `package:js`. Un `flutter build web` sans `--wasm` fait un *dry run* Wasm et affiche un warning non bloquant listant les imports incompatibles (désactivable avec `--no-wasm-dry-run`). `--no-deprecated-js-interop` (doc « 3.50+ ») transforme l'usage des anciennes libs en erreur.

## ⚠️ Pièges
- Le stable observé est **3.47**, alors que la doc mentionne des comportements « 3.50+ ». Vérifier le comportement avec `flutter --version` sur le canal réellement utilisé.
- Les plugins audio et WebRTC doivent être compatibles Wasm. Tester `flutter_webrtc`, `record` et `flutter_soloud` en `--wasm` avant de s'engager.
