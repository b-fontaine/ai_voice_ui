---
id: pdr-0023-example-guided-composition
title: "PDR-0023 — La composition A2UI est faite par un LLM guidé par des exemples d'écrans attendus, sur un catalogue fermé"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p10, product/sources/product-description.pdf#p12]
links: [p-rm-open-questions, p-ar-backend, p-fn-risks-acceptance, p-fn-nfr, p-fn-catalog, p-ar-quality, p-rm-roadmap, pdr-0005-frozen-fictional-dataset, pdr-0007-closed-catalog-stage-theme, pdr-0020-act1-four-surfaces]
tags: [pdr, decision, composition, determinisme, llm, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [p-fn-risks-acceptance, p-fn-catalog, p-fn-nfr, pdr-0007-closed-catalog-stage-theme, pdr-0005-frozen-fictional-dataset]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0023 — Composition guidée par exemples

> **En bref.** Décision contrainte, tranche Q-38. La composition A2UI est faite par un **LLM guidé par des exemples d'écrans attendus**, sur le catalogue fermé. LLM entièrement libre et plans A2UI pré-écrits par acte sont exclus. La forme et l'emplacement des exemples (prompt, fixtures) restent un détail de conception.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Q-38 : comment rendre la composition assez déterministe (NFR-08, « seule la composition varie ») ? Options : LLM libre, LLM guidé par exemples, plans A2UI pré-écrits par acte ([p-ar-backend](../architecture/backend.md)).
- Fiche § 8, parade validée de R6 : « exemples d'écrans attendus fournis à l'IA » ([p-fn-risks-acceptance](../functional/risks-acceptance.md)).
- Fiche § 7 : l'IA « choisit lesquels afficher et avec quelles données » ([p-fn-catalog](../functional/catalog.md)).
- Catalogue fermé [pdr-0007](pdr-0007-closed-catalog-stage-theme.md) ; données figées [pdr-0005](pdr-0005-frozen-fictional-dataset.md).

## Hypothèses
- La suffisance du déterminisme obtenu n'est pas une hypothèse de la décision : elle se mesure en répétition (snapshots NFR-08, [p-ar-quality](../architecture/quality.md)) et rouvre la décision si elle échoue.

## Options
1. **LLM guidé par exemples d'écrans attendus** (retenue)
2. LLM entièrement libre
3. Plans A2UI pré-écrits par acte

## Décision
- L'agent qui compose l'A2UI reçoit des exemples d'écrans attendus (au moins un par acte, par exemple les 4 surfaces de l'acte 1, [pdr-0020](pdr-0020-act1-four-surfaces.md)) et ne compose qu'avec le catalogue fermé.
- Le LLM choisit les composants et leurs données ; aucune séquence de messages A2UI n'est écrite à l'avance pour être rejouée comme si elle était générée.
- Forme et emplacement des exemples (prompt, fixtures) : détail de conception, hors décision.

## Raisons
- Seule l'option 1 est compatible à la fois avec la parade R6 de la fiche validée et avec le principe « l'IA compose, seule la composition varie » (§ 7, NFR-08).

## Options écartées
- **LLM entièrement libre** : contredit la parade R6 validée (fiche § 8).
- **Plans pré-écrits par acte** : l'IA ne choisirait plus les composants ni leurs données (fiche § 7). Le rejeu d'une session enregistrée (pdr-0006) reste le plan B, distinct de la génération.

## Conséquences
- [p-ar-backend](../architecture/backend.md) : déterminisme de la composition fixé ; reste à concevoir la forme des exemples.
- [p-fn-risks-acceptance](../functional/risks-acceptance.md) R6 : renvoi à cette PDR.
- [p-rm-roadmap](../roadmap/roadmap.md) J3 : dépendance Q-38 levée ; les exemples d'écrans font partie du livrable J3.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-38 tranchée. Q-17 (quel LLM) et Q-37 (qui produit l'A2UI) restent ouvertes.

## Réexaminer si
- Les snapshots NFR-08 en répétition montrent une variation de composition inacceptable malgré les exemples.
- Q-37 ou Q-17 est tranchée d'une façon qui rend les exemples impraticables.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-38 ouverte par l'architecture | Assistant |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur | Assistant |
| 2026-10-30 | Reconfirmée comme valable : [pdr-0060](pdr-0060-small-openai-text-model-guided-a2ui.md) (Q-17, réponse du porteur du 2026-10-30 : « Petit LLM OpenAI + repli (Recommandé) ») en est la mise en œuvre ; les écrans d'exemple guident un petit modèle texte, repli sur écrans fixes si NFR-02/03 échouent. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
