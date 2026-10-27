---
id: perf-web-profiling
title: Profiler Flutter web — Chrome DevTools Performance
tags: [profiling, web, chrome-devtools, timeline]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/web-performance
  - https://docs.flutter.dev/perf/ui-performance
links: [perf-profile-mode-devtools, perf-web-renderers, perf-web-no-isolates, perf-web-wasm-build]
---
# Sur le web, profiler avec Chrome DevTools, pas Flutter DevTools

Flutter DevTools ne se connecte pas à une app web en mode profile. Flutter (≥ 3.14) émet des événements de timeline (build, draw, GC) visibles dans le panneau **Performance** de Chrome.

```bash
flutter run -d chrome --profile   # doc : « run in profile mode »   # ajouter --wasm pour profiler le chemin skwasm
```

Pour un tracing plus fin, dans `main()` :

```dart
debugProfileBuildsEnabled = true;            // un événement par widget construit
debugProfileBuildsEnabledUserWidgets = true; // seulement les widgets de l'app
debugProfileLayoutsEnabled = true;
debugProfilePaintsEnabled = true;
```

Les événements custom passent par `Timeline` et `TimelineTask` (`dart:developer`).

**Méthode (opinion) :** profiler **les deux builds**, JS + CanvasKit et Wasm + skwasm, car Safari/iOS tombe sur JS (voir [[perf-web-wasm-build]]). Profiler aussi avec et sans COOP/COEP, ce qui donne le mode single-thread typique d'une page hôte tierce.

## ⚠️ Pièges
- Ces flags ajoutent probablement un coût notable : ne pas les laisser activés pour mesurer des temps absolus (opinion, la doc ne chiffre pas ce coût).
