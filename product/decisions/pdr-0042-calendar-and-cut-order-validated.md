---
id: pdr-0042-calendar-and-cut-order-validated
title: "PDR-0042 — Calendrier daté accepté tel quel ; ordre de coupe C1 à C5 appliqué sans redemander"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/roadmap/roadmap.md]
links: [pdr-0027-talk-context-meetup-flutter-nantes, pdr-0033-optional-shortcuts-mouse-first, pdr-0031-github-actions-ci-linux, p-rm-roadmap, p-rm-backlog, p-rm-open-questions]
tags: [pdr, decision, calendrier, coupe, roadmap]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29 (choix « Oui, tout (Recommandé) »)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0042 — Calendrier et ordre de coupe validés

> **En bref.** Le calendrier daté de [roadmap.md](../roadmap/roadmap.md) est accepté tel quel : développement jusqu'au 9/11 au soir, gel les 10 et 11/11, talk le 12/11. L'ordre de coupe **C1 à C5** est accepté tel que proposé : si le temps manque, l'appliquer dans cet ordre sans redemander. **C6 à C10** touchent des exigences de la fiche : décision du porteur au cas par cas. Tranche Q-65.

Part de l'assistant : proposition (replanification du 2026-10-29), consignation de l'acceptation.

## Contexte
Q-65 : valider le calendrier (12 jours de construction, week-ends compris), la capacité supposée et l'ordre de coupe ([p-rm-roadmap](../roadmap/roadmap.md)).

## Hypothèses
- ✅ Capacité de 12 jours consécutifs (29/10 → 9/11), acceptée avec le calendrier.

## Options
1. **Calendrier tel quel, coupes C1-C5 pré-autorisées** (retenue)
2. Jours ouvrés seulement (− 4 j : couper C1 à C7 d'emblée)

## Décision
- Calendrier : développement jusqu'au lun. 9/11 au soir, gel mar. 10 et mer. 11/11, talk jeu. 12/11.
- C1 (SP-08 et stories), C2 (journal seul), C3 (CI réduite), C4 (scénarios Gherkin de la fiche seulement), C5 (souris seule) : à appliquer dans l'ordre si un point de contrôle est manqué, sans redemander.
- C6 à C10 : jamais appliquées sans décision explicite du porteur.

## Raisons
- Question posée au porteur : « Je lance le dispositif (commit sur main, worktree, première itération suivie ensemble) ? » ; option choisie : « Oui, tout (Recommandé) », dont le texte était : « Je mets à jour AGENTS.md § 2 (backend local dans ce dépôt, sans auth), j'enregistre le calendrier et l'ordre de coupe C1-C5 tels que proposés, je commite, je crée le worktree et je lance la boucle dès que xvfb est installé. »

## Options écartées
- Jours ouvrés seulement : non retenu (le calendrier est accepté tel quel).

## Conséquences
- [p-rm-roadmap](../roadmap/roadmap.md) : calendrier et ordre de coupe passent à « validé » ; Q-65 tranchée.
- C6 à C10 touchent FR-06, FR-07, FR-08, FR-09, FR-12, FR-17, FR-18 : une PDR par coupe.

## Réexaminer si
- Un jalon dérive au point que C1 à C5 ne suffisent pas.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : choix « Oui, tout (Recommandé) » (texte cité en Raisons), conversation | Benoît FONTAINE (porteur) |

Pas d'archive brute.
