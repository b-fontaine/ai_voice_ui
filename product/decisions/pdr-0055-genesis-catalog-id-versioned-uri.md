---
id: pdr-0055-genesis-catalog-id-versioned-uri
title: "PDR-0055 — catalogId définitif : URI versionnée `genesis/v1`"
area: decisions
status: validated
updated: 2026-10-30
sources: [knowledge:genui-catalog-ids, specs/006-j3-act1-backend/status.md]
links: [p-rm-open-questions, p-ar-app-channel-contract, p-ar-frontend, p-ar-backend, p-ar-security, genui-catalog-ids]
tags: [pdr, decision, catalogue, a2ui]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0055 — catalogId définitif : URI versionnée `genesis/v1`

> **En bref.** Tranche Q-44. `catalogId` = `https://genesis-canvas.example/a2ui/catalogs/genesis/v1`, l'URI versionnée du compose.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-44 : la maquette affiche `genesis.release` ; la convention recommande une URI versionnée ([genui-catalog-ids]). 006 : paramètre `A2UI_CATALOG_ID`, défaut provisoire du compose.

## Hypothèses
- ✅ La maquette ne fonde pas un point technique (pdr-0017).

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : le `catalogId` définitif est `https://genesis-canvas.example/a2ui/catalogs/genesis/v1` (valeur du compose), convention [genui-catalog-ids]. Une évolution incompatible du catalogue crée `…/v2`.

## Raisons
- Convention de la base de connaissances ; valeur déjà en place.
- Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ».

## Options écartées
- `genesis.release` (maquette) : sans valeur technique.

## Conséquences
- Documents d'architecture : « provisoire » retiré ([p-ar-app-channel-contract](../architecture/app-channel-contract.md), [p-ar-backend](../architecture/backend.md), [p-ar-frontend](../architecture/frontend.md)).

## Réexaminer si
- l'hébergeur du domaine d'exemple devient une contrainte (alors : URI réelle contrôlée).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Les recommandations pour Q-71, Q-30, Q-31, Q-22, Q-35, Q-44, Q-69, Q-72, Q-70, Q-21, Q-32, Q-49 et Q-52 (blocs A, B et C) te conviennent-elles ? » → option « Toutes validées (Recommandé) ». Tranche Q-44. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
