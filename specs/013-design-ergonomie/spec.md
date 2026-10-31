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
- A1 Canevas élastique : la zone du canevas prend toute la hauteur disponible (plus de hauteur fixe de 572 px), la bande vide disparaît ; le rail garde son cadre et son titre « AGENTS A2A » même sans agent (RG-01 : pas de nom codé en dur).
- A2 Cellules lisibles (Q-83, option 1) : titres, libellés de checklist et avis passent à la ligne au lieu d'être tronqués (sauf le libellé d'un crash, une ligne avec ellipse, pdr-0074 D10) ; critère : sur la capture 1920×1080 aucun libellé de checklist ni d'avis n'est tronqué.
- A3 Titre de courbe jamais tronqué : la légende passe sous le titre quand la place manque.
- A4 Étagère : noms de composants entiers (deux colonnes ou retour à la ligne), jamais d'ellipse.
- A5 Régie : « Acte n/3 · … » et « Remettre à vide » alignés en un seul groupe de boutons homogènes, cibles ≥ 48 px, contraste mesuré ; panneau du protocole déplié sans débordement (la hauteur dépliée tient dans la zone).
- A6 Mise en page inspirée de la maquette (pdr-0017) : repères de zone (« CANEVAS · release-3-4 », « AGENTS A2A », « CATALOGUE · n / 6 utilisés »), sans rien emprunter de technique à la maquette.

**Lot B — apparition animée** (FR-04, NFR-04)
- B1 Squelette → composants → données en trois temps visibles : fondu et glissement courts (durées et courbes M3, `ds-motion`), un seul `AnimationController` par surface, `RepaintBoundary`.
- B2 `MediaQuery.disableAnimations` respecté ; le rejeu (0,25× à 2×) anime aussi, sans retarder le gate A2UI.
- B3 Mesure NFR-04 : budget de frames pendant l'apparition (test de budget sur horloge simulée + profil `--profile` en répétition, J7).

**Lot C — design system et Widgetbook** (adr-0004 à adr-0008)
- C1 Tokens DTCG dans Git (primitives, sémantiques, composants) pour le thème de scène, générés en Dart par Style Dictionary épinglé (format custom → `ThemeExtension`), code généré committé ; `SceneTheme` garde son API publique (RG-09) mais se nourrit des tokens ; un test de parité Dart (tokens ↔ valeurs) tient lieu de contrôle en porte, sans Node.
- C2 Catalogue Widgetbook 4.0.0-beta.14 épinglé (spike `spikes/widgetbook4`) : une story par composant du catalogue genesis (6) et par brique (3), états squelette, données et neutre ; build web statique, sans Widgetbook Cloud (adr-0006).
- C3 Contrôles d'accessibilité en test : contraste WCAG AA des paires du thème, texte ≥ 24 px des composants, cibles ≥ 48 px des boutons.

## Hors périmètre
- Tout ce qui change le contrat A2UI, le catalogue (6 composants), les agents ou le backend : aucune modification Go.
- Nouvelle mise en scène des actes, nouveau composant, nouveau mode d'interaction (porteur).
- Projecteur réel et fond de salle (géré par le porteur) ; mesure DevTools `--profile` sur la machine de démo (J7).
- Widgetbook Cloud (écarté, adr-0006) ; export vers Claude Design (adr-0007, hors démo).
- S-02 (« les surfaces existantes restent à leur place ») : la grille 2×2 puis 3×2 et le bandeau de la Barre d'actions de 72 px sont conservés.

## Scénarios d'acceptation (à automatiser)
Nouveaux (ajoutés à `product/functional/features/` à la clôture, pdr-0062 pour l'écart) :
- **D-01** (Flutter, 1920×1080) acte 1 en direct et en rejeu : le canevas occupe la hauteur laissée par la barre du haut, le rail et la rangée du bas ; aucun espace vide plus haut que l'intervalle de grille entre la barre du haut et la première surface.
- **D-02** (Flutter) la capture de la cinquième surface (CrashList) montre la checklist et les avis sans libellé tronqué (texte rendu complet, plusieurs lignes) ; texte ≥ 24 px.
- **D-03** (Flutter) titre de courbe entier et légende sous le titre quand la cellule fait ≈ 620 px de large.
- **D-04** (Flutter) étagère : six noms entiers, 6/6 sans ellipse.
- **D-05** (Flutter) régie : indicateur d'acte et remise à vide au même groupe, chaque cible ≥ 48 px ; panneau déplié contenu dans l'écran.
- **D-06** (Flutter) apparition en trois temps : à t=0 le squelette, après la durée du fondu les composants, puis les données ; avec `disableAnimations` le résultat est immédiat ; en rejeu à 2× la durée est proportionnelle.
- **D-07** (Flutter) les surfaces existantes ne bougent pas quand une surface arrive (S-02) malgré la nouvelle mise en page.

## Critères d'acceptation
- [ ] Scénarios D-01 à D-07 automatisés et verts
- [ ] Tests unitaires des unités nouvelles ; test de parité tokens ↔ `SceneTheme`
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] Captures 1920×1080 (`app-smoke`, `act1-replay`, `crashlist-replay`) relues : pas de bande vide, aucun libellé tronqué hors liste de crashs, texte ≥ 24 px
- [ ] Catalogue Widgetbook : build web réussi et `testWidgetbook` vert (ou coupe C déclarée)

## Questions ouvertes
Q-83 (cellules lisibles) : traitée ici par l'option 1, à clore à la clôture. Aucune question bloquante.
