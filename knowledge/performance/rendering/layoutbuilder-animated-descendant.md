---
id: perf-layoutbuilder-animated-descendant
title: Sous un LayoutBuilder, une animation par AnimatedBuilder remet en page à chaque image
tags: [layoutbuilder, animation, layout, repaint, rebuild]
status: sourced
updated: 2026-11-03
sources:
  - https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/widgets/layout_builder.dart
  - https://api.flutter.dev/flutter/widgets/FadeTransition-class.html
  - https://api.flutter.dev/flutter/widgets/CustomPainter-class.html
links: [perf-repaint-boundary, perf-avoid-rebuilds, perf-audio-visualizer-60hz, ds-motion]
---
# Un descendant animé d'un LayoutBuilder fait `markNeedsLayout` du LayoutBuilder à chaque image

Observé sous Flutter 3.47 (genesis_canvas, spec 019, revue du code) : un `AnimatedBuilder`, un `AnimatedWidget` ou une `SlideTransition` posé **sous un `LayoutBuilder`** reconstruit à chaque image, et le `LayoutBuilder` est remis en page (`BuildScope`, `layout_builder.dart`). Le parent est alors repeint à 60 Hz, même si seule une opacité ou un décalage change. Constat par `debugPrintMarkNeedsLayoutStacks = true`.

Animer au niveau du **rendu**, sans reconstruire :
- opacité : `FadeTransition` (met à jour la couche, ne reconstruit pas) ;
- dessin animé : `CustomPainter(repaint: animation)` ;
- glissement : un `RenderProxyBox` qui décale à la **peinture** (`paint` + `applyPaintTransform` + `hitTestChildren` décalé), pas une `SlideTransition` ;
- un seul contrôleur par animation, dans son propre `RepaintBoundary`.

Mesure en test : compter les `performLayout` d'un parent `LayoutBuilder` pendant l'animation (doit rester constant).

## ⚠️ Pièges
- Le compteur de peintures d'un `RepaintBoundary` (mesuré dans les tests de genesis_canvas) compte aussi les peintures du **parent** : une animation même ponctuelle dans une couche partagée fait échouer « cet élément n'est pas animé » ailleurs. Un boundary par animation.
- Un test qui exige un `AnimatedWidget` pour reconnaître un battement façonne le code de production : compter plutôt les notifications des `Listenable` (animations et `CustomPaint.painter`).
