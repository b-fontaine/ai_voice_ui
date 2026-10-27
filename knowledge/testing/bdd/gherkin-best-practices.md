---
id: test-bdd-gherkin-practices
title: Bonnes pratiques d'écriture Gherkin
tags: [bdd, gherkin, best-practice]
status: sourced
updated: 2026-10-26
sources: [https://cucumber.io/docs/bdd/better-gherkin/, https://pub.dev/packages/bdd_widget_test]
links: [test-bdd-feature-syntax, test-bdd-widget-test, test-tdd-red-green-refactor]
---
# Décrire le comportement, pas l'interface

Un scénario exprime une règle métier observable dans le langage du domaine. Le détail des clics et des clés de widgets reste dans les steps Dart.

## Règles
- **Déclaratif plutôt qu'impératif :**
  - à préférer : `When the user asks for {'mes factures'}`
  - à éviter : 3 steps « tap micro / wait / tap stop »
- **Un scénario = un comportement :** un seul bloc `When`, quelques `Then`. Le README de bdd_widget_test conseille 3 à 5 steps par scénario.
- **`Given` = état et `When` = action :** `Then` vérifie un résultat visible par l'utilisateur, jamais un état interne.
- **`Background` court :** seulement ce qui est vrai pour tous les scénarios de la feature.
- **Scenario Outline :** uniquement quand les lignes sont des variantes de la même règle, pas pour regrouper des cas sans lien.
- **Vocabulaire stable :** un catalogue de steps partagés (cf. `test-bdd-hooks-steps`) évite les synonymes. Par exemple, garder « the voice agent » partout plutôt qu'alterner avec « the assistant ».
- **Steps sans dépendance d'ordre caché :** chaque step doit pouvoir se relire seul.
- **Tags :** `@wip`, `@slow`, `@e2e`, `@golden` pour filtrer en CI.

## Pour le projet multi-agents
- Les features se rédigent du point de vue utilisateur : « l'utilisateur demande, l'écran apparaît ».
- On n'y nomme ni le modèle (gpt-live-1, gpt-realtime-1.5...), ni A2UI, ni le WebRTC : ces détails restent dans les fakes.

## ⚠️ Pièges
- Des steps génériques UI (`I tap {..} text`) partout transforment les features en scripts fragiles. Les réserver aux tests d'écran simples.
- Seules les règles « déclaratif » et « détails dans les step definitions » viennent de cucumber.io (2026-10-26), qui admet aussi le style impératif dans certains contextes ; « 3 à 5 steps » vient du README bdd_widget_test. Le reste relève de la recommandation interne.
