---
id: ds-widgetbook-4-testing
title: Widgetbook 4.0 bêta — testWidgetbook, scénarios, a11y et coverage
tags: [widgetbook, testing, scenarios, accessibility, golden, design-system]
status: verified
updated: 2026-10-28
sources: [https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz, https://docs.widgetbook.io/~v4/testing/run-scenarios, https://docs.widgetbook.io/~v4/testing/accessibility, https://docs.widgetbook.io/~v4/genui/testing, https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog, https://github.com/widgetbook/widgetbook/issues/678, https://github.com/widgetbook/widgetbook/issues/1991, https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/scenario.dart, https://pub.dev/api/archives/widgetbook_cli-4.0.0-beta.14.tar.gz]
links: [ds-widgetbook-4-stories, adr-0006-ds-no-widgetbook-cloud, test-golden-alchemist, ds-widgetbook-a11y-tooling, ds-widgetbook-4-genui]
---
# `testWidgetbook` capture des snapshots, mais ne compare rien : ce n'est pas un golden

État 4.0.0-beta.14 au 2026-10-28.

## Lancer
`Future<void> testWidgetbook(Config config)`, importé de `package:widgetbook/test.dart`, s'appelle dans `test/widgetbook_test.dart` puis `flutter test`. La fonction initialise le binding, appelle `loadFonts()`, puis crée un `group()` par composant, un `group()` par story et un `testWidgets()` par scénario.

## Sortie : `build/.widgetbook/<Component>/<Story>/<Scenario>.png` + `.json`
- Les `/` du nom de scénario deviennent `_`.
- Le JSON contient le sha256 de l'image, sa taille, le `pixelRatio`, l'arbre de sémantique et les violations a11y.
- Aucun `matchesGoldenFile` ni comparaison à une référence : le diff visuel est fait par **Widgetbook Cloud**. L'issue #678 (golden en OSS) est toujours ouverte. Dans la CLI v4, seule `widgetbook cloud build push` consomme ce dossier (après `flutter test`).

## Scénarios
- `Scenario({type = ScenarioType.local, required name, List<Mode>? modes, TArgs? args, run, excludeFromTests = false, mergeModes})`. Le callback `run` (`Future<void> Function(WidgetTester tester, TArgs args)`) s'exécute **avant** la capture : on y fait des tap, pump et expect, en local, sans Cloud.
- Les modes du scénario l'emportent sur ceux de la story (code de `defaultMergeModes`). Le docstring de `mergeModes` dit l'inverse.
- Global : `Config(scenarioConfig: ScenarioConfig(definitions: [ScenarioDefinition(name:, modes:)], nameBuilder:, setUp:, tearDown:, wrapper:))`. `setUp`/`tearDown` sont de type `Future<void> Function(WidgetTester, Scenario)`. `wrapper` date de la beta.6 (utile pour `package:clock`). `Config.scenarios` a disparu en beta.4.
- Une `ScenarioDefinition` se croise par défaut avec chaque scénario local (`ScenarioStrategy.perScenario`).
- `excludeFromTests` (beta.10, sur Story et Scenario) : aucun snapshot, signalé « skipped », mais toujours visible dans l'app.
- beta.10 vide le cache d'images entre scénarios ; beta.12 attend le chargement des images avant la capture.
- Rendu par `flutter_test` : le viewport fixe `physicalConstraints` et `devicePixelRatio` (sinon `Viewports.none`). Roboto est fourni. Une police déclarée dans un **package de dépendance** doit être référencée avec `package:` (issue #1991, close le 2026-07-30), sinon le texte s'affiche en rectangles noirs.

## Accessibilité (depuis beta.9)
- `AccessibilityConfig({guidelines = WidgetbookGuidelines.recommended})`. `recommended` regroupe : `MinTapTargetGuideline` (`tap-target-android` 48x48, `tap-target-ios` 44x44), `LabeledTappableGuideline()` (`labeled-tappable`) et `FlutterGuideline(textContrastGuideline, id: 'text-contrast')`.
- Noms exportés par beta.14 : `WidgetbookGuideline` (abstraite : `id`, `evaluate(WidgetTester)`), `FlutterGuideline(guideline, {required id, helpUrl})`, `MinTapTargetGuideline`, `LabeledTappableGuideline`, `WidgetbookGuidelines`, `evaluateGuidelines`, `GuidelineViolation({required guidelineId, required title, helpUrl, nodes, reason})` et `ViolationNode`.
- `LabeledImageGuideline` **n'existe pas** : c'est un exemple de règle maison. Garder un `id` stable, car les violations sont suivies par id.
- `guidelines: const []` désactive l'évaluation, mais l'arbre de sémantique reste capturé. Une règle qui lève une exception est enregistrée comme violation.
- Les violations **ne font jamais échouer** `flutter test`. Elles ne sont écrites que dans le JSON.
- `text-contrast` ne couvre que le texte, est approximatif et doit être lu comme indicatif. Ce n'est pas une preuve de conformité WCAG des tokens M3 (opinion).

## Coverage
`widgetbook coverage` (CLI 4.0.0-beta.14, expérimental) : `--package` (`./`), `--widgetbook` (`./widgetbook`), `--min-coverage` (100). Renvoie -8 sous le seuil, ce qui en fait un gate CI. `// widgetbook: ignore` exclut un widget.

## Sans Cloud ([[adr-0006-ds-no-widgetbook-cloud]]) (opinion)
- **Non-régression visuelle bloquante :** goldens alchemist dans des fichiers de test **séparés** ([[test-golden-alchemist]]). `goldenTest` ne peut pas s'appeler depuis `Scenario.run`. Aucune doc Widgetbook ne mentionne alchemist (non vérifié).
- `expectLater(..., matchesGoldenFile(...))` dans `run` est possible d'après la signature, mais non documenté et non testé.
- **Gate a11y :** un script lit la clé `"violations"` de `build/.widgetbook/**/*.json`. Ce JSON n'a pas de schéma publié : le gate reste fragile d'une bêta à l'autre.
- Lancer les tests sur un runner CI fixe : les pixels dépendent de l'OS hôte, comme pour tout golden.

## ⚠️ Pièges
- **Non vérifié :** `testWidgetbook` sur `--platform chrome`. Le code écrit avec `dart:io`, donc c'est probablement incompatible.
