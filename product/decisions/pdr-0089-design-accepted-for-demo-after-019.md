---
id: pdr-0089-design-accepted-for-demo-after-019
title: "PDR-0089 — L'UI livrée par 017 à 019 est validée pour la démo après essai en direct ; pas de fonctionnalité 020 de finition"
area: decisions
status: validated
updated: 2026-11-03
sources: [specs/019-design-system-fidelity/status.md, specs/progress.md]
links: [pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0085-replay-bar-not-covered-by-protocol-panel, pdr-0086-018-protocol-panel-above-bottom-row-assistant-decided, pdr-0087-design-system-fidelity-no-24px-minimum, pdr-0088-019-design-system-fidelity-ui-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, p-rm-open-questions]
tags: [pdr, decision, design-system, ui, demo]
decision_status: acceptée
decided_on: 2026-11-03
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0089 — UI validée pour la démo après 019, pas de 020

> **En bref.** Le porteur a testé en direct l'application depuis `main` (`tools/demo/run.sh --keep`) et valide l'UI livrée par 017, 018 et 019 pour la démo. Aucune fonctionnalité 020 de finition. Les choix de 019 restent. Q-92 et Q-94 sont closes ; Q-93 reste ouverte.

L'assistant a consigné la parole du porteur ; il n'a rien arbitré.

## Contexte
Après la publication de 019 (`c032887`), l'assistant avait listé les écarts restants avec le design system (barre du haut non composée comme le design system, cadre de génération affiché à la fin de l'acte 3, « REJEU » collé au bouton Lecture, Q-94 a et b, Q-92 b à e) et proposé une fonctionnalité 020 de finition. Le porteur a préféré tester lui-même.

## Hypothèses
- ✅ L'essai a eu lieu en direct, depuis `main`, le 2026-11-03 (parole du porteur).
- ⚠️ Hypothèse non confirmée : la lisibilité au fond de la salle (NFR-05, suspendue par pdr-0087) et les 60 i/s restent à observer en répétition → [p-rm-open-questions](../roadmap/open-questions.md) (Q-80 pour le réglage des mesures ; Q-93 pour le panneau déplié).

## Options
1. **Valider l'UI en l'état, pas de 020.**
2. Fonctionnalité 020 de finition des écarts listés (proposée par l'assistant, non retenue).

## Décision
- L'UI livrée par 017 à 019 est validée pour la démo.
- Aucune fonctionnalité 020 de finition n'est lancée.
- Les choix de 019 restent : pas de « vs seuil » calculé, écarts du KeyIndicator non colorés (pdr-0064 D7, pdr-0088 F3).
- Q-92 (b à e) est acceptée en l'état ; Q-94 (a et b) est close sur les choix de 019.
- Q-93 n'est pas tranchée : elle reste à observer en répétition, panneau replié par défaut.
- NFR-05 reste suspendue (pdr-0087).

## Raisons
- Parole du porteur après essai en direct : « Ok, je viens de tester et ça me va. Ce sera suffisant pour la démo. »

## Options écartées
- Fonctionnalité 020 : le porteur juge le rendu suffisant pour la démo.

## Conséquences
- Q-92 et Q-94 : « Tranchée → pdr-0089 (2026-11-03) ». Q-93 : note datée seulement.
- Reste pour J7, en répétition : Q-79, Q-80, Q-87, Q-90, Q-93, SP-06, mesure des 60 i/s.

## Réexaminer si
- La répétition montre une lisibilité insuffisante au fond de la salle ou un recouvrement gênant (Q-93).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-03 | Acceptée. Parole citée (conversation Claude Code, 2026-11-03) : « Ok, je viens de tester et ça me va. Ce sera suffisant pour la démo. » | Benoît FONTAINE (porteur) |

Pas d'archive brute.
