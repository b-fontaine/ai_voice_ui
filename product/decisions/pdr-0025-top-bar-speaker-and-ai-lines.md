---
id: pdr-0025-top-bar-speaker-and-ai-lines
title: "PDR-0025 — La barre supérieure affiche en direct les répliques du speaker et de l'IA ; une réplique coupée est tronquée"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p5, product/sources/product-description.pdf#p8, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-mockups, p-fn-requirements, p-fn-business-rules, p-fn-screen, p-fn-feature-barge-in, p-ar-frontend, p-rm-backlog, pdr-0008-single-screen-show-the-making, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, transcription, barre-superieure, barge-in, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0008-single-screen-show-the-making, p-fn-requirements, p-fn-business-rules, p-fn-feature-barge-in]
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0025 — Répliques du speaker et de l'IA dans la barre supérieure

> **En bref.** Décision contrainte, tranche Q-59 (E20). La barre supérieure affiche en direct les répliques du speaker **et** de l'IA ; une réplique de l'IA coupée est tronquée à l'endroit de l'interruption.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Fiche § 6 : répliques du speaker et de l'IA ; FR-19, RG-17 ; S-05 : « sa réplique est tronquée dans la transcription à l'endroit de l'interruption » ([p-fn-requirements](../functional/requirements.md), [p-fn-business-rules](../functional/business-rules.md), [barge-in.feature](../functional/features/barge-in.feature)).
- Maquettes 1-3 : seule la phrase du speaker ([p-fn-mockups](../functional/mockups.md), E20).
- [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md) : la fiche l'emporte ; [pdr-0008](pdr-0008-single-screen-show-the-making.md) : écran unique, barre supérieure.

## Hypothèses
- Aucune sur la décision. La détection de l'interruption reste une question technique distincte (Q-40).

## Options
1. **Speaker et IA (fiche)** (retenue)
2. Speaker seul (maquettes)

## Décision
- La transcription de la barre supérieure montre, en direct, les répliques du speaker et celles de l'IA.
- Une réplique de l'IA interrompue reste affichée, tronquée à l'endroit de l'interruption (S-05, FR-19).

## Raisons
- La fiche tranche explicitement (§ 6, FR-19, RG-17, S-05) ; un écart avec l'illustration n'est pas une question (pdr-0017).

## Options écartées
- **Speaker seul** : repose uniquement sur l'illustration et rendrait S-05 invérifiable.

## Conséquences
- [p-fn-business-rules](../functional/business-rules.md) RG-17, [p-fn-screen](../functional/screen.md) : réserve E20 retirée.
- [p-ar-frontend](../architecture/frontend.md) `top_bar` : transcription des deux voix sans réserve.
- [p-rm-backlog](../roadmap/backlog.md) RG-17 : dépendance Q-59 levée ; Q-40 (inférence de la troncature) reste ouverte.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-59 tranchée ; [p-fn-mockups](../functional/mockups.md) : E20 tranché.

## Réexaminer si
- La fiche § 6 ou S-05 est révisée.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-59 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur (pdr-0017) | Assistant |

Pas d'archive brute.
