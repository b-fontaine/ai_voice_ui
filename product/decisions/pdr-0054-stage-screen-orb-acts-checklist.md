---
id: pdr-0054-stage-screen-orb-acts-checklist
title: "PDR-0054 — Écran de scène : orbe « Réflexion », 6 zones, indicateur d'acte, statuts de checklist"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7]
links: [p-rm-open-questions, p-fn-screen, p-fn-catalog, p-fn-mockups, p-fn-business-rules, pdr-0014-six-component-catalog, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0004-mvp-three-acts]
tags: [pdr, decision, ecran, orbe, checklist]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0054 — Écran de scène : orbe « Réflexion », 6 zones, indicateur d'acte, statuts de checklist

> **En bref.** Tranche Q-30, Q-31, Q-22 et Q-35 : l'écran suit la fiche (§ 2, § 6, § 7), avec un petit indicateur « Acte n/3 » ajouté dans la barre supérieure.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Écarts E12 (Q-30), E13 (Q-31), E9 (Q-22) et E17 (Q-35) entre la fiche et les maquettes ([p-fn-mockups](../functional/mockups.md)). La fiche l'emporte ([pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md)) ; Q-22 est un ajout, la fiche étant muette.

## Hypothèses
- ✅ La fiche § 6 prévoit l'état « Réflexion » et l'orbe dans la barre supérieure, 6 zones dont Rejeu, flux replié par défaut (§ 6, § 2), statuts de checklist validé / à risque / bloquant (§ 7).

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** :
- **Q-30** : état « Réflexion » pendant le travail des agents ; orbe dans la barre supérieure.
- **Q-31** : les 6 zones, dont la zone Rejeu ; flux du protocole **replié par défaut**, déplié une fois pendant l'acte 1 (fiche § 2).
- **Q-22** : petit indicateur « Acte n/3 · <nom> » dans la barre supérieure, avec les 3 actes de la fiche (Créer, Transformer, Interagir).
- **Q-35** : statuts de la checklist selon la fiche § 7 : validé / à risque / bloquant ; l'en-tête est hors catalogue ([pdr-0014](pdr-0014-six-component-catalog.md)).

## Raisons
- Conformité à la fiche (pdr-0017) ; l'indicateur d'acte aide le public sans coût de catalogue.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- Pastille « EN ÉCOUTE » pendant le travail, indicateur « 1/3 · VIDE » à trois étapes différentes des actes, ✓ / ✗ seulement : maquettes, illustrations seulement.

## Conséquences
- [p-fn-screen](../functional/screen.md), [p-fn-catalog](../functional/catalog.md), [p-fn-business-rules](../functional/business-rules.md) (RG-28), [p-fn-mockups](../functional/mockups.md) : écarts E9, E12, E13, E17 tranchés.
- Débloque la fonctionnalité 007 (J3-B).

## Réexaminer si
- la répétition montre que l'indicateur d'acte distrait ou que le flux replié est illisible.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-30, Q-31, Q-22, Q-35. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
