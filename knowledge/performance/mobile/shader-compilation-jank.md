---
id: perf-shader-jank
title: Jank de compilation de shaders — résolu par Impeller, SkSL obsolète
tags: [impeller, shader, jank, mobile, skia]
status: sourced
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/rendering-performance
  - https://docs.flutter.dev/perf/impeller
  - https://docs.flutter.dev/tools/devtools/performance
  - https://flutter.dev/blog/whats-new-in-flutter-3-47
links: [perf-impeller-status, perf-profile-mode-devtools]
---
# Le jank à la première animation vient de Skia ; Impeller précompile ses shaders

Impeller précompile un ensemble réduit de shaders **au build du moteur**, et non à l'exécution (doc Impeller, blog 3.47). Le saut de frame à la première exécution d'une animation, typique de Skia, disparaît donc sur iOS, sur Android Vulkan et, depuis la 3.47, sur desktop.

**Que faire si une animation saccade la première fois :**
1. Vérifier qu'on mesure en `--profile`, sur un appareil réel.
2. Vérifier qu'Impeller est actif. Sur Android, il faut API 29+ avec Vulkan ; sinon l'app est sur OpenGL/Skia.
3. Dans DevTools > Performance, les frames qui compilent un shader pour la première fois sont **marquées en rouge foncé**.

**SkSL warmup :** `flutter run --cache-sksl` et `--bundle-sksl-path` ne servaient qu'au backend Skia. `/perf/shader` redirige désormais vers rendering-performance, qui n'en parle plus et renvoie vers Impeller ; ils n'apportent rien sous Impeller. *Version exacte de leur retrait non vérifiée* (statut : sourced).

## ⚠️ Pièges
- Le web reste sur Skia (CanvasKit/skwasm), donc le premier usage d'un effet peut coûter plus cher sur le web que sur mobile.
- Les shaders custom (`FragmentProgram`) restent à charger tôt, avant l'animation critique (opinion).
