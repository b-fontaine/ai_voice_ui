---
id: ds-a11y-flutter-signals
title: Accessibilité — signaux MediaQuery Flutter et meetsGuideline
tags: [accessibility, flutter, media-query, testing, design-system]
status: verified
updated: 2026-10-27
sources: [https://api.flutter.dev/flutter/widgets/MediaQueryData/textScaleFactor.html, https://api.flutter.dev/flutter/widgets/MediaQueryData/highContrast.html, https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html, https://api.flutter.dev/flutter/widgets/MediaQueryData/boldText.html, https://docs.flutter.dev/ui/accessibility/accessibility-testing, https://docs.flutter.dev/ui/accessibility/ui-design-and-styling]
links: [ds-widgetbook-testing, ds-color-dark-contrast, ds-a11y-wcag-contrast, ds-motion, ds-typography]
---
# Les composants du DS lisent quatre signaux d'accessibilité et sont testés avec meetsGuideline

## Signaux `MediaQueryData`
- **`textScaler`** (`MediaQuery.textScalerOf`, `TextScaler.noScaling` par défaut). `textScaleFactor` est déprécié après v3.12.0-2.0.pre, en vue de la mise à l'échelle non linéaire. Il existe encore, mais sera retiré.
- **`highContrast`** : « Increase Contrast » (iOS), « High contrast text » (Android). Mis à jour seulement sur iOS 13+ et Android API 34+ ; `false` sans ancêtre `MediaQuery` ([[ds-color-dark-contrast]]).
- **`disableAnimations`** reflète « Remove animations » d'Android. Le mouvement réduit iOS passe par `AccessibilityFeatures.reduceMotion` (`dart:ui`), qui **ne** positionne **pas** `disableAnimations` : traiter les deux.
- **`boldText`** : la plateforme demande du texte en gras (via `PlatformDispatcher.accessibilityFeatures`).

```dart
// (opinion) un seul helper du DS pour les durées, voir ds-motion
bool reduceMotion(BuildContext c) =>
    MediaQuery.disableAnimationsOf(c) ||
    View.of(c).platformDispatcher.accessibilityFeatures.reduceMotion;
```

## Recommandations Flutter
- Au moins 4.5:1 pour le petit texte (< 18 pt, ou < 14 pt gras) et 3.0:1 pour le grand texte.
- Vérifier que la mise en page tient avec la plus grande police de l'OS, par exemple sur un petit écran. Le seuil de 200 % vient de WCAG 1.4.4, pas de Flutter.

## Tests automatisés (`flutter_test`)
```dart
testWidgets('bouton DS accessible', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(wrapDs(const DsButton(label: 'Envoyer')));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // 48x48
  handle.dispose();
});
```
`iOSTapTargetGuideline` contrôle 44 × 44 (pixels logiques). Jouer ces tests sur chaque thème : clair, sombre, contraste élevé ([[ds-widgetbook-testing]]).

## ⚠️ Pièges
- `disableAnimations` est lu depuis le moteur (`SemanticsBinding`). Le surcharger par un `MediaQuery` n'affecte pas les animations du framework.
- Non vérifié : les seuils numériques de `textContrastGuideline` (la doc renvoie au code source).
- Non vérifié : la correspondance de `boldText` avec chaque plateforme, et le support de `highContrast`/`reduceMotion` sur desktop et web (déduit, non affirmé).
