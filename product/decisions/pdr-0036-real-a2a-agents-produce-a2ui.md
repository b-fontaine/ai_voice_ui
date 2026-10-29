---
id: pdr-0036-real-a2a-agents-produce-a2ui
title: "PDR-0036 — Agents A2A réels (un processus par agent) ; chaque agent produit l'A2UI de ses surfaces (penchant du porteur)"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p1, knowledge:ma-target-architecture, knowledge:proto-a2a-agent-card]
links: [pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0023-example-guided-composition, pdr-0008-single-screen-show-the-making, pdr-0029-local-docker-compose-hosting, pdr-0035-no-third-party-agent, p-ar-backend, p-ar-overview, p-ar-agents-protocols, p-rm-roadmap, p-rm-open-questions, ma-target-architecture, proto-a2a-agent-card, genui-a2ui-security]
tags: [pdr, decision, agents, a2a, a2ui, orchestrateur]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0036 — Agents A2A réels, chacun produit son A2UI

> **En bref.** Les agents spécialisés sont de **vrais serveurs A2A** : des processus séparés (le découpage du compose en un conteneur par agent est un choix de conception de l'assistant, [pdr-0029](pdr-0029-local-docker-compose-hosting.md)). **Chaque agent produit l'A2UI de ses surfaces** (penchant exprimé par le porteur), avec le catalogue partagé ([pdr-0014](pdr-0014-six-component-catalog.md)) et une composition guidée par exemples ([pdr-0023](pdr-0023-example-guided-composition.md)). L'orchestrateur planifie, délègue, valide et relaie. Tranche Q-16 et Q-37.

Part de l'assistant : Q-16, recommandation suivie (vrais serveurs A2A). Q-37, l'assistant n'avait rien recommandé ; le porteur a exprimé un **penchant** (« je penche pour »), consigné ici comme sa réponse. L'assistant **recommande désormais** cette option : elle correspond à la fiche § 1 (« des agents A2A qui renvoient de l'UI déclarative A2UI ») et montre au public, dans le panneau protocole, des messages A2UI venant de plusieurs agents ([pdr-0008](pdr-0008-single-screen-show-the-making.md)).

## Contexte
- Q-16 : vrais serveurs A2A séparés, ou agents internes exposés en A2A ?
- Q-37 : chaque agent produit-il l'A2UI, ou un composeur central compose-t-il à partir des données ? La fiche § 1 parle d'agents qui renvoient de l'UI ; [ma-target-architecture] décrit un agent GenUI central.

## Hypothèses
- ⚠️ Hypothèse non confirmée : un LLM texte par agent tient la latence NFR-02/NFR-03 ; à mesurer par SP-04 (choix du LLM : Q-17).

## Options
1. **Agents réels, chacun produit son A2UI** (retenue)
2. Agents réels qui renvoient des données, composeur A2UI central
3. Agents internes à l'orchestrateur

## Décision
- Chaque agent (Qualité, Voix du client, Livraison… [pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md)) est un serveur A2A distinct (processus séparé), avec son Agent Card [proto-a2a-agent-card].
- Penchant du porteur (Q-37) : chaque agent produit les messages A2UI v0.9 de ses surfaces, avec le catalogue fermé partagé et les exemples d'écrans attendus.
- L'orchestrateur planifie, choisit les agents, délègue, **valide** l'A2UI contre le catalogue [genui-a2ui-security] et le relaie à l'app sans le recomposer. Éviter les collisions de `surfaceId` entre agents est un détail de conception (J2), pas une décision.

## Raisons
- Parole du porteur (2026-10-29), Q-16 : « agents réels ».
- Parole du porteur (2026-10-29), Q-37 : « Vu que tu ne recommandes rien, je penche pour que chaque agent A2A produise l'A2UI ».

## Options écartées
- **Composeur central** : moins fidèle à la fiche § 1 ; le panneau protocole ne montrerait qu'une source.
- **Agents internes** : le message du talk sur A2A perdrait en crédibilité.

## Conséquences
- [p-ar-backend](../architecture/backend.md) : module `a2ui` = validation et relais ; production A2UI dans `agents/*`.
- [p-ar-overview](../architecture/overview.md) : topologie A2UI décidée ; un processus par agent (un conteneur chacun : choix de conception, [pdr-0029](pdr-0029-local-docker-compose-hosting.md)).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-16 et Q-37 tranchées.

## Réexaminer si
- SP-04 montre que la latence par agent dépasse NFR-03.
- Le porteur précise son penchant sur Q-37 dans l'autre sens.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : Q-16 « agents réels » ; Q-37 « je penche pour que chaque agent A2A produise l'A2UI » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Revue : Q-37 qualifiée de « penchant du porteur » ; la mention d'un échange « après coup », non sourcé, est retirée ; l'assistant recommande cette option (fiche § 1, panneau protocole multi-agents) ; « un conteneur par agent » requalifié en choix de conception | Assistant |

Pas d'archive brute.
