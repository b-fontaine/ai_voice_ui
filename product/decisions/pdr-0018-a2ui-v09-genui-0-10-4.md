---
id: pdr-0018-a2ui-v09-genui-0-10-4
title: "PDR-0018 — La démo parle A2UI v0.9 (\"version\": \"v0.9\") avec genui 0.10.4 figé"
area: decisions
status: validated
updated: 2026-10-29
sources: [knowledge:genui-overview, knowledge:genui-a2ui-overview, knowledge:genui-a2ui-messages, knowledge:genui-a2ui-v1-rc, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-mockups, p-ar-stack, p-ar-agents-protocols, p-ar-frontend, p-ar-backend, p-ar-replay, p-ar-quality, p-rm-spikes, p-rm-backlog, p-rm-backend-production-plan, p-rm-beyond, p-fn-glossary, pdr-0008-single-screen-show-the-making, pdr-0010-pinned-experimental-versions, pdr-0017-source-hierarchy-sheet-over-mockups, genui-overview, genui-a2ui-overview, genui-a2ui-messages, genui-a2ui-v1-rc]
tags: [pdr, decision, a2ui, genui, versions, decision-contrainte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [genui-overview, genui-a2ui-overview, genui-a2ui-messages, pdr-0008-single-screen-show-the-making, pdr-0010-pinned-experimental-versions, pdr-0017-source-hierarchy-sheet-over-mockups]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0018 — A2UI v0.9 avec genui 0.10.4 figé

> **En bref.** Décision contrainte, tranche Q-03 (E3). La démo émet et affiche des messages A2UI **v0.9** (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`), avec `"version": "v0.9"` exactement, rendus par `genui` **0.10.4** figé. La mention « A2UI v0.8 » de l'illustration est sans portée.

Part de l'assistant : décision contrainte, prise sur délégation du porteur ; le porteur peut la contester (elle serait alors remplacée par une PDR de sa main).

## Contexte
- Q-03 demandait quelle version A2UI montrer : l'illustration affiche des messages v0.8 (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`) ; la fiche ne fixe pas de version.
- Faits vérifiés : genui 0.10.x parle **v0.9** ; v0.9.1 est la version de production de la spec, v1.0 est une release candidate, v0.8 est legacy [genui-a2ui-overview]. `genui` 0.10.4 est la dernière version publiée (relevé du 2026-10-26) ; 0.10.6 n'est pas publiée [genui-overview].
- Le parseur `a2ui_core` 0.1.x utilisé par genui 0.10.4 rejette toute `version` différente de `"v0.9"`, y compris `"v0.9.1"` [genui-a2ui-overview], [genui-a2ui-messages].
- Décisions : le panneau « flux du protocole » montre les vrais messages [pdr-0008](pdr-0008-single-screen-show-the-making.md) ; versions figées [pdr-0010](pdr-0010-pinned-experimental-versions.md) ; la maquette ne compte pas pour le technique [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md).

## Hypothèses
- ✅ genui 0.10.4 + `a2ui_core ^0.1.0` = v0.9 (faits vérifiés du 2026-10-26).
- La publication éventuelle d'une version plus récente est revérifiée par SP-01 ([spikes.md](../roadmap/spikes.md)) ; ce n'est pas une hypothèse de la décision mais une condition de réexamen.

## Options
1. **A2UI v0.9, genui 0.10.4** (retenue)
2. A2UI v0.8 (illustration)
3. A2UI v1.0

## Décision
- Messages agent → app : `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`, champ `"version": "v0.9"` exactement (jamais `"v0.9.1"`).
- `genui: 0.10.4` épinglé sans `^`, avec `a2ui_core` résolu en `^0.1.0` par genui.
- La version reste un paramètre (`a2ui.version`), jamais une constante (AGENTS.md § 2).

## Raisons
- Une seule réponse correcte au vu des faits : genui 0.10.4 ne lit que v0.9, et le panneau doit montrer les vrais messages (pdr-0008).
- Parole du porteur, 2026-10-29 (conversation avec l'assistant), à propos de Q-03 : « Je ne comprends pas pourquoi c'est une question et que tu me demandes une décision... Tu as toutes les infos (v0.9 est la version stable mais aussi la seule utilisée dans genui), tu pouvais donc prendre la bonne décision seul, non ? »

## Options écartées
- **v0.8** : legacy, non lue par genui 0.10 [genui-a2ui-overview] ; l'afficher sans l'utiliser contredirait pdr-0008. La maquette ne compte pas pour le technique (pdr-0017).
- **v1.0** : release candidate ; genui 0.10.x ne l'implémente pas et aucune prise en charge n'est publiée [genui-a2ui-v1-rc].

## Conséquences
- [p-ar-stack](../architecture/stack.md), [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-frontend](../architecture/frontend.md), [p-ar-backend](../architecture/backend.md), [p-ar-replay](../architecture/replay.md), [p-ar-quality](../architecture/quality.md) : noms v0.9 et `a2ui.version = v0.9` sans réserve.
- [p-rm-spikes](../roadmap/spikes.md) SP-01 : la question de version est tranchée ; le spike garde la vérification des versions publiées et de `genui_a2a`.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-03 tranchée. [p-fn-mockups](../functional/mockups.md) : E3 tranché.
- Le panneau affiche du v0.9 ; la mention v0.8 de l'illustration est sans portée.

## Réexaminer si
- genui publie une version qui prend en charge A2UI v1.0 avant l'entrée en J7 **et** le coût de migration est faible (port A2UI, paramètre `a2ui.version`).
- SP-01 constate que genui 0.10.4 n'est plus résoluble ou qu'une 0.10.x corrective est nécessaire (montée dans une PR dédiée, pdr-0010).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Q-03 ouverte sans recommandation (consigne « tout laisser ouvert ») | Assistant |
| 2026-10-29 | Parole du porteur : « Je ne comprends pas pourquoi c'est une question et que tu me demandes une décision... Tu as toutes les infos (v0.9 est la version stable mais aussi la seule utilisée dans genui), tu pouvais donc prendre la bonne décision seul, non ? » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Acceptée comme décision contrainte, sur délégation du porteur | Assistant |

Pas d'archive brute.
