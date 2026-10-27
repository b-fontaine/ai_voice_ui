---
id: perf-avoid-rebuilds
title: Éviter les rebuilds — const, setState bas, child réutilisé
tags: [rebuild, const, widgets, build, best-practice]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/best-practices
links: [perf-bloc-scoped-rebuilds, perf-repaint-boundary, perf-audio-visualizer-60hz]
---
# Un rebuild coûte ce qu'il reconstruit : réduire la portée, réutiliser les instances

Quand le framework retrouve la **même instance** de widget, il ne reconstruit pas son sous-arbre. Les `const` et le pattern `child` exploitent ce comportement.

**Règles (doc officielle, page de la 3.47) :**
- Pas de travail coûteux dans `build()` : il est rappelé souvent.
- Appeler `setState()` sur le sous-arbre **le plus bas** qui change.
- Découper en petits `StatelessWidget` plutôt qu'en méthodes helper `_buildX()`.
- Passer la partie statique en `child` aux builders animés :

```dart
AnimatedBuilder(
  animation: controller,
  child: const Logo(),                    // construit une seule fois
  builder: (context, child) =>
      Transform.rotate(angle: controller.value, child: child),
);
```

- Les constructeurs `const` (et le lint `prefer_const_constructors`) produisent des instances canoniques : même instance, donc sous-arbre sauté au rebuild (règle Dart, non citée telle quelle par la page).
- Ne **pas** surcharger `operator ==` sur les widgets : risque de comportement en O(N²). Seule exception de la doc : widgets feuilles rarement reconfigurés.

**Mesurer :** DevTools > Performance > *Track Widget Builds*.

## ⚠️ Pièges
- `const` n'aide pas un widget qui lit `Theme.of` ou `MediaQuery.of` : il sera rebuild quand ces dépendances changent. Préférer `MediaQuery.sizeOf(context)` à `MediaQuery.of` (opinion, API granulaire).
