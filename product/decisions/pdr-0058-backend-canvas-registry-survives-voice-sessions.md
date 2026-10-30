---
id: pdr-0058-backend-canvas-registry-survives-voice-sessions
title: "PDR-0058 — Le registre de canevas vit côté backend et survit aux sessions voix"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/004-j2-orchestrator-quality-agent/status.md, specs/006-j3-act1-backend/status.md]
links: [p-rm-open-questions, p-ar-app-channel-contract, p-ar-backend, p-ar-stage-runtime, p-fn-requirements, pdr-0052-one-gpt-live-session-per-act-recommended, pdr-0015-app-held-canvas-layout]
tags: [pdr, decision, canevas, session, backend]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0058 — Le registre de canevas vit côté backend et survit aux sessions voix

> **En bref.** Tranche Q-70, option (a). Le backend porte un registre de canevas qui survit aux sessions voix ; la session voix ne porte que la conversation ; la remise à vide (FR-11) réinitialise l'état du canevas côté backend.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-70 : [pdr-0052](pdr-0052-one-gpt-live-session-per-act-recommended.md) (une session par acte) contre FR-07 (l'acte 2 modifie en place les surfaces de l'acte 1). 006 : le registre de l'orchestrateur est la seule source de vérité des surfaces actives.

## Hypothèses
- ✅ `ContextID` = id de session en 006 ; il faudra le rattacher à la démo (007+).

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : (a) le backend porte un registre de canevas (surfaces actives, contexte d'agent par démo) qui survit aux changements de session voix ; la session voix ne porte que la conversation ; la **remise à vide (FR-11)** réinitialise l'état du canevas côté backend.

## Raisons
- Compatible avec pdr-0052 et FR-07 ; source de vérité unique.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- (b) rejouer l'état à chaque session ; (c) session unique (contredit pdr-0052).

## Conséquences
- [p-ar-app-channel-contract](../architecture/app-channel-contract.md) et [p-ar-backend](../architecture/backend.md) : registre par démo, remise à vide.
- Débloque J4 (acte 2 en place).

## Réexaminer si
- une mesure de contexte permet la session unique (pdr-0052 réexaminée).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-70. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
