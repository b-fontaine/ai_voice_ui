---
id: perf-impeller-status
title: Impeller — état par plateforme (Flutter 3.47)
tags: [impeller, android, ios, desktop, renderer, vulkan]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/impeller
  - https://flutter.dev/blog/whats-new-in-flutter-3-47
links: [perf-shader-jank, perf-desktop-specifics, perf-web-renderers]
---
# Impeller est le renderer par défaut partout, sauf sur le web

Infos de Flutter 3.47 stable, sorti le 2026-08-12, relevées le 2026-10-26. La doc indique qu'Impeller est le défaut sur iOS et Android API 29+ « depuis la 3.27 ».

| Plateforme | Défaut | Opt-out |
|---|---|---|
| iOS | Impeller, seul moteur supporté | impossible |
| Android API 29+ avec Vulkan | Impeller | possible |
| Android < 29 ou sans Vulkan | repli automatique sur OpenGL | — |
| macOS / Windows / Linux | Impeller (depuis 3.47) : Metal sur macOS, Vulkan sur Windows/Linux | temporaire |
| Web | Skia (CanvasKit/skwasm) | sans objet |

**Opt-out pour le débogage (Android, macOS, Linux, Windows) :** `flutter run --no-enable-impeller`.

**Opt-out en production sur Android**, dans `AndroidManifest.xml` sous `<application>` :

```xml
<meta-data android:name="io.flutter.embedding.android.EnableImpeller"
           android:value="false" />
```

Pour le desktop, voir [[perf-desktop-specifics]].

## ⚠️ Pièges
- Les opt-outs desktop **seront supprimés** dans une version future. Ne pas en dépendre.
- Une app peut tourner sous Impeller sur un Android récent et sous OpenGL sur un ancien. Profiler sur un appareil bas de gamme ancien (API < 29) en plus d'un appareil récent.
- Pour signaler un bug : titre préfixé `[Impeller]`, appareil, puce, et trace de performance exportée.
