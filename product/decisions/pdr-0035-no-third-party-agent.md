---
id: pdr-0035-no-third-party-agent
title: "PDR-0035 — Pas d'agent d'un autre éditeur dans la démo"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p3]
links: [pdr-0004-mvp-three-acts, pdr-0036-real-a2a-agents-produce-a2ui, p-rm-beyond, p-ar-security, p-rm-open-questions, p-fn-mockups]
tags: [pdr, decision, agents, a2a, perimetre]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0035 — Pas d'agent tiers

> **En bref.** La démo ne montre pas d'agent d'un autre éditeur ; aucun acte n'est ajouté. Tranche Q-10 (E6).

Part de l'assistant : consignation.

## Contexte
- Fiche § 3 : un agent d'un autre éditeur serait « l'argument le plus fort du multi-agents », au prix d'un acte de plus (E6, Q-10). [pdr-0004](pdr-0004-mvp-three-acts.md) laissait la question ouverte.

## Hypothèses
- Aucune.

## Options
1. **Non** (retenue)
2. Oui, acte supplémentaire
3. Après le talk

## Décision
- Pas d'agent tiers dans la démo. Tous les agents A2A sont ceux du produit ([pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md)).

## Raisons
- Parole du porteur (2026-10-29), Q-10 : « Non, l'intérêt n'est pas là ».

## Options écartées
- **Acte supplémentaire** : écarté par le porteur.
- **Piste après le talk** : non tranchée ; le porteur ne s'est prononcé que sur la démo. La piste reste dans [beyond.md](../roadmap/beyond.md), à confirmer.

## Conséquences
- [pdr-0004](pdr-0004-mvp-three-acts.md) : option « agent d'un autre éditeur » close (historique).
- [p-rm-beyond](../roadmap/beyond.md) : piste « Agent tiers en A2A » hors de la démo ; après le talk, à confirmer par le porteur.
- [p-ar-security](../architecture/security.md) : menace « agent A2A non fiable » sans objet pour la démo.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-10 tranchée.

## Réexaminer si
- Le porteur change d'avis.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Non, l'intérêt n'est pas là » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Revue : portée limitée à la démo ; la piste « après le talk » n'est plus présentée comme écartée par le porteur | Assistant |

Pas d'archive brute.
