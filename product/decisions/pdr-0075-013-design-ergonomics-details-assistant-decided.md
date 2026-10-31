---
id: pdr-0075-013-design-ergonomics-details-assistant-decided
title: "PDR-0075 — 013 : détails de design et d'ergonomie tranchés par la boucle (rail horizontal, cellules lisibles, apparition animée, tokens, Widgetbook)"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/013-design-ergonomie/status.md, specs/013-design-ergonomie/spec.md, specs/013-design-ergonomie/plan.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-ar-design-system, p-fn-feature-design-ergonomics-013, p-ar-frontend-screen, p-ar-quality, pdr-0072-design-ergonomics-013, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0007-closed-catalog-stage-theme, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0066-010-act4-replay-details-assistant-decided, pdr-0074-012-llm-composer-gateway-crashlist-details, p-fn-screen, p-fn-nfr, p-rm-open-questions, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0006-ds-no-widgetbook-cloud, adr-0008-ds-widgetbook-4-beta, ds-motion, ds-a11y-wcag-contrast, ds-a11y-wcag-focus-target]
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
- ⚠️ Hypothèse non confirmée : Node (Style Dictionary) est disponible chez le porteur. Parade : le code généré est committé et un test Dart de parité remplace la génération dans la porte ; Node n'est jamais requis pour lancer l'app. Toujours non confirmée à la clôture : [Q-86](../roadmap/open-questions.md) (option 3 seulement si Node est requis chez le porteur).

## Options
1. **Rail horizontal de 96 px, canevas élastique, retour à la ligne, transitions implicites, tokens générés, Widgetbook isolé** (retenue).
2. Rail en colonne à gauche comme sur la maquette : le canevas gagne en hauteur mais perd environ 340 px de largeur ; les cellules de 620 px deviennent plus étroites encore (Q-83 aggravée).
3. Garder le rail de 200 px et réduire d'autres zones : la bande vide demeure hors session.

## Décision
- **D1 Mise en page** : rail des agents en **rangée horizontale de 96 px**, de hauteur fixe même vide (« AGENTS A2A » en colonne de tête ; tuile : nom, puis « état · tâche » ; texte ≥ 24 px) ; le canevas, déjà `Expanded`, passe à **676 px** à 1920×1080 (2 × 302 + 72) ; grille 2×2 puis 3×2 et bandeau de 72 px inchangés (S-02, [pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) D7). Pas de libellé « CANEVAS ». Régie : indicateur d'acte et « Remettre à vide » **empilés**, deux contrôles de largeur égale à 48 px (testés sous Linux). Panneau du protocole déplié : entrées affichées selon la hauteur disponible, dans la zone du canevas. La liaison animée de délégation (fiche, jamais livrée) n'est **pas** décidée ici : [Q-85](../roadmap/open-questions.md), porteur.
- **D2 Lisibilité (Q-83, option 1)** : les libellés de checklist et les titres passent à la ligne (capacité calculée par la hauteur réelle du texte) ; les **avis n'affichent que des extraits entiers qui tiennent, puis « + N avis »** (en 3×2, un ou deux extraits : assumé) ; le titre de courbe tient sur sa ligne, légende dessous ; l'étagère affiche six noms entiers en deux rangées de trois, l'état porté par une icône et `Semantics` (le compte reste dans l'en-tête) ; seule la ligne d'un crash garde l'ellipse ([pdr-0074](pdr-0074-012-llm-composer-gateway-crashlist-details.md) D10).
- **D3 Apparition animée** : un `AnimationController` par surface (fondu squelette → composants 200 ms, translation de 8 px, `easeOutCubic`, [ds-motion]) et fondu des valeurs 150 ms du seul passage « sans données » → « données » ; durée nulle si `disableAnimations` ou `_animationsOff` (via `SceneMotionScope`, jamais de `TickerMode`) ; en rejeu à la vitesse v, durées divisées par v (plancher 60 ms) ; aucune transition ne change la taille ni la place d'une surface (S-02). **Précision (T21c) :** le squelette part dès le passage `skeleton` → `components` et le contenu fond depuis le fond du canevas (les scénarios F-02 de 012 et C6 de 009 exigent « aucun squelette » aussitôt après les composants) ; pas de fondu croisé. Une surface déjà présente au premier rendu du canevas est visible sans fondu ; une surface qui arrive ensuite, même déjà en phase `data` (rejeu), s'anime. Le périmètre de reconstruction est refait (cellules sélectives) pour que l'arrivée d'une surface ne reconstruise ni ne repeigne ses voisines (NFR-04).
- **D4 Design system** : tokens DTCG dans Git, générés en Dart par Style Dictionary épinglé ([adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md)), code committé. **Écarts à adr-0005, contestables** : le format custom émet des **constantes** (`SceneTokens`) et non un second `ThemeExtension` (`SceneTheme` reste l'unique `ThemeExtension`, RG-09) ; la porte de la boucle ne lance pas Node (`tools/loop/` est hors de sa portée) et le fichier généré est contrôlé par un test de hash (sha256 en en-tête) et de parité, au lieu de `git diff --exit-code` en CI. Widgetbook 4.0.0-beta.14 épinglé, une story par composant et par brique, sans Cloud ([adr-0006](../../knowledge/decisions/adr-0006-ds-no-widgetbook-cloud.md), [adr-0008](../../knowledge/decisions/adr-0008-ds-widgetbook-4-beta.md)) ; **application `apps/genesis_widgetbook/` (couche app, membre du workspace)**, car `shared/*` ne peut dépendre de `feature_canvas` ; première tâche : prouver que la résolution pub et la porte restent vertes, sinon coupe C2.
- **D5 Ordre et coupe** : lot A (corrections), lot B (animation), lot C (tokens, Widgetbook). Si le calendrier l'impose, le lot C est coupé en dernier, comme le prévoit [pdr-0072](pdr-0072-design-ergonomics-013.md) « Réexaminer si » ; la coupe est alors signalée dans `progress.md`.

## Raisons
- Le vide vient du rail fixe de 200 px : le rendre horizontal rend 104 px au canevas sans réduire sa largeur (Q-83 concerne la largeur des cellules).
- Les transitions implicites coûtent peu de code, restent dans le budget de reconstruction (RepaintBoundary, [perf-repaint-boundary]) et respectent S-02.
- Le fichier généré committé et le test de parité tiennent la source de vérité sans imposer Node à la porte de la boucle (`tools/loop/` n'est pas modifiable par la boucle).

## Options écartées
- Rail en colonne (option 2) : aggrave Q-83.
- Rail de 200 px conservé (option 3) : la bande vide revient.
- Génération Node dans la porte : hypothèse « Node partout » non confirmée, et fichier de porte hors de portée de la boucle.
- Paquet Widgetbook « isolé » sous `design_system` : membre du workspace, il entre dans la résolution unique et dans `verify.sh` ; sous `shared/` il violerait la règle d'import.

## Conséquences
- [p-fn-screen](../functional/screen.md) : budget des zones (rail 96, canevas 676), régie, repères de zone, **mis à jour à la clôture de 013** ; [Q-83](../roadmap/open-questions.md) **tranchée par D2** (2026-10-31, contestable) ; NFR-04 et NFR-05 mesurées par tests (la mesure DevTools reste à J7).
- Aucun contrat A2UI ni code Go ne change.

## Réexaminer si
- Le porteur préfère la maquette (rail en colonne) après avoir vu les captures de 013.
- ⚠️ Observation à juger sur la capture (D2, option 2 de Q-83) : en 3×2 avec les données de l'acte 2, « Changelog validé » est masqué derrière « + 1 autres critères », un seul avis tient et la sixième cellule reste vide ; l'option 2 (disposition de la cinquième surface) toucherait S-02 et reste au porteur.
- Une cellule ne tient pas à 1366×768 (machine de répétition différente).
- Widgetbook 4 bêta casse le build (coupe du lot C).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (délégation pdr-0062) à l'étape « Définir » de 013. | Assistant (délégation du porteur) |
| 2026-10-31 | Précision D3 à l'implémentation de T21c (squelette retiré aussitôt, pas de fondu croisé ; règle de la surface déjà présente). | Assistant (délégation du porteur) |
| 2026-10-31 | Amendée par la revue du plan (verdict À AMENDER, P1 à P8) : D1 (676 px, rail de hauteur fixe, régie empilée, Q-85), D2 (extraits entiers), D3 (contrôleur par surface, `SceneMotionScope`), D4 (constantes, hash, `apps/genesis_widgetbook`). | Assistant (délégation du porteur) |
| 2026-10-31 | **Livrée** par 013 (`gate --full` vert, captures 1920×1080 relues). Précisions de réalisation, mêmes réserves (délégation pdr-0062, contestables) : D1 régie large de 520 px aux couleurs du thème de scène (« Remettre à vide » contouré comme l'indicateur d'acte, après la revue du code R2), panneau déplié de hauteur min(620, place) (le débordement de 39 px n'a pas été reproduit), intervalle libre `AgentsRail.delegationGap` de 48 px ; D2 mesures en 3×2 (2 critères + « + 1 autres critères », 1 extrait + « + 2 avis ») ; D3 durée de statut de décision de 400 ms passée par `SceneMotion`, translation de 8 px tokenisée et clippée ; D4 `SceneTokens` interne au paquet, hash sha256 portant aussi sur le générateur, `.gitattributes` en `eol=lf`, `sceneMaterialTheme()` partagé, viewports Widgetbook 640×318 et 952×318, pas de coupe C2. Q-83 tranchée ; Q-85 et Q-86 restent ouvertes (porteur). | Assistant (délégation du porteur) |

Pas d'archive brute.
