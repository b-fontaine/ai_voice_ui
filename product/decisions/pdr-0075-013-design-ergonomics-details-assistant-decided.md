---
id: pdr-0075-013-design-ergonomics-details-assistant-decided
title: "PDR-0075 — 013 : détails de design et d'ergonomie tranchés par la boucle (rail horizontal, cellules lisibles, apparition animée, tokens, Widgetbook)"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/013-design-ergonomie/spec.md, specs/013-design-ergonomie/plan.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [pdr-0072-design-ergonomics-013, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0007-closed-catalog-stage-theme, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0066-010-act4-replay-details-assistant-decided, pdr-0074-012-llm-composer-gateway-crashlist-details, p-fn-screen, p-fn-nfr, p-rm-open-questions, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0006-ds-no-widgetbook-cloud, adr-0008-ds-widgetbook-4-beta, ds-motion, ds-a11y-wcag-contrast, ds-a11y-wcag-focus-target]
tags: [pdr, decision, design, ergonomie, widgetbook, 013]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0075 — 013 : détails de design et d'ergonomie tranchés par la boucle

> **En bref.** La fiche est muette sur la mise en page fine ; la boucle tranche, sous [pdr-0062](pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md), les détails de 013. Le périmètre (design system, animations, 24 px, bande vide, titre de courbe, régie) est celui du porteur ([pdr-0072](pdr-0072-design-ergonomics-013.md)). Le porteur peut contester chaque point.

Part de l'assistant : décision de détail d'interface sur délégation permanente ; aucun choix de périmètre, de mise en scène, de budget ni de fournisseur.

## Contexte
Captures 1920×1080 de 012 : bande vide d'environ 220 px sous la barre du haut (le rail fixe de 200 px est vide hors session et en rejeu), libellés tronqués (Checklist, avis, étagère, [Q-83](../roadmap/open-questions.md)), boutons de régie à 44 px, panneau déplié qui déborde de 39 px, titre de courbe tronqué, aucune animation d'apparition (FR-04, NFR-04), thème de scène sans source de tokens ni catalogue visuel.

## Hypothèses
- ✅ La fiche ne fixe ni disposition fine ni animation (p-fn-screen) ; la maquette n'est qu'une inspiration ([pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md)).
- ⚠️ Hypothèse non confirmée : Node (Style Dictionary) est disponible chez le porteur. Parade : le code généré est committé et un test Dart de parité remplace la génération dans la porte ; Node n'est jamais requis pour lancer l'app.

## Options
1. **Rail horizontal de 96 px, canevas élastique, retour à la ligne, transitions implicites, tokens générés, Widgetbook isolé** (retenue).
2. Rail en colonne à gauche comme sur la maquette : le canevas gagne en hauteur mais perd environ 340 px de largeur ; les cellules de 620 px deviennent plus étroites encore (Q-83 aggravée).
3. Garder le rail de 200 px et réduire d'autres zones : la bande vide demeure hors session.

## Décision
- **D1 Mise en page** : rail des agents en **rangée horizontale de 96 px** (nom sur une ligne, état en toutes lettres dessous, texte ≥ 24 px) ; le canevas prend toute la hauteur restante (≈ 676 px à 1920×1080), calculée sur la hauteur disponible ; grille 2×2 puis 3×2 et bandeau de 72 px de la Barre d'actions inchangés (S-02, [pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) D7). Régie : indicateur d'acte et « Remettre à vide » en un groupe de deux contrôles à 48 px. Panneau du protocole déplié contenu dans la zone du canevas.
- **D2 Lisibilité (Q-83, option 1)** : les libellés de checklist, d'avis et les titres passent à la ligne (jamais d'ellipse) ; le titre de courbe tient sur sa ligne, légende dessous ; l'étagère affiche les six noms entiers ; seule la ligne d'un crash garde l'ellipse ([pdr-0074](pdr-0074-012-llm-composer-gateway-crashlist-details.md) D10).
- **D3 Apparition animée** : transitions implicites (fondu squelette → composants 200 ms, fondu des valeurs 150 ms, translation de 8 px, `easeOutCubic`, [ds-motion]) ; `disableAnimations` → durée zéro ; en rejeu à la vitesse v, durées divisées par v (plancher 60 ms) ; aucune transition ne change la taille ni la place d'une surface (S-02).
- **D4 Design system** : tokens DTCG dans Git, générés en Dart par Style Dictionary épinglé ([adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md)), code committé ; `SceneTheme` garde son API (RG-09) ; test de parité tokens ↔ thème dans la porte. Widgetbook 4.0.0-beta.14 épinglé, une story par composant et par brique, sans Cloud ([adr-0006](../../knowledge/decisions/adr-0006-ds-no-widgetbook-cloud.md), [adr-0008](../../knowledge/decisions/adr-0008-ds-widgetbook-4-beta.md)) ; paquet isolé du reste du workspace de la porte.
- **D5 Ordre et coupe** : lot A (corrections), lot B (animation), lot C (tokens, Widgetbook). Si le calendrier l'impose, le lot C est coupé en dernier, comme le prévoit [pdr-0072](pdr-0072-design-ergonomics-013.md) « Réexaminer si » ; la coupe est alors signalée dans `progress.md`.

## Raisons
- Le vide vient du rail fixe : le rendre horizontal rend 104 px au canevas sans réduire sa largeur (Q-83 concerne la largeur des cellules).
- Les transitions implicites coûtent peu de code, restent dans le budget de reconstruction (RepaintBoundary, [perf-repaint-boundary]) et respectent S-02.
- Le fichier généré committé et le test de parité tiennent la source de vérité sans imposer Node à la porte de la boucle (`tools/loop/` n'est pas modifiable par la boucle).

## Options écartées
- Rail en colonne (option 2) : aggrave Q-83.
- Rail de 200 px conservé (option 3) : la bande vide revient.
- Génération Node dans la porte : hypothèse « Node partout » non confirmée, et fichier de porte hors de portée de la boucle.

## Conséquences
- [p-fn-screen](../functional/screen.md) : budget des zones (rail 96, canevas ≈ 676), régie, repères de zone, à mettre à jour à la clôture de 013 ; [Q-83](../roadmap/open-questions.md) tranchée par D2 ; NFR-04 et NFR-05 mesurées par tests (la mesure DevTools reste à J7).
- Aucun contrat A2UI ni code Go ne change.

## Réexaminer si
- Le porteur préfère la maquette (rail en colonne) après avoir vu les captures de 013.
- Une cellule ne tient pas à 1366×768 (machine de répétition différente).
- Widgetbook 4 bêta casse le build (coupe du lot C).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (délégation pdr-0062) à l'étape « Définir » de 013. | Assistant (délégation du porteur) |

Pas d'archive brute.
