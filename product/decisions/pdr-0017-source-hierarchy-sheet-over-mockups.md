---
id: pdr-0017-source-hierarchy-sheet-over-mockups
title: "PDR-0017 — La fiche produit fait foi ; les maquettes illustrent la vision et ne sont jamais une spécification"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf, product/sources/design-example.pdf]
links: [p-sources, p-conventions, p-fn-mockups, p-rm-open-questions, p-readme, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, adr-0007-ds-design-tool-claude-design]
tags: [pdr, decision, sources, maquettes, gouvernance]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0017 — Hiérarchie des sources produit

> **En bref.** La fiche produit est la référence. Les maquettes (`design-example.pdf`) illustrent la vision du porteur : elles ne sont jamais suivies à la lettre et ne comptent pas du tout sur un point technique. Un écart fiche/maquette n'est plus une question : la fiche l'emporte. Remplace la consigne du 2026-10-28 « tout laisser ouvert » sur les écarts.

Part de l'assistant : mise en forme ; la règle est du porteur.

## Contexte
- Le 2026-10-28, le porteur avait demandé de « tout laisser ouvert » : chaque écart fiche/maquettes (E1 à E22, [p-fn-mockups](../functional/mockups.md)) devenait une `Q-xx` sans recommandation ([p-rm-open-questions](../roadmap/open-questions.md)).
- Le 2026-10-29, le porteur précise le statut des maquettes (voir Raisons).

## Hypothèses
- ✅ La fiche produit est la seule source validée par le porteur ([p-sources](../sources/README.md)).

## Options
1. **Fiche = référence ; maquettes = illustration, sans portée technique** (retenue)
2. Laisser chaque écart ouvert jusqu'à arbitrage (consigne du 2026-10-28)

## Décision
1. **La fiche produit fait foi** pour le fonctionnel.
2. **Les maquettes illustrent la vision** : elles ne sont jamais une spécification ni suivies à la lettre.
3. **Écart fiche/maquette** : ce n'est pas une question ; la fiche l'emporte.
4. **Fiche muette** : la maquette n'est qu'une inspiration et n'impose rien ; le choix suit la procédure ordinaire (décision contrainte ou arbitrage du porteur).
5. **Point technique** (version A2UI, noms de messages, ids de surfaces, `Grid`, `catalogId`, `LineChart v2`…) : la maquette ne compte pas ; seuls les faits vérifiés (`knowledge/`, doc officielle) et les décisions (PDR, ADR hérités) décident.
6. **Exception** : les décisions déjà acceptées par le porteur ([pdr-0013](pdr-0013-orchestrator-visible-agent-selection.md) à [pdr-0016](pdr-0016-validate-release-action.md)) restent valables telles quelles, même quand elles s'inspirent des maquettes.

## Raisons
Parole du porteur, 2026-10-29 (conversation avec l'assistant) : « En fait, la maquette n'est qu'une démonstration de ma vision, une illustration. Il ne faut surtout pas la suivre à la lettre, et surtout pas pour des questions techniques. »

## Options écartées
- Option 2 : remplacée par cette PDR ; elle transformait chaque détail de l'illustration en question à trancher.

## Conséquences
- [p-sources](../sources/README.md) : statut des maquettes = illustration de la vision, sans portée technique.
- [p-conventions](../_conventions.md) § 4 : règle des écarts entre sources réécrite.
- [p-fn-mockups](../functional/mockups.md) : le registre E1..E22 devient « différences avec l'illustration ».
- [p-rm-open-questions](../roadmap/open-questions.md) : la mention « sans recommandation, consigne du porteur » est retirée ; les `Q-xx` issues d'écarts sont à fermer selon cette règle (suite du travail, pas dans cette PDR).
- `AGENTS.md` § 1 bis : une ligne rappelle la règle.
- La note d'application de [adr-0007-ds-design-tool-claude-design] dans `decisions/index.yaml` (« les maquettes sont une spécification ») est corrigée en conséquence.

## Réexaminer si
- Le porteur livre une maquette explicitement validée comme spécification (nouvelle source datée dans `product/sources/`).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Consigne « tout laisser ouvert » sur les écarts fiche/maquettes | Benoît FONTAINE (porteur) |
| 2026-10-29 | Acceptée, sur la parole « En fait, la maquette n'est qu'une démonstration de ma vision, une illustration. Il ne faut surtout pas la suivre à la lettre, et surtout pas pour des questions techniques. » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
