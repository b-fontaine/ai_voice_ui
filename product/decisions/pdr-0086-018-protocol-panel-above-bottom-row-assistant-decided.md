---
id: pdr-0086-018-protocol-panel-above-bottom-row-assistant-decided
title: "PDR-0086 — 018 : le panneau du protocole déplié se pose au-dessus de la rangée du bas (mise en page tranchée par la boucle)"
area: decisions
status: validated
updated: 2026-11-03
sources: [specs/018-replay-bar-reachable/spec.md, specs/018-replay-bar-reachable/plan.md, specs/018-replay-bar-reachable/status.md, product/roadmap/open-questions.md#Q-92]
links: [pdr-0085-replay-bar-not-covered-by-protocol-panel, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0066-010-act4-replay-details-assistant-decided, p-ar-replay, p-ar-frontend-screen, p-rm-open-questions]
tags: [pdr, decision, replay, protocole, mise-en-page, 018]
decision_status: acceptée
decided_on: 2026-11-03
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0086 — 018 : le panneau du protocole déplié se pose au-dessus de la rangée du bas

> **En bref.** Pour que la barre de rejeu reste atteignable ([pdr-0085](pdr-0085-replay-bar-not-covered-by-protocol-panel.md)), la boucle ancre le panneau du protocole déplié **juste au-dessus de la rangée du bas**, au lieu de le laisser la recouvrir. Détail d'interface tranché sous pdr-0062 ; le porteur peut le contester.

Part de l'assistant : décision de mise en page prise par la boucle (fiche muette), pas un arbitrage du porteur.

## Contexte
Le panneau déplié (780×620, ancré en bas à droite) recouvrait x 1116..1896, y 452..1072 à 1920×1080, donc la droite de la barre de rejeu (Q-92 a, pdr-0085). Coordonnées à 1920×1080 : barre du haut y 8..136, rail 144..240, canevas 248..924, rangée du bas 932..1072.

## Hypothèses
- ✅ Le recouvrement du canevas par le panneau déplié est un comportement décidé en 007 (jamais de redimensionnement du canevas).

## Options
1. **Ancrer le panneau déplié au-dessus de la rangée du bas** (retenue) : bord bas à 148 px du bas de la zone, hauteur 620, y 304..924 ; l'emplacement replié reste réservé et vide tant que le panneau est déplié.
2. Réduire la hauteur dépliée à 472 px (bas conservé) : rendrait la rangée du bas visible mais passerait le panneau à 3 entrées (le nombre d'entrées est hors périmètre de 018).
3. Déplacer la barre de rejeu : changerait un rectangle de 013 et de 017.

## Décision
- Déplié, le panneau est posé avec un retrait de 148 px (140 de rangée du bas + 8 d'écart) au-dessus du bas de la zone ; replié, rien ne change (460×140 à sa place).
- Hauteur dépliée 620, plafonnée à la zone du canevas (676) : jamais sur le rail ni la barre du haut.
- Le canevas n'est toujours pas redimensionné (recouvrement), les rectangles de 013 et 017 sont inchangés.

## Raisons
- Seule option qui garde toutes les commandes visibles, le nombre d'entrées et les rectangles existants.
- Conséquence assumée : le panneau recouvre en plus y 304..452 de la colonne de droite (en 2×2, 246 des 302 px de la cellule de droite du haut sont masqués au lieu de 98) ; le contour pointillé de surbrillance de cette cellule peut rester caché en rejeu.

## Options écartées
- Hauteur 472 px (3 entrées) ; déplacement de la barre de rejeu (voir Options).

## Conséquences
- [p-ar-frontend-screen](../architecture/frontend-screen.md) § Acte 4 et [p-ar-replay](../architecture/replay.md) mis à jour à la clôture de 018.
- Le contournement de 017 ([pdr-0084](pdr-0084-017-design-system-ui-details-assistant-decided.md) U15 d : remplissage de la barre) n'est plus nécessaire dans son principe ; sa géométrie de 8 px est conservée pour ne pas bouger les rectangles.

## Réexaminer si
- La cellule de droite du haut doit rester visible en rejeu avec le panneau déplié (acte 1) ; le porteur préfère un panneau plus bas ou moins haut.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-03 | Acceptée dans le cadre de 018 (revue du plan, P4). | Assistant (délégation du porteur, pdr-0062) |
