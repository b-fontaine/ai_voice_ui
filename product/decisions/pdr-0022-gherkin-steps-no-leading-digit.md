---
id: pdr-0022-gherkin-steps-no-leading-digit
title: "PDR-0022 — Les steps Gherkin qui commencent par un chiffre sont reformulés ; bdd_widget_test est conservé"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p5, knowledge:test-bdd-feature-syntax]
links: [p-rm-open-questions, p-fn-mockups, p-fn-risks-acceptance, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-ar-quality, pdr-0011-adopt-knowledge-adrs, adr-0001-initial-constraints, test-bdd-feature-syntax]
tags: [pdr, decision, bdd, gherkin, tests, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [test-bdd-feature-syntax, adr-0001-initial-constraints, AGENTS.md#tests, pdr-0011-adopt-knowledge-adrs]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0022 — Steps Gherkin sans chiffre initial

> **En bref.** Décision contrainte, tranche Q-34 (E16). Les steps qui commencent par un chiffre sont reformulés en toutes lettres, sens inchangé (« Et quatre surfaces sont complètes… », « Soit deux surfaces sur quatre… »). L'outil BDD reste `bdd_widget_test`.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Fiche § 4 : « Et 4 surfaces sont complètes en moins de 8 secondes » (S-01), « Soit 2 surfaces sur 4 sont en cours de construction » (S-06).
- Fait vérifié : `bdd_widget_test` fait échouer le build sur un step qui commence par un chiffre ou `_` [test-bdd-feature-syntax].
- L'outil est imposé par AGENTS.md § 2 (tests) et [adr-0001-initial-constraints], appliqué au produit par [pdr-0011](pdr-0011-adopt-knowledge-adrs.md).

## Hypothèses
- Aucune.

## Options
1. **Reformuler les steps** (retenue)
2. Changer d'outil BDD

## Décision
- Tout step `.feature` du produit commence par un mot, jamais par un chiffre ni `_`.
- Reformulations : S-01 « Et quatre surfaces sont complètes en moins de 8 secondes » ; S-06 « Soit deux surfaces sur quatre sont en cours de construction » (et, par cohérence, « Et les deux surfaces inachevées sont retirées »). Le sens et les seuils sont inchangés.
- `bdd_widget_test` reste l'outil BDD.

## Raisons
- Changer d'outil contredirait AGENTS.md § 2 et adr-0001 ; seule la reformulation est compatible avec le fait vérifié.

## Options écartées
- **Changer d'outil BDD** : contraire à une règle non négociable (AGENTS.md § 2, adr-0001).

## Conséquences
- [voice-screen-generation.feature](../functional/features/voice-screen-generation.feature), [barge-in.feature](../functional/features/barge-in.feature) : steps reformulés.
- [p-fn-risks-acceptance](../functional/risks-acceptance.md) DoD D1 : la réserve E16 est levée.
- [p-ar-quality](../architecture/quality.md) : règle d'écriture des steps.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-34 tranchée (Q-63 reste ouverte) ; [p-fn-mockups](../functional/mockups.md) : E16 tranché.

## Réexaminer si
- Une version de `bdd_widget_test` accepte les steps commençant par un chiffre (revérifier [test-bdd-feature-syntax]).
- AGENTS.md ou adr-0001 change d'outil BDD.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-34 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur | Assistant |

Pas d'archive brute.
