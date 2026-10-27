---
id: perf-web-coop-coep
title: Flutter web Wasm — en-têtes COOP/COEP pour le multi-thread
tags: [web, wasm, skwasm, headers, hosting, embedding]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/platform-integration/web/wasm
  - https://docs.flutter.dev/platform-integration/web/initialization
links: [perf-web-renderers, perf-web-wasm-build, perf-web-multi-view, proj-avw-overview]
---
# skwasm ne passe en multi-thread qu'avec COOP + COEP

Sans ces en-têtes HTTP, l'app Wasm fonctionne, mais en **single-thread** : le rendu partage le thread principal avec Dart.

| En-tête | Valeur |
|---|---|
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Embedder-Policy` | `credentialless` **ou** `require-corp` |

- Un warning console s'affiche s'ils manquent. On le masque avec `suppressMultithreadingWarning: true`.
- Pour forcer le single-thread, par exemple en cas de bug ou d'hôte non maîtrisé : `forceSingleThreadedSkwasm: true`.

## ⚠️ Pièges
- **Widget embarqué chez un tiers** (cas `ai_voice_widget` servi par CDN, voir [[proj-avw-overview]]) : ce sont les en-têtes de la *page hôte* qui comptent, et on ne les contrôle pas. Prévoir le mode single-thread comme cas nominal.
- `require-corp` bloque toute ressource cross-origin sans CORP/CORS : CDN, images, iframes de paiement, etc. `credentialless` casse moins de choses.
- COOP `same-origin` coupe `window.opener`, ce qui peut casser les popups OAuth. À tester avant activation (opinion).
