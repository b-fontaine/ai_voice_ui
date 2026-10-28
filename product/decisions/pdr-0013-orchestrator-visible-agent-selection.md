---
id: pdr-0013-orchestrator-visible-agent-selection
title: "PDR-0013 — L'orchestrateur choisit visiblement ses agents, nommés par rôle métier"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p2, product/sources/design-example.pdf]
links: [p-rm-open-questions, p-fn-scope, p-fn-business-rules, p-fn-requirements, p-fn-screen, p-fn-mockups, p-fn-glossary, p-ar-agents-protocols, p-ar-backend, p-ar-overview, pdr-0003-use-case-release-copilot, pdr-0008-single-screen-show-the-making]
tags: [pdr, decision, agents, orchestrator, rail]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0013 — L'orchestrateur choisit visiblement ses agents

> **En bref.** Tranche Q-01 (écart E1). Ce qui compte, c'est de **montrer que l'orchestrateur choisit quels agents il active** : le rail distingue les agents sollicités des agents en veille. Le nombre d'agents n'est pas un critère. Les agents portent les **noms métier de la fiche** (Qualité, Voix du client, Livraison), pas les noms de source de données des maquettes.

Part de l'assistant : mise en forme et propagation ; la décision est du porteur.

## Contexte
Fiche § 3 : un orchestrateur et 3 agents (Qualité, Voix du client, Livraison). Maquettes : 4 agents nommés par source (Crash, Avis stores, Changelog, Captures d'écran), dont un toujours « en veille », et un orchestrateur qui « planifie · 4 tâches » puis « délègue · 3 tâches ». Voir [p-fn-mockups](../functional/mockups.md) (E1).

## Hypothèses
- ✅ Le rail des agents est une zone de l'écran unique ([pdr-0008](pdr-0008-single-screen-show-the-making.md)).
- ✅ Avec les 3 agents de la fiche, la sélection est déjà visible : à l'acte 2, Livraison reste en veille (maquette 3, « Changelog en veille ») ; à l'acte 3, seul Livraison s'allume (S-03).

## Options
1. **Montrer la sélection par l'orchestrateur ; nombre libre ; noms de la fiche** (retenue)
2. 3 agents de la fiche, sans exigence de sélection visible
3. 4 agents des maquettes, nommés par source de données

## Décision
- L'orchestrateur est visible dans le rail et, à chaque demande, **choisit** les agents à activer.
- Le rail rend ce choix lisible : agents sollicités allumés avec leur tâche, agents non sollicités visiblement **en veille** (RG-29).
- Les agents sont nommés par **rôle métier**, selon la fiche : Qualité, Voix du client, Livraison. Un agent ajouté plus tard suit la même règle de nommage.
- Le nombre d'agents n'est pas fixé par cette décision.

## Raisons
Paroles du porteur, 2026-10-29 : « il faut un orchestrateur et montrer qu'il choisit quel agent est activé ou pas. Le nombre d'agents n'est pas si important. Par contre, les noms de la fiche produit sont meilleurs. »

## Options écartées
- Option 2 : ne montre pas que l'orchestrateur décide, ce qui est le point démontré par le rail.
- Option 3 : noms de source de données jugés moins bons par le porteur ; le nombre n'est pas un critère.

## Conséquences
- [p-fn-business-rules](../functional/business-rules.md) : nouvelle règle RG-29 (sélection visible).
- [p-fn-scope](../functional/scope.md), [p-fn-glossary](../functional/glossary.md), [p-fn-mockups](../functional/mockups.md) : E1 tranché.
- Scénarios Gherkin : les noms Qualité, Voix du client, Livraison restent ceux des `.feature`.
- [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-backend](../architecture/backend.md) : le plan de l'orchestrateur sélectionne un sous-ensemble d'agents ; la liste `agents[]` reste une configuration.
- Le journal A2A/A2UI doit garder la trace des agents choisis **et** non choisis, pour le rejeu ([p-ar-replay](../architecture/replay.md)).

## Réexaminer si
- La sélection n'est pas perçue en répétition (le public ne remarque pas les agents en veille).
- Un agent tiers est ajouté (Q-10, Q-16).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-01 tranchée | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
