# 019 — Plan technique

## Où
Tout est Flutter ; aucune tâche Go. Les tâches sont donc **séquentielles** (une seule pile : pas de TDD en parallèle).

| Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|
| `packages/shared/design_system` | shared | `tokens/` (source DTCG) et `scene_tokens.g.dart` régénéré ; `scene_theme.dart` (échelle de texte et micro-styles) ; `scene_panel.dart` (remplissage, en-tête, coins HUD) ; `scene_motion.dart` (durées et courbes de `gc-row`, `gc-wipe`, `gc-spin`, `gc-scan`, `gc-ring`, `gc-indet`, `gc-flash`, `gc-blink`) ; `ds_status_chip.dart` (pilule 26 px, grande puce, capitales) ; nouveaux `ds_rise.dart` (apparition avec flou), `ds_gen_frame.dart` (cadre de génération), `ds_caps.dart` (capitales à l'affichage) ; `scene_material_theme.dart` si le thème Material suit l'échelle |
| `packages/features/canvas` | feature (catalogue) | `key_indicator.dart` (jauge, compteur), `trend_chart.dart` et `trend_chart_painter.dart` (grille, axe, zones, annotation, tracé), `release_checklist.dart` (tableau, cascade), `review_sentiment.dart` (barre, cartes), `action_bar.dart` (boutons), `text_metrics.dart` (mesures à l'échelle du design system) |
| `apps/genesis_canvas` | app / pages / widgets | `widgets/agents_rail/agents_rail.dart` (tuiles), `widgets/top_bar/` et `widgets/stage_bar/` (barre vocale, segments d'actes, boutons), `widgets/top_bar/voice_orb.dart` (anneaux, onde), `widgets/catalog_shelf/` (puces), `widgets/replay_bar/` (piste, vitesses), `widgets/protocol_panel/` (flux en liste mono), `pages/genesis_canvas/genesis_canvas_page.dart` (cadre de génération par surface) |
| `packages/features/stage_controls`, `replay` | model | **aucun changement de logique** (T40 seulement ajoute un test) |
| `apps/genesis_widgetbook` | histoires | une histoire par composant changé (nouvelle structure) |
| `test/` | acceptation + unité | `apps/genesis_canvas/test/acceptance/` (F-01…F-10, A-01…A-07, I-01), tests unitaires par composant, `test/architecture/no_hardcoded_style_test.dart` recalé |

## Contrats
- **Aucun contrat nouveau** : A2UI v0.9, canal app ↔ backend, événements Bloc, données : inchangés (pdr-0087 D4). Le catalogue `genesis` fermé et sa validation ne bougent pas.
- **Thème** : `SceneTheme` reste l'unique `ThemeExtension` (RG-09) ; ses rôles étaient figés par 017 : les **styles de texte** changent de taille, de nouveaux micro-styles s'ajoutent (pdr-0088 F1). Toute nouvelle couleur est déjà dans la palette (aucun rôle ajouté, sinon régénération et T10 la porte).
- **Mouvement** : une seule source, `SceneMotionScope` (vitesse de rejeu, `disableAnimations`). Chaque animation a une durée et une courbe dans `SceneMotion`, **divisée par la vitesse de rejeu** et plafonnée par le plancher de 60 ms (comportement de 013/017). Toute boucle passe par `SceneMotionScope.loop`.
- **Apparition avec flou** (`DsRise`) : un `AnimatedBuilder` sur un `AnimationController` à vie courte, `ImageFiltered` seulement tant que `value < 1`, `Opacity`/`Transform` sinon ; dans le `RepaintBoundary` de la cellule (périmètre de reconstruction de 013).
- **Cadre de génération** (`DsGenFrame`) : `CustomPainter` (arc `SweepGradient` tournant en bordure de 2 px + balayage `LinearGradient`), une boucle, un `RepaintBoundary`, état `done` qui finit le tour puis fond (pas de boucle infinie après).
- **Compteur** (`data-count`) : `TweenAnimationBuilder` du texte formaté (virgule décimale, 2 décimales) de 100 vers la valeur en 1,4 s ; texte final = valeur exacte (les tests existants qui cherchent « 99,43 % » restent verts, l'animation étant coupée par `disableAnimations`, et le texte étant celui de la fin hors animation).
- **Cascade** : chaque ligne de checklist prend un décalage de `180 ms × index` (plafonné) ; l'ordre est celui des critères.
- **Géométrie** : `lineHeightOf` et `TextMetrics` (013) suivent la nouvelle échelle ; le nombre de lignes visibles des avis (D-02 : « 1 à 2 extraits ») est **recalculé** pour des cartes de verbatims, mais le nombre d'extraits affichés (donnée) ne change pas.

## Références
- `product/architecture/design-system.md` § tokens, § apparition ; `product/architecture/design-system-look.md` § typographie, panneaux, statuts ; `product/architecture/frontend-screen.md`.
- Source : `product/sources/design-system-2026-11-02/components/<Nom>/{README.md,preview.html}`, `bundle.css`.
- Notes `knowledge/` : [ds-motion], [ds-a11y-wcag-contrast], [ds-tokens-style-dictionary], [ds-tokens-theme-extension], [perf-repaint-boundary], [ds-widgetbook-4-stories], [ds-widgetbook-4-testing], [test-golden-alchemist] ; décisions : [pdr-0087], [pdr-0088], [pdr-0084] (reste en vigueur).

## Risques
- **60 i/s (NFR-04)** : flou de `gc-rise`, cadre de génération, onde, anneaux, boucles de niveau B → un `RepaintBoundary` local par boucle, flou limité à la transition, repli décrit dans pdr-0088 F5 ; mesure réelle en J7 (hors porte), un test de **nombre de boucles actives** (bornées) et d'arrêt sous `disableAnimations` les couvre côté code.
- **Régression des 24 px sur la géométrie** : les rectangles (S-02, D-01…D-07, R-01, RB-01…RB-03) restent ceux de 013/018 ; les textes plus petits libèrent de la place, mais le tableau de la checklist, les cartes d'avis et la jauge ajoutent de la structure → test de **non-débordement** par composant dans sa cellule (F-xx) et captures 1920×1080 aux actes 1 à 3.
- **Tests qui cherchent la casse d'origine** (capitales, pdr-0088 F6) → un utilitaire `DsCaps`/helper de test commun, recalage groupé en T11 ; ne pas toucher aux chaînes de données ni à `Semantics`.
- **Captures sans animation** : `_animationsOff` en scénario et en capture → animations prouvées par tests à horloge simulée (A-01 à A-07), pas par capture ; l'état final est comparé aux `preview.html`.
- **Source écrite pour 1440 px** : textes plus petits que le canevas de 1920 : consigné pour la répétition (lisibilité au fond de la salle, pdr-0087 D1) ; aucune mise à l'échelle ajoutée (pdr-0087 D1).
- **Polices** : Space Grotesk et JetBrains Mono embarquées (017) couvrent les graisses utilisées (400 à 700 ; 800 non utilisé) ; ✓ ▲ ▶ ↺ ◆ ★ par le repli DejaVu (017).
- **`line-strong` à 2,30:1** (017) : réservée aux séparateurs et coins HUD ; la source affirme 3:1 : non repris (pdr-0084 U4 reste en vigueur).
