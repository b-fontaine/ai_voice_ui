---
id: test-flutter-hit-test-reachability
title: Prouver qu'un contrôle est atteignable en widget test (tap, warnIfMissed, hitTestable)
tags: [widget-test, flutter, hit-test, tap, layout]
status: verified
updated: 2026-11-03
sources: [flutter/packages/flutter_test/lib/src/controller.dart (Flutter 3.47.8, WidgetController.tap, hitTestWarningShouldBeFatal), flutter/packages/flutter_test/lib/src/finders.dart (CommonFinders.hitTestable)]
links: [test-mock-boundaries-only, test-flutter-real-fonts-overflow, test-bdd-app-running-fixture]
---
# Prouver qu'un contrôle est atteignable en widget test

`tester.tap(finder)` ne fait **jamais échouer** un clic qui tombe sur un autre widget : avec `warnIfMissed: true` (défaut) il écrit seulement un avertissement (« derived an Offset … that would not hit test »), avec `warnIfMissed: false` il ne dit rien. Un test de mise en page qui ne fait que taper peut donc rester vert alors qu'un panneau recouvre le contrôle.

Pour prouver l'atteignabilité, combiner deux conditions :

```dart
// 1. le point visé (centre par défaut) atteint bien ce widget
expect(find.byKey(key).hitTestable(), findsOneWidget, reason: 'recouvert');
// 2. son rectangle ne recoupe pas celui de l'élément qui le recouvre
expect(tester.getRect(find.byKey(key)).overlaps(panelRect), isFalse);
```

- `hitTestable({Alignment at = Alignment.center})` accepte un autre point : utile pour les extrémités d'une glissière, qui ne positionne qu'au relâchement.
- Le centre seul ne suffit pas : un contrôle peut passer le test au centre avec 3 px de marge (cas vu : bouton recoupant un panneau de 20 px mais touché au centre) ; la seconde condition rend le test indépendant de cette marge.
- Pour les clics qui doivent **traverser** un calque transparent (`Positioned.fill` + `Align` + `Padding`, `Material(type: transparency)`) : vérifier `hitTestable()` sur les widgets situés dessous.
- `WidgetController.hitTestWarningShouldBeFatal = true` (statique, défaut `false`) transforme l'avertissement en erreur pour tous les `tap` d'une suite ; à poser dans un `setUp` et à restaurer.

⚠️ Pièges
- Les helpers de test écrits avec `warnIfMissed: false` (pour viser un widget volontairement hors cadre) masquent un recouvrement ; ne pas les utiliser pour prouver l'atteignabilité.
- `tester.tapAt(offset)` ne vérifie rien : appeler d'abord un contrôle de hit test au même point.
- Un test à tester pour de bon : neutraliser la cause (p. ex. le clic qui déplie le panneau) doit le faire passer au rouge (rouge de contrôle).
