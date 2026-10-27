---
id: test-bdd-build-yaml
title: bdd_widget_test — options build.yaml et bdd_options.yaml
tags: [bdd, build_runner, build-yaml, config]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bdd_widget_test]
links: [test-bdd-widget-test, test-bdd-hooks-steps, test-patrol]
---
# Configurer le builder `bdd_widget_test|featureBuilder`

```yaml
# build.yaml
targets:
  $default:
    sources: [integration_test/**, test/**, lib/**, $package$]  # si features en integration_test
    builders:
      bdd_widget_test|featureBuilder:
        options:
          stepFolderName: bdd_steps
          addHooks: true
          hookFolderName: bdd_hooks
          externalSteps:
            - package:voice_test_kit/steps/voice_steps.dart
          include: package:voice_test_kit/bdd_options.yaml
          customHeaders:  # REMPLACE les imports par défaut : remettre flutter_test
            - "import 'package:flutter_test/flutter_test.dart';"
            - "import 'package:voice_test_kit/fakes.dart';"
```

| Clé | Rôle |
|---|---|
| `stepFolderName` | dossier des steps (défaut `./step`, à côté de la feature ; sinon créé sous `test/`) |
| `relativeToTestFolder` | défaut `true` ; `false` : chemins résolus depuis la racine du projet |
| `addHooks` / `hookFolderName` | défaut `false` / `./hook` ; génère les hooks, par dossier |
| `externalSteps` | steps importés d'un autre package (pas de régénération) |
| `include` | charge un `bdd_options.yaml` externe (`include:`, `externalSteps:`) |
| `customHeaders` | lignes en tête des fichiers générés ; **remplacent** les imports par défaut (`material_ui` + `flutter_test` des features, `flutter_test` des steps) |
| `testMethodName`, `testerName`, `testerType` | défauts `testWidgets`, `tester`, `WidgetTester` ; Patrol : `patrolTest`, `$`, `PatrolIntegrationTester` |
| `includeIntegrationTestBinding` | défaut `true` ; `false` pour Patrol 3.0.0 et plus |

Valeurs par défaut lues dans `lib/src/generator_options.dart` de la 3.0.4 (le README ne les liste pas).

## ⚠️ Pièges
- Après modification de `build.yaml`, relancer `build_runner` (opinion : `watch` ne reprend pas toujours proprement le changement de config).
- Oublier `flutter_test` dans `customHeaders` casse la compilation des tests générés.
