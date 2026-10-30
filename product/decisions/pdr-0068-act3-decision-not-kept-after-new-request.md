---
id: pdr-0068-act3-decision-not-kept-after-new-request
title: "PDR-0068 — Décision « Bloquée » / « Validée » non conservée après une nouvelle demande"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/roadmap/open-questions.md]
links: [p-rm-open-questions, pdr-0065-009-act3-interact-details-assistant-decided]
tags: [pdr, decision, act-3, limite]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0068 — Décision « Bloquée » / « Validée » non conservée après une nouvelle demande

> **En bref.** On **accepte la limite** : si le speaker redemande une vue après l'acte 3 (« plutôt iOS »), l'agent Livraison, sans état, réécrit la checklist et la décision repasse à « En attente de décision ». Le déroulé du talk ne fait aucune demande après le clic.

Part de l'assistant : recommandation et mise en forme.

## Contexte
Relevé à la revue du plan de 009 ([pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) D3) : l'agent Livraison est sans état ; une demande vocale ultérieure réécrit tout `/checklist`. Question Q-76 ([p-rm-open-questions](../roadmap/open-questions.md)).

## Options
1. **Accepter la limite** (retenue)
2. Conserver la décision dans le registre du canevas et la réappliquer

## Décision
- Aucune persistance de la décision humaine au-delà de la demande suivante ; la limite reste décrite par un test.
- La consigne de régie (stage-runtime) précise : pas de nouvelle demande après l'acte 3 ; remise à vide avant de rejouer.

## Raisons
Recommandation de l'assistant validée par le porteur. Question posée : « Q-68 et Q-76 : je les tranche selon mes recommandations (session GPT-Live plafonnée à 30 min ; limite « décision perdue si on redemande une vue après l'acte 3 » acceptée) ? » Réponse : « Oui, les deux (Recommandé) ».

## Options écartées
- Option 2 : travail supplémentaire (registre, réapplication, tests) sans bénéfice pour le déroulé du talk.

## Conséquences
- [p-ar-stage-runtime](../architecture/stage-runtime.md) : consigne de régie ajoutée.

## Réexaminer si
- Le déroulé du talk ajoute une demande après l'acte 3, ou une répétition montre le cas.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée ; Q-76 tranchée (réponse : « Oui, les deux (Recommandé) ») | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
