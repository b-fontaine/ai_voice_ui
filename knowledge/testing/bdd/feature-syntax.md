---
id: test-bdd-feature-syntax
title: bdd_widget_test — syntaxe Gherkin supportée
tags: [bdd, gherkin, scenario-outline, data-table]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/bdd_widget_test]
links: [test-bdd-widget-test, test-bdd-gherkin-practices, test-bdd-hooks-steps]
---
# Background, After, Rule, Scenario Outline, tables : tout le Gherkin utile est supporté (v3.0.4)

```gherkin
@voice
Feature: Session vocale
  Background:
    Given the app is running
  After:
    Then I close the voice session        # exécuté même si le test échoue

  Rule: Affichage GenUI
    Scenario Outline: L'agent affiche l'écran demandé
      When the voice agent calls show_screen with {'<screen>'}
      Then I see {'<title>'} text
      Examples:
        | screen   | title    |
        | invoices | Factures |
        | clients  | Clients  |

  Scenario: Catalogue de composants
    Given available components
      | 'name' | 'kind'   |
      | 'Card' | 'layout' |
```

## Éléments supportés
- **`Background` :** steps exécutés avant chaque scénario. Le `Background` d'une `Rule` s'exécute après celui de la Feature.
- **`After` :** nettoyage exécuté même en cas d'échec.
- **`Rule` :** crée un `group` imbriqué. Ses tags sont hérités par ses scénarios.
- **`Scenario Outline` + `Examples` (ou `Scenarios`) :** un test par ligne. Les `<placeholder>` sont remplacés par la valeur de la colonne.
- **Data table sous un step :** passée en argument `bdd.DataTable`, lisible avec `asLists()` ou `asMaps()`.
  ```dart
  Future<void> availableComponents(WidgetTester tester, bdd.DataTable dataTable) async {..}
  ```
- **Tables de répétition :** une table placée sous un step peut aussi servir à l'exécuter une fois par ligne. Le README distingue ce cas des data tables : vérifier le step généré.
- **`# language: fr` :** placé au-dessus du premier keyword de feature ; les **keywords** doivent alors être en français (`Fonctionnalité`, `Contexte`, `Scénario`, `Soit`/`Quand`/`Alors`), sauf `After:` qui reste en anglais.
- **Doc strings (`"""`) :** parsées mais ignorées.
- **Tags :** `flutter test --tags voice` ou `--exclude-tags slow`.
  - Les tags spéciaux `@testMethodName:`, `@testerType:`, `@testerName:` et `@scenarioParams:` se placent seuls sur leur ligne.

## ⚠️ Pièges
- Les noms de steps sont dérivés des lettres et chiffres ASCII, même avec `# language: fr` (accents repliés). Un step sans ASCII, ou commençant par un chiffre ou `_`, fait échouer le build. Préférer des steps en anglais (opinion).
- `After:` et les tables de répétition sont des extensions non standard : d'autres outils Gherkin les interprètent autrement, sans erreur.
