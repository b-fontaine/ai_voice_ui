---
id: pdr-0056-failed-agent-partial-surfaces-removed
title: "PDR-0056 — Un agent en échec après affichage partiel : ses surfaces sont retirées"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/004-j2-orchestrator-quality-agent/status.md, specs/006-j3-act1-backend/status.md]
links: [p-rm-open-questions, p-ar-app-channel-contract, p-ar-backend, p-ar-agents-protocols, p-fn-business-rules, pdr-0036-real-a2a-agents-produce-a2ui]
tags: [pdr, decision, echec, a2ui]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0056 — Un agent en échec après affichage partiel : ses surfaces sont retirées

> **En bref.** Tranche Q-69. Si un agent échoue après avoir fait afficher une partie de sa surface, l'orchestrateur la retire (`deleteSurface`), comme le prévoit FR-16.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-69 : RG-10 (état neutre pour données incomplètes) contre RG-14 / FR-16 (surfaces inachevées retirées). Comportement provisoire de 004/006 : retrait.

## Hypothèses
- ✅ Comportement déjà livré pour `failed` (006, scénario G3).

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : les surfaces d'un agent qui échoue après affichage partiel sont **retirées** (`deleteSurface` émis par l'orchestrateur) ; les surfaces des autres agents restent. Un `rejected` n'a rien à compenser.

## Raisons
- Cohérent avec FR-16 ; pas d'écran à moitié construit sur scène.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- Laisser en état neutre ; retirer sauf si le `root` est complet : écartées par le porteur (validation de la reco).

## Conséquences
- Marques « provisoire » levées dans [p-ar-app-channel-contract](../architecture/app-channel-contract.md) et [p-ar-backend](../architecture/backend.md).

## Réexaminer si
- la répétition montre qu'un écran partiel vaut mieux qu'un trou.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-69. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
