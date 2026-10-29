---
id: pdr-0021-mockup-data-not-corrected
title: "PDR-0021 — Les incohérences de données des maquettes ne sont pas à corriger ; le jeu de référence (Q-23) doit être cohérent"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p9, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-mockups, p-fn-dataset, p-fn-nfr, pdr-0005-frozen-fictional-dataset, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, dataset, maquettes, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0005-frozen-fictional-dataset, p-fn-nfr]
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0021 — Données des maquettes : rien à corriger

> **En bref.** Décision contrainte, tranche Q-33 (E15) : la question est sans objet. Les maquettes sont une illustration ; leurs incohérences (0,82 % vs 0,61 %, « 4 tâches » puis « 3 tâches »…) n'ont pas à être corrigées. Le jeu de référence, à fixer par Q-23, doit seulement être crédible, cohérent en interne, figé et déterministe.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Q-33 demandait comment rendre cohérentes les valeurs illustrées par les maquettes ([p-fn-mockups](../functional/mockups.md), E15 ; [p-fn-dataset](../functional/dataset.md)).
- [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md) : les maquettes ne sont pas une spécification.
- Fiche § 3 et NFR-08 : données fictives crédibles et déterministes ([p-fn-nfr](../functional/nfr.md)) ; [pdr-0005](pdr-0005-frozen-fictional-dataset.md) : jeu figé.

## Hypothèses
- Aucune.

## Options
1. **Ne pas corriger l'illustration ; exiger la cohérence du jeu de référence** (retenue)
2. Corriger les valeurs des maquettes
3. Corriger les libellés des maquettes

## Décision
- Les maquettes ne sont ni corrigées ni reprises comme valeurs de référence.
- Le jeu de référence (contenu tranché par Q-23) est **crédible, cohérent en interne** (par exemple, un taux du jour et une moyenne sur 7 jours sont libellés comme tels), **figé et déterministe** (pdr-0005, NFR-08).

## Raisons
- La question porte uniquement sur des valeurs illustrées ; le choix des valeurs réelles relève de Q-23.

## Options écartées
- **Corriger valeurs ou libellés des maquettes** : travail sur une illustration sans portée (pdr-0017).

## Conséquences
- [p-fn-dataset](../functional/dataset.md) : la réserve E15 devient une exigence de cohérence interne du jeu de référence (Q-23 ouverte).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-33 tranchée ; Q-23 reste ouverte. [p-fn-mockups](../functional/mockups.md) : E15 tranché.

## Réexaminer si
- Le porteur décide, via Q-23, de reprendre telles quelles les valeurs des maquettes : leur cohérence redevient alors à vérifier dans le jeu.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-33 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur (pdr-0017) | Assistant |

Pas d'archive brute.
