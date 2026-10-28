---
id: pdr-0008-single-screen-show-the-making
title: "PDR-0008 — Écran unique en 6 zones qui montre la fabrication de l'interface"
area: decisions
status: validated
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p8, product/sources/product-description.pdf#p9, product/sources/design-example.pdf, knowledge:genui-a2ui-messages, knowledge:ux-genui-streaming-loading]
links: [p-fn-screen, p-fn-mockups, p-fn-requirements, p-fn-nfr, p-ar-frontend, p-ar-agents-protocols, p-rm-open-questions, pdr-0002-desktop-platform, pdr-0006-replay-fallback-must, pdr-0007-closed-catalog-stage-theme, genui-a2ui-messages, ux-genui-streaming-loading, genui-multiple-surfaces]
tags: [pdr, decision, screen, layout, pedagogy]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0008 — Un écran unique qui montre la fabrication

> **En bref.** Genesis Canvas tient en un seul écran de 6 zones, qui montre en même temps le résultat (les surfaces générées) et sa fabrication (agents, messages du protocole, catalogue, rejeu). Le public voit l'interface se construire, pas seulement l'interface finie.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 1 (p. 1), problème adressé : « Les démos d'IA générative montrent un résultat fini, que le public ne distingue pas d'un écran codé à la main. Le flux réel […] reste invisible. »
- Fiche § 6 (p. 7) : « L'écran unique montre en même temps le résultat (le canevas) et sa fabrication (agents, protocole, catalogue). »
- Les 3 maquettes (design-example.pdf) illustrent cet écran à 3 moments : vide, construction, interaction → [p-fn-mockups](../functional/mockups.md).

## Hypothèses
- ✅ Projection 16:9 en 1920×1080 ([pdr-0002-desktop-platform](pdr-0002-desktop-platform.md)).
- ⚠️ Écart E3 non tranché : le flux du protocole des maquettes affiche des messages A2UI v0.8 (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`, « A2UI v0.8 ») ; la base knowledge décrit A2UI v0.9 (`createSurface`, `updateComponents`…) pour genui 0.10 [genui-a2ui-messages] → [p-rm-open-questions](../roadmap/open-questions.md) (Q-03).
- ⚠️ Raccourcis clavier « proposés, à valider » (fiche § 6) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-05).

## Options
1. **Écran unique montrant résultat et fabrication** (retenue).
2. Écran montrant le seul résultat fini : c'est le problème que la fiche veut résoudre.

## Décision
| Zone | Contenu (fiche § 6) |
|---|---|
| Barre supérieure | Orbe vocal (7 états), transcription en direct, forme d'onde |
| Canevas génératif | Surfaces générées, 6 au maximum, en 3 temps : squelette, composants, données |
| Rail des agents | Orchestrateur et agents spécialisés, allumés avec leur tâche, liaison animée |
| Flux du protocole | Messages d'interface des agents ; replié par défaut ; message en cours relié à son composant |
| Étagère du catalogue | Composants disponibles ; celui qui est utilisé s'allume |
| Rejeu | Curseur sur l'historique de la session ; sert aussi de mode secours |

Détail des zones, états de l'orbe et modes d'interaction : [p-fn-screen](../functional/screen.md).

## Raisons
- Fiche § 1 : rendre visible le flux voix → agents → JSON A2UI → widgets, sans quoi « la valeur de GenUI n'est pas démontrée ».
- Fiche § 6 : le pointillé qui relie le message du protocole au composant construit matérialise le message du talk.

## Options écartées
- **Montrer seulement le résultat fini** : c'est le défaut des démos existantes, fiche § 1.

## Conséquences
- **Exigences** : FR-03 (rail), FR-04 (3 temps), FR-05 (message mis en évidence), FR-06 (étagère), FR-19 (orbe), NFR-06 (6 surfaces au plus).
- **Architecture front** : le client doit exposer les messages A2UI reçus à l'UI (et pas seulement les rendre) pour alimenter le flux du protocole et le lien message → composant ; il gère plusieurs surfaces [genui-multiple-surfaces] et un rendu progressif [ux-genui-streaming-loading] → [p-ar-frontend](../architecture/frontend.md).
- **Architecture agents** : le rail suppose que l'app reçoit l'état des agents (sollicité, tâche) depuis l'orchestrateur backend → [p-ar-agents-protocols](../architecture/agents-protocols.md).
- **Lisibilité** : 6 zones sur un écran projeté, avec du texte d'au moins 24 px (NFR-05) ; tension à vérifier en répétition sur un vrai projecteur.
- **Rejeu** : la zone Rejeu porte aussi le mode secours → [pdr-0006-replay-fallback-must](pdr-0006-replay-fallback-must.md).

## Réexaminer si
- Les tests de lisibilité au projecteur montrent que 6 zones simultanées sont illisibles depuis le fond de salle.
- La répétition générale montre que le public ne relie pas le message du protocole au composant (test des 3 développeurs, fiche § 8).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 1, § 6) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR ; écart E3 signalé | Assistant (mise en forme) |

Pas d'archive brute.
