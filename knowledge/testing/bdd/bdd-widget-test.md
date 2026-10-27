---
id: test-bdd-widget-test
title: bdd_widget_test — tests de widgets générés depuis Gherkin
tags: [bdd, gherkin, bdd_widget_test, build_runner, widgets]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bdd_widget_test, https://pub.dev/packages/material_ui]
links: [test-bdd-feature-syntax, test-bdd-build-yaml, test-bdd-hooks-steps, test-bdd-gherkin-practices, test-bdd-app-running-fixture, proj-sk-patterns]
---
# Des fichiers `.feature` transformés en `testWidgets` par build_runner

Version observée sur pub.dev le 2026-10-26 : `bdd_widget_test` **3.0.4**, publiée le 2026-10-15. Éditeur vérifié : leushchenko.com, licence MIT.

## Fonctionnement
- **Parsing :** les `*.feature` sont lus par `cucumber_gherkin`. Un Gherkin invalide fait échouer le build, avec fichier, ligne et colonne.
- **Mapping :** chaque `Feature` devient un `group` et chaque `Scenario` un `testWidgets`.
- **Steps :** chaque step correspond à une fonction Dart dans un dossier `step/` voisin. Le keyword (Given, When, Then...) est ignoré pour l'appariement.
- **Fichiers générés :** les fichiers `_test.dart` sont régénérés et **ne doivent pas être édités**. Les fichiers de steps ne sont jamais écrasés.

## Installation
```yaml
dev_dependencies:
  build_runner: any
  bdd_widget_test: ^3.0.4
```
- Le README demande d'ajouter **`material_ui`** aux dépendances de l'app (`flutter pub add material_ui`), car les tests et steps prédéfinis générés l'importent. `material_ui` (1.8.0 au 2026-10-26) est la bibliothèque Material sortie du framework (ex-`package:flutter/material.dart`) et exige Flutter >= 3.47.0. Migration : `dart fix --apply --code=migrate_design_widgets`.
- Commandes : `dart run build_runner watch --delete-conflicting-outputs`, puis `flutter test`.

```gherkin
Feature: Counter
  Scenario: Initial counter value is 0
    Given the app is running
    Then I see {'0'} text
```

## ⚠️ Pièges
- Les paramètres entre `{}` sont recopiés tels quels en Dart : `{'0'}` est une `String`, `{0}` un `int`.
- Le README conseille 3 à 5 steps par scénario.
- Les doc strings (`"""`) sont parsées mais ignorées.
- Versionner ou non les `_test.dart` générés : décision d'équipe (opinion : les versionner simplifie la CI, sinon lancer `build_runner build` avant `flutter test`).
