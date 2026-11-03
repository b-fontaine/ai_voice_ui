# 018 — Barre de rejeu toujours atteignable

> **En bref.** Le speaker peut piloter le rejeu de l'acte 4 (Lecture, Recommencer, glissière, « Direct », cinq vitesses) que le panneau du protocole soit replié ou déplié, à 1920×1080. Aujourd'hui le panneau déplié recouvre 304 px des 480 px de la barre.

- **Jalon** : avant J7 (`product/roadmap/backlog.md` § 018).
- **Exigences visées** : FR-09 (rejeu), FR-05 (panneau du protocole), NFR-05 (lisibilité) ; EP-07, EP-05.
- **Décisions applicables** : [pdr-0085](../../product/decisions/pdr-0085-replay-bar-not-covered-by-protocol-panel.md) (décision du porteur, 2026-11-03), pdr-0062 (mise en page laissée à la boucle), pdr-0066 (rejeu), pdr-0084 (017, rectangles de 013 conservés), [Q-92](../../product/roadmap/open-questions.md) (a) ; architecture [p-ar-replay](../../product/architecture/replay.md), [p-ar-frontend-screen](../../product/architecture/frontend-screen.md).
- **Hors périmètre** : Q-92 (b) à (e) ; comportement du rejeu et du flux du protocole ; contenu, titre et nombre d'entrées du panneau ; budget vertical des autres zones (barre du haut 128, rail 96, canevas 676, rangée du bas 140) ; tout autre rectangle de 013 et de 017.

## Problème (constaté)
Rangée du bas : étagère | 16 | Rejeu 480 | 16 | emplacement du panneau replié 460. Le panneau est posé par-dessus en bas à droite (`Positioned(right: 0, bottom: 0)`) ; déplié (780×620) il couvre x 1116..1896, y 452..1072, donc la rangée du bas à droite : Recommencer, glissière, « Direct » et les vitesses sont inatteignables. R-01 ne passe que par 3,2 px de marge sur « Lecture ».

## Décision de mise en page (la boucle, pdr-0062 ; contestable)
Le panneau déplié **quitte la rangée du bas** : il s'ancre au-dessus (bord bas à `140 + 8` px du bas de la zone utile, c'est-à-dire juste au-dessus de la rangée du bas, écart de la page), sur la droite, et recouvre comme avant le canevas à droite sans le redimensionner. Sa hauteur ne dépasse pas celle du canevas (676 px). Replié, rien ne change (460×140 à sa place). Le bouton « Replier » reste dans l'en-tête du panneau déplié. L'emplacement replié reste réservé (la rangée du bas ne bouge pas) ; il est vide tant que le panneau est déplié.

## Scénarios (Gherkin)
Nouveaux, hors des 9 de la fiche : `product/functional/features/replay-bar-018.feature` (ajouté à l'étape Gherkin, product-curate), automatisés dans `apps/genesis_canvas/test/acceptance/acte_barre_rejeu.feature`.
- RB-01 — Panneau déplié : chaque commande de la barre de rejeu est atteignable (le point central de chaque commande est touché par elle-même, sans marge de contournement).
- RB-02 — Panneau replié : même propriété (garde-fou, vert avant 018).
- RB-03 — Panneau déplié : il ne recouvre aucun pixel de la rangée du bas, ses entrées et le bouton « Replier » restent visibles dans la fenêtre, et le rejeu piloté (Lecture puis vitesse) passe par ces mêmes commandes.
- R-01 à R-09 (010) et D-01 à D-07 (013) : inchangés et verts ; le contournement de 3,2 px de R-01 n'est plus nécessaire.

## Critères d'acceptation
- [ ] RB-01 à RB-03 automatisés et verts ; RB-01 et RB-03 rouges avant la correction pour la bonne raison (commande recouverte)
- [ ] Tests unitaires du widget du panneau (position et hauteur dépliée)
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Capture `app-smoke.sh` 1920×1080, panneau déplié en rejeu : toute la barre visible
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)

## Questions ouvertes
Aucune nouvelle. Q-92 reste ouverte pour (b) à (e).
