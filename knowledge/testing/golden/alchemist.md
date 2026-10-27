---
id: test-golden-alchemist
title: Golden tests — alchemist (golden_toolkit discontinué)
tags: [golden, alchemist, golden_toolkit, visual]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/alchemist, https://pub.dev/packages/golden_toolkit, https://github.com/Betterment/alchemist]
links: [test-pyramid-flutter, test-bdd-hooks-steps, test-coverage-ci]
---
# Utiliser alchemist : golden_toolkit est marqué « discontinued »

État observé sur pub.dev le 2026-10-26 :
- **golden_toolkit 0.15.0 :** publiée le 2023-02-21, marquée *discontinued* (`replacedBy: null` dans l'API pub.dev).
- **alchemist 0.14.1 :** publiée le 2026-10-08, éditeur vérifié betterment.dev. Son README se dit « heavily inspired » de golden_toolkit.

## Deux familles de goldens
- **CI goldens (`goldens/ci/`) :**
  - texte remplacé par des blocs (police Ahem)
  - identiques quel que soit l'OS, donc ce sont eux qui font foi en CI
- **Platform goldens (`goldens/<platform>/`) :**
  - texte lisible, varient selon l'OS
  - utiles en local pour la revue humaine

```dart
goldenTest(
  'surface GenUI facture',
  fileName: 'genui_invoice_card',
  builder: () => GoldenTestGroup(children: [
    GoldenTestScenario(name: 'défaut', child: InvoiceCard(fixture)),
    GoldenTestScenario.withTextScaleFactor(
      name: 'texte x2', textScaleFactor: 2, child: InvoiceCard(fixture)),
  ]),
);
```

## Configuration globale
- `test/flutter_test_config.dart` enveloppe `testMain` dans `AlchemistConfig.runWithConfig(...)`.
- Paramètres réglables : `theme`, `platformGoldensConfig: PlatformGoldensConfig(enabled: !isCI)`, `ciGoldensConfig`.
- `goldenTest` porte le tag `golden` par défaut : `flutter test --update-goldens`, `--tags golden` ou `--exclude-tags golden`.
- `diffThreshold` (défaut `0.0`) tolère une fraction de pixels différents.

## Cas du projet
Figer en golden le rendu d'un message A2UI enregistré : c'est une non-régression du catalogue GenUI.

## ⚠️ Pièges
- Les ombres sont instables : `renderShadows` vaut `false` en CI, `true` en platform. Pour les animations, `pumpBeforeTest` (défaut `onlyPumpAndSettle`) contrôle le pump avant capture.
- Ne jamais committer de platform goldens générés sur des OS différents.
