---
id: pdr-0019-six-limit-applies-to-surfaces
title: "PDR-0019 — La limite « 6 » porte sur les surfaces visibles, pas sur un compteur de composants"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p9, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-mockups, p-fn-nfr, p-fn-business-rules, p-fn-scope, p-fn-catalog, p-fn-screen, p-ar-quality, p-rm-backlog, p-rm-spikes, pdr-0007-closed-catalog-stage-theme, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0017-source-hierarchy-sheet-over-mockups]
tags: [pdr, decision, surfaces, catalog, etagere, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, p-fn-nfr, p-fn-business-rules]
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0019 — La limite « 6 » porte sur les surfaces visibles

> **En bref.** Décision contrainte, tranche Q-04 (E4) : la question est sans objet. La fiche fixe **au plus 6 surfaces visibles** en même temps (§ 3, NFR-06, RG-05). L'étagère montre les composants du catalogue et allume celui qui est utilisé (FR-06, § 6) ; aucun compteur ni limite de composants n'est exigé.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Q-04 demandait si « 6 » portait sur les surfaces ou sur les composants. Seule la maquette (« 4 / 6 utilisés », « 5 / 6 utilisés » sur l'étagère) suggérait un compteur de composants ([p-fn-mockups](../functional/mockups.md), E4).
- Fiche § 3 et NFR-06 : « au maximum 6 surfaces visibles » ; RG-05 ([p-fn-nfr](../functional/nfr.md), [p-fn-business-rules](../functional/business-rules.md)).
- Le catalogue est fermé à 6 composants par [pdr-0014](pdr-0014-six-component-catalog.md), sans rapport avec NFR-06 ; la grille de l'app est dimensionnée pour au plus 6 surfaces ([pdr-0015](pdr-0015-app-held-canvas-layout.md)). Ces deux PDR laissaient Q-04 ouverte en vertu de la consigne « tout laisser ouvert », remplacée par [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md).

## Hypothèses
- Aucune : la réponse découle de la fiche et des décisions acceptées.

## Options
1. **Limite de surfaces (fiche)** (retenue)
2. Limite du catalogue (« n / 6 utilisés » de l'illustration)
3. Les deux

## Décision
- RG-05 / NFR-06 : au plus 6 **surfaces** visibles en même temps sur le canevas.
- L'étagère du catalogue (FR-06) montre les composants et allume celui qui est utilisé ; aucun compteur « n / 6 » ni plafond de composants n'est exigé.
- Que le catalogue compte aussi 6 composants (pdr-0014) est une coïncidence sans lien avec NFR-06.

## Raisons
- La fiche dit explicitement « surfaces » (§ 3, NFR-06) ; la seule source de la question est l'illustration, et un écart fiche/maquette n'est pas une question (pdr-0017).

## Options écartées
- **Limite du catalogue** et **les deux** : reposent uniquement sur l'illustration (pdr-0017) ; la taille du catalogue est déjà fixée par pdr-0014.

## Conséquences
- [p-fn-business-rules](../functional/business-rules.md) RG-05, [p-fn-nfr](../functional/nfr.md) NFR-06, [p-fn-scope](../functional/scope.md), [p-fn-catalog](../functional/catalog.md) : réserve E4 · Q-04 retirée.
- [p-ar-quality](../architecture/quality.md) : l'assertion NFR-06 porte sur le nombre de surfaces dans `CanvasBloc`.
- [p-rm-backlog](../roadmap/backlog.md), [p-rm-spikes](../roadmap/spikes.md) : dépendance Q-04 levée (EP-04, SP-07).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-04 tranchée ; [p-fn-mockups](../functional/mockups.md) : E4 tranché.

## Réexaminer si
- La fiche produit est révisée et fixe une limite sur l'étagère du catalogue.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-04 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Parole du porteur : « En fait, la maquette n'est qu'une démonstration de ma vision, une illustration. Il ne faut surtout pas la suivre à la lettre, et surtout pas pour des questions techniques. » (conversation, pdr-0017) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur | Assistant |

Pas d'archive brute.
