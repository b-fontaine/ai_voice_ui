---
id: ds-widgetbook-visual-review-ci
title: Revue visuelle sans Widgetbook Cloud — goldens et artefacts CI
tags: [widgetbook, golden-tests, ci, visual-review, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/~v4/sharing/hosting, https://docs.widgetbook.io/~v4/testing/run-scenarios, https://docs.widgetbook.io/~v4/genui/testing, https://docs.widgetbook.io/~v4/sharing/fonts, https://api.flutter.dev/flutter/flutter_test/LocalFileComparator-class.html, https://pub.dev/packages/alchemist, https://github.com/actions/upload-artifact]
links: [adr-0006-ds-no-widgetbook-cloud, ds-widgetbook-publish-web, ds-widgetbook-4-testing, test-golden-alchemist, test-coverage-ci]
---
# Sans Cloud, la non-régression visuelle repose sur des goldens commités

Sans Widgetbook Cloud ([[adr-0006-ds-no-widgetbook-cloud]]), rien ne compare les snapshots v4 (`build/.widgetbook`) d'un commit à l'autre. Il faut des golden tests par widget, avec baselines commitées et régénérées par `--update-goldens` (« Rerun with `--update-goldens` and commit the images », doc v4). Infos au 2026-10-28.

## Ce que produit Widgetbook 4
- `test/widgetbook_test.dart` appelle `await testWidgetbook(config);` (`package:widgetbook/test.dart`). Chaque scénario écrit `build/.widgetbook/<Component>/<Story>/<Scenario>.png` + un JSON de métadonnées. Images courantes seulement : **aucun diff local**, et aucun outil officiel de comparaison trouvé.
- Les violations d'accessibilité n'échouent pas `flutter test` : elles vont dans le champ `violations` du JSON. Pour bloquer, la CI doit lire ce champ.
- `excludeFromTests: true` (depuis beta.10) sur `_Story`/`_Scenario` : pas de snapshot, mais visible dans le catalogue.
- Réseau inaccessible en test : embarquer les polices en assets, fetch runtime désactivé. Sinon, une famille non déclarée dans le manifeste de polices donne des rectangles noirs (le lien direct avec google_fonts est une déduction).

## Diffs exploitables
- Le `LocalFileComparator` de Flutter écrit, à côté du golden en échec, un dossier `failures/` : `<test>_masterImage.png`, `_testImage.png`, `_isolatedDiff.png`, `_maskedDiff.png`.
- alchemist 0.14.1 écrit ses goldens CI dans `goldens/ci/`, à côté du test (config `AlchemistConfig`, `PlatformGoldensConfig`/`CiGoldensConfig`) ; voir [[test-golden-alchemist]]. Qu'alchemist passe par `LocalFileComparator` (et produise `failures/`) n'est pas vérifié.

## Publication en artefact (`actions/upload-artifact@v7`)
- Entrées utiles : `name`, `path`, `if-no-files-found` (`warn` par défaut), `retention-days` (1 à 90 par défaut, plafond réglable dans le dépôt), `include-hidden-files`, `overwrite`, `compression-level`.
- **`include-hidden-files: true` obligatoire** pour `build/.widgetbook` : par défaut, les dossiers commençant par `.` sont exclus.
- La sortie `artifact-url` n'est accessible qu'à un utilisateur connecté ; on peut la recopier dans un commentaire de PR.

## Montage proposé (opinion)
- Job golden bloquant, puis upload de `failures/` et de `build/.widgetbook` en artefact. Le catalogue de la PR va en preview Firebase ([[ds-widgetbook-publish-web]]) pour la revue humaine.
- Non vérifié : un exemple officiel `if: failure()` avec upload-artifact, et les actions de commentaire de PR (`sticky-pull-request-comment`, `gh pr comment`).

## ⚠️ Pièges
- Sans `include-hidden-files`, l'artefact `build/.widgetbook` est vide, avec un simple avertissement (déduction : `if-no-files-found` vaut `warn` par défaut).
