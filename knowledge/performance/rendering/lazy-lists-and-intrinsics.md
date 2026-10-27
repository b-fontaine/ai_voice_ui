---
id: perf-lazy-lists
title: Listes lazy (builder) et passes intrinsèques
tags: [listview, lazy, sliver, layout, intrinsics]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/perf/best-practices
links: [perf-avoid-rebuilds, perf-repaint-boundary]
---
# Construire seulement ce qui est visible

`ListView.builder`, `GridView.builder` et les `Sliver*` avec `SliverChildBuilderDelegate` ne construisent que les éléments visibles, plus un cache. `ListView(children: [...])` ou `Column` construisent **tous** les enfants.

```dart
ListView.builder(
  itemCount: messages.length,
  itemExtent: 72,   // hauteur fixe : layout O(1) par item et scroll rapide (opinion)
  itemBuilder: (context, i) => MessageTile(messages[i]),
);
```

**Cas de l'app :** le transcript de conversation voix et les surfaces GenUI longues. Pour une liste qui grossit par le bas, utiliser `reverse: true` et insérer en tête de données (opinion).

**Passes intrinsèques :** certaines grilles ou listes font une seconde passe de layout pour donner la même taille aux cellules. Cette passe visite **tous** les enfants. On la détecte avec DevTools *Track Layouts* (événements `'$runtimeType intrinsics'`). On l'évite avec des tailles fixes, ou en retirant `IntrinsicHeight`/`IntrinsicWidth` des listes.

## ⚠️ Pièges
- Un `shrinkWrap: true` dans un `ListView` imbriqué casse la paresse. Préférer `CustomScrollView` avec des slivers.
- Le catalogue A2UI peut générer des `Column` longues : vérifier si les composants liste du catalogue sont lazy (non vérifié pour `genui`).
