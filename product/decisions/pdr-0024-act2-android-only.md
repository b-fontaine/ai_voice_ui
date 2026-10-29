---
id: pdr-0024-act2-android-only
title: "PDR-0024 — À l'acte 2, toutes les données affichées concernent uniquement Android, checklist comprise"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p4, product/sources/design-example.pdf#p3]
links: [p-rm-open-questions, p-fn-mockups, p-fn-requirements, p-fn-business-rules, p-fn-dataset, p-fn-feature-voice-screen-generation, p-rm-roadmap, p-rm-backlog, pdr-0004-mvp-three-acts, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, acte-2, android, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0004-mvp-three-acts, p-fn-requirements, p-fn-feature-voice-screen-generation]
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0024 — Acte 2 : uniquement Android

> **En bref.** Décision contrainte, tranche Q-58 (E19). À l'acte 2, **toutes** les données affichées concernent Android, y compris les critères de la checklist. Le critère iOS et la puce « iOS » de la maquette 3 n'ont aucune portée.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Fiche § 4, S-02 : « Et les données affichées concernent uniquement Android » (FR-07, [p-fn-requirements](../functional/requirements.md), [voice-screen-generation.feature](../functional/features/voice-screen-generation.feature)).
- Maquette 3 : critère « Sans crash iOS ≥ 99,5 % · 99,71 » dans la checklist et puce « iOS » ([p-fn-mockups](../functional/mockups.md), E19).
- [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md) : écart fiche/maquette, la fiche l'emporte ; [pdr-0004](pdr-0004-mvp-three-acts.md) : acte 2 « transformer ».

## Hypothèses
- Aucune.

## Options
1. **Uniquement Android (fiche)** (retenue)
2. Android filtré, mais checklist multi-plateformes (maquette)

## Décision
- Après « Concentre-toi sur Android… », chaque surface affichée (Indicateur clé, Courbe, Sentiment des avis, Checklist go/no-go) ne montre que des données Android.
- Aucun critère, valeur ni libellé iOS n'est visible à l'acte 2.

## Raisons
- La fiche tranche explicitement (S-02, FR-07) ; un écart avec l'illustration n'est pas une question (pdr-0017).

## Options écartées
- **Checklist multi-plateformes** : repose uniquement sur l'illustration (pdr-0017) et contredit S-02.

## Conséquences
- [p-fn-requirements](../functional/requirements.md) FR-07, [p-fn-business-rules](../functional/business-rules.md) RG-06 : réserve E19 · Q-58 retirée (E8 · Q-21 reste).
- [p-fn-dataset](../functional/dataset.md) : la checklist de l'acte 2 a des critères Android.
- [p-rm-roadmap](../roadmap/roadmap.md) J4, [p-rm-backlog](../roadmap/backlog.md) EP-04 : dépendance Q-58 levée.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-58 tranchée ; [p-fn-mockups](../functional/mockups.md) : E19 tranché.

## Réexaminer si
- La fiche S-02 est révisée.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-58 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur (pdr-0017) | Assistant |

Pas d'archive brute.
