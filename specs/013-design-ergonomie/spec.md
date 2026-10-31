# 013 — Design et ergonomie

**Backlog** : EP-04 (canevas, animations), EP-01 (socle visuel, design system). **Jalon** : avant J7 (ordre du porteur : 011 → 012 → 013 → J7).
**Décisions** : [pdr-0072](../../product/decisions/pdr-0072-design-ergonomics-013.md) (fonctionnalité dédiée), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md) (détails tranchés par la boucle), [pdr-0062](../../product/decisions/pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md) (fiche d'abord, détails d'interface), [pdr-0017](../../product/decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md) (maquette = illustration), [pdr-0007](../../product/decisions/pdr-0007-closed-catalog-stage-theme.md) (thème de scène), adr-0004 à adr-0008 (design system, tokens, Widgetbook).
**Sources** : [diagnostic de l'essai au micro](../../product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md), captures 1920×1080 de 012 (`act1-replay`, `crashlist-replay`), Q-83.

## Objectif
Rendre l'écran lisible depuis le fond de la salle (NFR-05) et fluide à l'apparition des surfaces (FR-04, NFR-04), corriger les défauts visuels connus, puis ancrer le thème de scène dans un design system à tokens avec un catalogue Widgetbook (adr-0004 à adr-0008). La fiche fait foi ; la maquette n'inspire que la mise en page (pdr-0017).

## Constats (captures 1920×1080 de 012, 2026-10-31)
1. Une **bande vide d'environ 220 px** sépare la barre du haut du canevas (le rail est vide hors session ou en rejeu, et le canevas a une hauteur fixe de 572 px) ; en bas, 220 px d'étagère et de rejeu pour peu de contenu.
2. **Libellés tronqués** malgré NFR-05 : « Checklist… », « Sessions sans cra… », « Avis négatifs (glo… », « ReleaseCheck… », « ReviewSenti… » (étagère), avis tronqués en fin de ligne (Q-83).
3. **Régie** : le bouton « Remettre à vide » est une pastille claire démesurée, « Acte 1/3 · Créer » flotte au-dessus ; cibles à 44 px (pdr-0066 « hors périmètre »).
4. **Panneau du protocole** déplié : déborde de 39 px (pdr-0066).
5. **Titre de courbe** tronqué quand la légende prend la place du titre (constat du porteur, pdr-0072).
6. Apparition des surfaces : aucune animation (FR-04 « trois temps » : squelette, composants, données, sans transition).
7. Les couleurs et tailles du thème de scène vivent dans une classe écrite à la main (`SceneTheme`, 326 lignes) sans source de tokens ni catalogue visuel.

## Périmètre
Trois lots, dans cet ordre ; un lot se livre entier avant le suivant (coupe possible après B, pdr-0072 « Réexaminer si »).

**Lot A — corrections visuelles et lisibilité** (obligatoire)
- A1 Bande vide : le rail devient une rangée horizontale de 96 px (au lieu de 200 px), le canevas garde `Expanded` et passe à 676 px ; le rail garde son titre « AGENTS A2A » et une hauteur fixe même sans agent (RG-29 : pas de nom codé en dur ; la tâche de chaque agent reste affichée, FR-03).
- A2 Cellules lisibles (Q-83, option 1) : titres et libellés de checklist passent à la ligne ; les avis n'affichent que des extraits entiers qui tiennent, puis « + N avis » (sauf le libellé d'un crash, une ligne avec ellipse, pdr-0074 D10) ; critère : sur la capture 1920×1080 aucun libellé de checklist ni d'avis n'est tronqué.
- A3 Titre de courbe jamais tronqué : la légende passe sous le titre quand la place manque.
- A4 Étagère : deux rangées de trois puces, noms entiers sans ellipse, état porté par une icône et `Semantics`.
- A5 Régie : « Acte n/3 · … » et « Remettre à vide » alignés en un seul groupe de boutons homogènes, cibles ≥ 48 px, contraste mesuré ; panneau du protocole déplié sans débordement (la hauteur dépliée tient dans la zone).
- A6 Mise en page inspirée de la maquette (pdr-0017) : repères « AGENTS A2A » et « CATALOGUE · n / 6 utilisés » ; pas de libellé « CANEVAS » (aucun budget de hauteur ni donnée de release), rien d'emprunté de technique à la maquette. La liaison animée de délégation de la fiche n'a jamais été livrée : elle attend la décision du porteur ([Q-85](../../product/roadmap/open-questions.md)), le rail laisse la place d'un connecteur.

**Lot B — apparition animée** (FR-04, NFR-04)
- B1 Squelette → composants → données en trois temps visibles : fondu et glissement courts (durées et courbes M3, `ds-motion`), un seul `AnimationController` par surface, `RepaintBoundary` ; l'arrivée d'une surface ne reconstruit ni ne repeint les cellules voisines (périmètre de reconstruction, NFR-04).
- B2 `MediaQuery.disableAnimations` et le réglage `_animationsOff` de la page respectés (durée nulle, jamais de `TickerMode`) ; le rejeu (0,25× à 2×) anime aussi, sans retarder le gate A2UI.
- B3 Mesure NFR-04 : test du périmètre de reconstruction et de peinture ; les 60 i/s eux-mêmes se mesurent au profil `--profile` en répétition (J7).

**Lot C — design system et Widgetbook** (adr-0004 à adr-0008)
- C1 Tokens DTCG dans Git (primitives, sémantiques, composants) pour le thème de scène, générés en Dart par Style Dictionary épinglé (format custom → constantes `SceneTokens`), code généré committé ; `SceneTheme` reste l'unique `ThemeExtension` (RG-09) et se nourrit des constantes ; un test de hash (sha256 en en-tête du fichier généré) et de parité tient lieu de contrôle en porte, sans Node.
- C2 Catalogue Widgetbook 4.0.0-beta.14 épinglé (spike `spikes/widgetbook4`), application `apps/genesis_widgetbook/` (couche app) membre du workspace : une story par composant du catalogue genesis (6, états données, sans données, neutre, alimentés par les exemples du contrat) et par brique (3, dont le squelette) ; build web statique, sans Widgetbook Cloud (adr-0006) ; première tâche : prouver que la résolution pub et la porte restent vertes, sinon coupe C2.
- C3 Contrôles d'accessibilité en test pour ce que 013 ajoute (paires de la régie, repères, icônes d'étagère ; cibles ≥ 48 px sous Linux) ; le contraste du thème et le texte ≥ 24 px existent déjà (`scene_theme_test.dart`).

## Hors périmètre
- La liaison animée de délégation du rail (fiche, jamais livrée) : Q-85, porteur.
- Le 1366×768 (limite assumée de `screen.md`).
- Tout ce qui change le contrat A2UI, le catalogue (6 composants), les agents ou le backend : aucune modification Go.
- Nouvelle mise en scène des actes, nouveau composant, nouveau mode d'interaction (porteur).
- Projecteur réel et fond de salle (géré par le porteur) ; mesure DevTools `--profile` sur la machine de démo (J7).
- Widgetbook Cloud (écarté, adr-0006) ; export vers Claude Design (adr-0007, hors démo).
- S-02 (« les surfaces existantes restent à leur place ») : la grille 2×2 puis 3×2 et le bandeau de la Barre d'actions de 72 px sont conservés.

## Scénarios d'acceptation (à automatiser)
Nouveaux (ajoutés à `product/functional/features/` à la clôture, pdr-0062 pour l'écart) :
- **D-01** (Flutter, 1920×1080) acte 1 en direct et en rejeu : `canvas-board.top == agents-rail.bottom + 8`, hauteur du canevas 676 px, première surface au ras du haut du canevas (aucune bande vide).
- **D-02** (Flutter, polices réelles) en 3×2 avec les données de l'acte 2, la checklist et les avis n'ont aucun libellé tronqué ; les avis affichent des extraits entiers puis « + N avis » (nombre fixé par le test) ; texte ≥ 24 px.
- **D-03** (Flutter) titre de courbe entier et légende sous le titre quand la cellule fait ≈ 620 px de large.
- **D-04** (Flutter, polices réelles) étagère : six noms entiers sans ellipse, état par icône et `Semantics`.
- **D-05** (Flutter, sous Linux) régie : indicateur d'acte et remise à vide empilés, chaque cible ≥ 48 px ; panneau déplié contenu dans la zone du canevas avec 4 entrées dont une refusée et `actions`.
- **D-06** (Flutter) apparition en trois temps : à t=0 le squelette, après la durée du fondu les composants, puis les données ; avec `disableAnimations` le résultat est immédiat ; en rejeu à 2× la durée est proportionnelle.
- **D-07** (Flutter) aucun rectangle ne bouge à l'arrivée du premier `plan`, pendant une mutation de l'acte 2 ni à l'arrivée du bandeau `actions` ; à l'arrivée d'une surface de la grille aucun `State` existant n'est recréé ; pendant une transition le rectangle de `surface-<id>` reste constant (S-02 ; les changements de colonnes 1 → 2 et 2×2 → 3×2 sont acceptés, pdr-0074).

## Critères d'acceptation
- [ ] Scénarios D-01 à D-07 automatisés et verts
- [ ] Tests unitaires des unités nouvelles ; test de parité tokens ↔ `SceneTheme`
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Captures 1920×1080 (`app-smoke`, `act1-replay`, `crashlist-replay`) relues : pas de bande vide, aucun libellé de checklist ni d'avis tronqué, texte ≥ 24 px
- [ ] Catalogue Widgetbook : build web réussi et `testWidgetbook` vert, porte verte avec le membre du workspace (ou coupe C2 déclarée)

## Questions ouvertes
Q-83 (cellules lisibles) : traitée ici par l'option 1, à clore à la clôture. [Q-85](../../product/roadmap/open-questions.md) (liaison animée de délégation, au porteur) : non bloquante, hors périmètre tant que non tranchée.
