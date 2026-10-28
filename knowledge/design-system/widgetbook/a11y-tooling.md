---
id: ds-widgetbook-a11y-tooling
title: Accessibilité du DS — meetsGuideline en test, accessibility_tools dans Widgetbook
tags: [accessibility, widgetbook, testing, accessibility-tools, design-system]
status: verified
updated: 2026-10-28
sources: [https://api.flutter.dev/flutter/flutter_test/meetsGuideline.html, https://api.flutter.dev/flutter/flutter_test/androidTapTargetGuideline-constant.html, https://api.flutter.dev/flutter/flutter_test/iOSTapTargetGuideline-constant.html, https://api.flutter.dev/flutter/flutter_test/labeledTapTargetGuideline-constant.html, https://pub.dev/packages/accessibility_tools, https://docs.widgetbook.io/addons/accessibility-addon, https://docs.widgetbook.io/addons/builder-addon]
links: [ds-widgetbook-testing, ds-widgetbook-addons, ds-a11y-flutter-signals, ds-a11y-wcag-focus-target, ds-a11y-wcag-contrast]
---
# Deux outils : `meetsGuideline` bloque en test, `accessibility_tools` alerte dans le catalogue

> Référence Widgetbook 3.x. Pour la 4.0 bêta, voir [[ds-widgetbook-4-testing]] (adoption assumée d'une bêta : [[adr-0008-ds-widgetbook-4-beta]]).

## En test : `meetsGuideline`
Matcher **asynchrone** : `await expectLater`, sémantique activée avant avec `tester.ensureSemantics()`, puis `handle.dispose()`.

```dart
testWidgets('DsButton respecte les guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(wrapDs(DsButton(label: 'Valider', onPressed: () {})));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```
- `androidTapTargetGuideline` : nœuds tapables >= **48 x 48**.
- `iOSTapTargetGuideline` : >= **44 x 44**.
- `labeledTapTargetGuideline` : label obligatoire sur tout nœud avec tap ou long press.
- `textContrastGuideline` : contraste du texte selon le WCAG.

## Dans Widgetbook : `accessibility_tools` 3.0.0
Au 2026-10-27 : éditeur vérifié rebelappstudio.com, actif en debug seulement, retiré des builds release. Zones tactiles par défaut : 48x48 mobile, 44x44 desktop. `AccessibilityAddon` est déprécié ; la doc renvoie vers `BuilderAddon` :

```dart
BuilderAddon(
  name: 'Accessibility',
  builder: (context, child) => AccessibilityTools(child: child),
),
```
- `checkFontOverflows: true` active le vérificateur de débordement du texte agrandi (expérimental, désactivé par défaut).
- `IgnoreMinimumTapAreaSize` neutralise l'alerte de zone tactile pour une exception assumée.

## Usage recommandé (opinion)
Pour une app desktop + web : tester les composants DS avec `iOSTapTargetGuideline` (44, aligné sur le défaut desktop d'accessibility_tools) au minimum, et `androidTapTargetGuideline` pour les composants tactiles. Tests a11y dans la suite du package DS, pas dans le catalogue.

## ⚠️ Pièges
- Oublier `ensureSemantics()` ou `await` : le test ne vérifie rien de fiable.
- **Non vérifié :** seuils exacts de `textContrastGuideline` (4.5:1 ou 3:1), absents de la page API.
- accessibility_tools ne documente aucun usage en test automatisé ou en CI : le traiter comme un outil de revue manuelle (opinion).
