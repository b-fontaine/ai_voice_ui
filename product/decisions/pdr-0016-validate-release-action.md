---
id: pdr-0016-validate-release-action
title: "PDR-0016 — « Valider la release » se comporte comme « Bloquer la release »"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p10, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-business-rules, p-fn-catalog, p-fn-requirements, p-fn-mockups, p-rm-roadmap, p-rm-backlog, pdr-0014-six-component-catalog]
tags: [pdr, decision, actions, checklist]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0016 — « Valider la release » se comporte comme « Bloquer la release »

> **En bref.** Tranche Q-62. L'action « Valider la release » de la Barre d'actions fonctionne comme « Bloquer la release » : clic transmis à Livraison, confirmation vocale, statut de la checklist mis à jour (par exemple « Validée »).

Part de l'assistant : recommandation et mise en forme ; la décision est du porteur.

## Contexte
Fiche § 7 : deux décisions possibles, « Bloquer la release » et « Valider la release » ; seul « Bloquer » est spécifié (S-03, RG-28).

## Hypothèses
- ⚠️ Q-63 reste ouverte : aucun scénario Gherkin n'est ajouté pour « Valider ».

## Options
1. **Symétrique de « Bloquer »** (retenue)
2. Affichée mais inactive
3. Retirée

## Décision
« Valider la release » : clic transmis à l'agent Livraison, confirmation vocale, statut de la checklist mis à jour (par exemple « Validée »), selon RG-18 et RG-28.

## Raisons
Parole du porteur, 2026-10-29 (conversation avec l'assistant), après présentation des recommandations : « oui, enregistre tes recommandations comme décision. Je les valide. »
Peu coûteux ; évite un bouton qui ne fait rien sur scène.

## Options écartées
- Option 2 : bouton inerte devant le public.
- Option 3 : s'écarte de la fiche, qui cite les deux décisions.

## Conséquences
- [p-fn-business-rules](../functional/business-rules.md) : nouvelle RG-30. [p-fn-catalog](../functional/catalog.md), [p-fn-mockups](../functional/mockups.md).
- Les `.feature` ne changent pas (Q-63 ouverte).
- Roadmap : dépendance Q-62 levée (J5, EP-06).

## Réexaminer si
- Un scénario BDD de « Valider » est ajouté (Q-63) et révèle un comportement différent.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Recommandation présentée par l'assistant | Assistant |
| 2026-10-29 | Acceptée, sur la parole « oui, enregistre tes recommandations comme décision. Je les valide. » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
