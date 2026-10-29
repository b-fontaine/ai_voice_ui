---
id: pdr-0033-optional-shortcuts-mouse-first
title: "PDR-0033 — Raccourcis clavier facultatifs : toute action critique est faisable à la souris"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p10, knowledge:ux-desktop-shortcuts, knowledge:ux-desktop-focus]
links: [p-fn-screen, p-fn-requirements, p-fn-nfr, p-fn-business-rules, p-fn-risks-acceptance, p-ar-stage-runtime, p-rm-open-questions, pdr-0032-obs-video-fallback-a2ui-replay-act, adr-0004-ds-visual-base-m3, ux-desktop-shortcuts, ux-desktop-focus]
tags: [pdr, decision, raccourcis, souris, regie]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0033 — Raccourcis facultatifs, souris d'abord

> **En bref.** Toute action critique doit être faisable **à la souris** (bouton visible). Les raccourcis clavier s'ajoutent quand ils ne posent pas de problème (focus, conflit avec Espace sur un bouton focalisé). NFR-12, FR-11 et FR-20 sont assouplis. Tranche Q-05 (E5).

Part de l'assistant : consignation.

## Contexte
- Fiche § 6 : raccourcis Espace, M, P, R, B, ←/→ « proposés, à valider » ; NFR-12 : « Toutes les actions critiques ont un raccourci clavier ».
- Fait : un raccourci Flutter ne se déclenche que dans le sous-arbre focalisé, et Espace active aussi le bouton qui a le focus [ux-desktop-shortcuts], [ux-desktop-focus].

## Hypothèses
- Aucune.

## Options
1. **Souris d'abord, raccourcis s'ils ne posent pas de problème** (retenue)
2. Liste de raccourcis de la fiche, obligatoire

## Décision
- Chaque action critique (faire taire l'IA, couper le micro, remettre à vide, déplier le flux, piloter le rejeu) a un contrôle cliquable.
- Un raccourci n'est ajouté que s'il se déclenche de façon fiable et sans conflit ; sinon on s'en passe.
- La touche B (mode secours) disparaît avec le mode secours ([pdr-0032](pdr-0032-obs-video-fallback-a2ui-replay-act.md)).

## Raisons
- Parole du porteur (2026-10-29), Q-05 : « Si les racourcis posent problème, nous nous contenterons d'utiliser la souris. N'oublions pas que ce n'est qu'une démo. »

## Options écartées
- **Raccourcis obligatoires** : risque de focus et de conflit avec Espace, pour un gain faible en démo.

## Conséquences
- [p-fn-nfr](../functional/nfr.md) : NFR-12 « assoupli par pdr-0033 » (action critique faisable à la souris ; raccourci si sans problème).
- [p-fn-requirements](../functional/requirements.md) : FR-11 et FR-20 « assouplis par pdr-0033 » ; RG-21 précisée ([p-fn-business-rules](../functional/business-rules.md)).
- [p-fn-screen](../functional/screen.md), [p-ar-stage-runtime](../architecture/stage-runtime.md) : raccourcis facultatifs.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-05 tranchée.

## Réexaminer si
- Une action doit être faite pendant que les mains du porteur ne peuvent pas atteindre la souris.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Si les racourcis posent problème, nous nous contenterons d'utiliser la souris. N'oublions pas que ce n'est qu'une démo. » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
