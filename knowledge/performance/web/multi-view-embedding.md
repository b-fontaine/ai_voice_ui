---
id: perf-web-multi-view
title: Flutter web — embedding multi-view (hostElement, addView)
tags: [web, embedding, multi-view, widgets]
status: verified
updated: 2026-10-26
sources:
  - https://docs.flutter.dev/platform-integration/web/embedding-flutter-web
  - https://docs.flutter.dev/platform-integration/web/initialization
links: [proj-avw-overview, proj-avw-risks, perf-web-coop-coep, perf-web-initial-load]
---
# Un moteur, N vues dans des éléments DOM de la page hôte

Le mode multi-view rend l'app Flutter dans un ou plusieurs éléments DOM. Toutes les vues partagent **un seul moteur et un seul état Dart**, ce qui coûte bien moins cher que N iframes.

```js
const engine = await engineInitializer.initializeEngine({ multiViewEnabled: true });
const app = await engine.runApp();
const id = app.addView({ hostElement: el, initialData: { prompt: '...' },
                         viewConstraints: { maxWidth: 320, maxHeight: Infinity } });
app.removeView(id);
```

Côté Dart, il n'y a pas d'`implicitView` :
- utiliser `runWidget(MultiViewApp(viewBuilder: ...))` et non `runApp`, sinon on obtient l'erreur `Unexpected null value` ;
- lire les données d'initialisation avec `ui_web.views.getInitialData(viewId)` ;
- `View.of(context).viewId` identifie la vue courante.

Le CSS de l'hôte doit avoir une taille non nulle, `position: relative|absolute|fixed` et `overflow: hidden`.

**Perf :** le moteur et le code ne se téléchargent qu'une fois. Les vues suivantes ne coûtent que leur rendu. Aucun rendu n'a lieu avant le premier `addView`, donc on peut initialiser le moteur tôt et attacher la vue au clic (opinion).

## ⚠️ Pièges
- Les contraintes JS et le CSS doivent concorder : Flutter ne résout pas les conflits.
- L'état partagé entre vues oblige à scoper les BLoC par `viewId`, sinon deux widgets voix partagent la même session (opinion, voir [[proj-avw-risks]]).
