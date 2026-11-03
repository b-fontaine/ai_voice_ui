# 018 — Barre de rejeu toujours atteignable

> **En bref.** Le speaker peut piloter le rejeu de l'acte 4 (Lecture, Recommencer, glissière, « Direct », cinq vitesses) que le panneau du protocole soit replié ou déplié, à 1920×1080. Aujourd'hui le panneau déplié recouvre 304 px des 480 px de la barre.

- **Jalon** : avant J7 (`product/roadmap/backlog.md` § 018).
- **Exigences visées** : FR-09 (rejeu), FR-05 (panneau du protocole), NFR-05 (lisibilité) ; EP-07, EP-05.
- **Décisions applicables** : [pdr-0085](../../product/decisions/pdr-0085-replay-bar-not-covered-by-protocol-panel.md) (décision du porteur, 2026-11-03), pdr-0062 (mise en page laissée à la boucle), pdr-0066 (rejeu), pdr-0084 (017, rectangles de 013 conservés), [Q-92](../../product/roadmap/open-questions.md) (a) ; architecture [p-ar-replay](../../product/architecture/replay.md), [p-ar-frontend-screen](../../product/architecture/frontend-screen.md).
- **Hors périmètre** : Q-92 (b) à (e) ; comportement du rejeu et du flux du protocole ; contenu, titre et nombre d'entrées du panneau ; budget vertical des autres zones (barre du haut 128, rail 96, canevas 676, rangée du bas 140) ; tout autre rectangle de 013 et de 017.

## Problème (constaté)
Rangée du bas : étagère | 16 | Rejeu 480 | 16 | emplacement du panneau replié 460. Le panneau est posé par-dessus en bas à droite (`Positioned(right: 0, bottom: 0)`) ; déplié (780×620) il couvre x 1116..1896, y 452..1072, donc la rangée du bas à droite : Recommencer, glissière, « Direct » et les vitesses sont inatteignables. R-01 ne passe que par 3,2 px de marge sur « Lecture ».

## Décision de mise en page (la boucle, pdr-0062 ; contestable)
Le panneau déplié **quitte la rangée du bas** : il s'ancre au-dessus (bord bas à `140 + 8` = 148 px du bas de la zone du canevas, juste au-dessus de la rangée du bas), sur la droite, et recouvre comme avant le canevas à droite sans le redimensionner. Sa hauteur (620) ne dépasse pas celle de la zone du canevas (676 px) : il ne touche ni le rail ni la barre du haut. Replié, rien ne change (460×140 à sa place). Le bouton « Replier » reste dans l'en-tête du panneau déplié. L'emplacement replié reste réservé (la rangée du bas ne bouge pas) ; il est vide tant que le panneau est déplié. Décision enregistrée : pdr-0086 (T02).

**Coordonnées à 1920×1080** (marges de 8) : barre du haut y 8..136 ; rail 144..240 ; canevas 248..924 ; panneau déplié 304..924 ; rangée du bas 932..1072. **Conséquence assumée** : le panneau recouvre en plus y 304..452 de la colonne de droite (en 2×2, 246 des 302 px de la cellule de droite du haut sont masqués au lieu de 98) ; option écartée : une hauteur de 472 px, qui ramènerait le panneau à 3 entrées (le nombre d'entrées est hors périmètre).

## Scénarios (Gherkin)
Nouveaux, hors des 9 de la fiche : `product/functional/features/replay-bar-018.feature` (ajouté à l'étape Gherkin, product-curate), automatisés dans `apps/genesis_canvas/test/acceptance/acte_barre_rejeu.feature`.
État testé : rejeu en pause à mi-parcours (`ReplayActive`), toutes les commandes construites et actives. Commandes : `replay-play`, `replay-restart`, `replay-slider`, `replay-direct`, `replay-speed-<id>` (cinq vitesses). Atteignable = **deux conditions** : `hitTestable()` trouve la commande **et** son rectangle ne recoupe pas celui du panneau (le centre seul ne suffit pas : la glissière ne positionne qu'au relâchement, ses deux extrémités doivent être atteignables).
- RB-01 — Panneau déplié : chaque commande de la barre de rejeu est atteignable, sans marge de contournement.
- RB-02 — Panneau replié : même propriété (garde-fou, vert avant 018).
- RB-03 — Panneau déplié : il ne recouvre aucun pixel de la rangée du bas (`panel.bottom <= bottom-row.top`) ni le rail ; ses entrées et le bouton « Replier » restent visibles dans la fenêtre ; le nombre d'entrées montrées reste celui mesuré avant correction ; les clics hors du panneau traversent (surface `kpi`, boutons de la barre du haut, `action-<id>` de gauche restent atteignables) ; le rejeu piloté (Lecture puis vitesse) passe par ces commandes.
- R-01 à R-09 (010) et D-01 à D-07 (013) : inchangés et verts. Le support d'acceptation de l'acte 4 devient strict (`press` vérifie `hitTestable()` avant de toucher) : R-01 est alors rouge avant correction.
- Le contournement de 017 (remplissage de 8 px de la barre, test `genesis_canvas_page_replay_reach_test`) est remplacé par RB-01 ; la géométrie de 8 px est conservée (les rectangles de 017 ne bougent pas).

## Critères d'acceptation
- [ ] RB-01 à RB-03 automatisés et verts ; RB-01 et RB-03 rouges avant la correction pour la bonne raison (commande recouverte)
- [ ] Tests unitaires du widget du panneau (position et hauteur dépliée)
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Capture `GENESIS_REPLAY_AT=0.5 GENESIS_PROTOCOL_EXPANDED=1 app-smoke.sh act1-replay` (1920×1080) : toute la barre visible, panneau déplié
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)

## Questions ouvertes
Aucune nouvelle. Q-92 reste ouverte pour (b) à (e). **À remonter au porteur, sans bloquer** (observation à mesurer, non corrigée, antérieure à 018) : dans le bandeau d'actions, le second bouton de la Barre d'actions tombe probablement sous le panneau déplié (x ≥ 1116, y 852..924) pendant l'acte 3.
