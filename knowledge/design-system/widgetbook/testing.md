---
id: ds-widgetbook-testing
title: Tester le design system à partir du catalogue Widgetbook
tags: [widgetbook, golden, testing, coverage, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/packages/alchemist/changelog, https://pub.dev/documentation/alchemist/latest/, https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html, https://pub.dev/packages/alchemist, https://pub.dev/packages/widgetbook_golden_test, https://docs.widgetbook.io/cli/commands/coverage, https://docs.widgetbook.io/cloud/reviews/limitations, https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog]
links: [test-golden-alchemist, ds-widgetbook-a11y-tooling, ds-widgetbook-cloud, test-coverage-ci]
---
# Le catalogue sert de référence ; les goldens alchemist restent le garde-fou bloquant

> Référence Widgetbook 3.x. Le projet utilise la 4.0 bêta ([[adr-0008-ds-widgetbook-4-beta]]) : voir [[ds-widgetbook-4-testing]].

## Stratégie (opinion)
1. **Goldens alchemist** sur chaque composant DS (CI goldens bloquants) : voir [[test-golden-alchemist]], non dupliqué ici.
2. **Tests a11y** automatisés (`meetsGuideline`) : voir [[ds-widgetbook-a11y-tooling]].
3. **`widgetbook coverage`** en CI : tout widget public du DS a au moins un use case.
4. **Widgetbook Cloud** en option, pour la revue humaine ([[ds-widgetbook-cloud]]).
Partager les fixtures et builders entre use cases et tests, plutôt que dépendre d'un paquet de rejeu.

## Compléments alchemist (au 2026-10-27, version 0.14.1)
- **0.13.0 :** anti-aliasing désactivé sur `BlockedTextPaintingContext` (changement *breaking*, corrige aussi un problème cross-platform). Les CI goldens existants peuvent changer : les régénérer une fois après la montée.
- **0.14.0 :** ajout de `diffThreshold` (ratio de pixels différents, `0.0` inclus à `1.0` exclu, `0.001` = 0,1 %, défaut `0.0`) et correctif de la lenteur du chargement des polices.
- Minimum Flutter 3.32.0 depuis la 0.12.0.
- Les tests golden reçoivent par défaut le tag `golden` : `flutter test --tags golden` ou `--exclude-tags golden`.

## `matchesGoldenFile` (flutter_test)
- `AsyncMatcher matchesGoldenFile(Object key, {int? version})`, mise à jour par `flutter test --update-goldens`, comparaison via `goldenFileComparator`.
- Une police personnalisée peut s'afficher différemment selon la plateforme **et** la version de Flutter. Par défaut, Ahem dessine des carrés.

## Rejouer les use cases en goldens
- `widgetbook_golden_test` 0.5.1 : paquet **communautaire** (uploader non vérifié), dépend de `widgetbook ^3.20.2`. Appel : `runWidgetbookGoldenTests(nodes: directories, properties: WidgetbookGoldenTestsProperties())`.
- `widgetbook_test` (éditeur widgetbook.io) : la 3.0.0 est un simple **placeholder**. La préversion 4.0.0-alpha.3 ajoutait `testWidgetbook`, fusionné dans `widgetbook` depuis 4.0.0-alpha.5 ([[ds-widgetbook-4-testing]]).

## `widgetbook coverage` (CLI, expérimental)
`--package` (défaut `./`), `--widgetbook` (défaut `./widgetbook`), `--min-coverage` (défaut `100`). Exclure un widget : `// widgetbook: ignore`.

## ⚠️ Pièges
- **Non vérifié :** compatibilité de `widgetbook_golden_test` avec widgetbook 3.25.0.
- `widgetbook coverage` peut casser à chaque version mineure : épingler la version de la CLI.
- **Cloud :** animations (`CircularProgressIndicator`) et valeurs aléatoires faussent la comparaison. Désactiver les animations en contexte Cloud ou via un knob booléen ; remplacer l'aléatoire par des constantes ou un knob avec valeur par défaut.
- Non vérifié : environnement de rendu (OS, polices) des snapshots Cloud.
