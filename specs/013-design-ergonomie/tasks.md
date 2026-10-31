# 013 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante des autres tâches ouvertes. Tout est Flutter : les tâches sont **séquentielles** sauf mention `[P]` (une seule pile : pas de parallélisme entre sous-agents sur les mêmes fichiers). `product/`, `specs/`, `pubspec.yaml` racine : session principale seule.

## Gherkin
- [ ] T01 Flutter — `acte_design_ergonomie.feature` : D-01 (hauteur du canevas, pas de bande vide, direct et rejeu), D-02 (checklist et avis sans libellé tronqué, ≥ 24 px), D-03 (titre de courbe et légende), D-04 (étagère noms entiers), D-05 (régie ≥ 48 px, panneau contenu) · rouges : canevas à 572 px et bande de 200 px ; ellipse sur « Checklist… » ; titre et légende sur la même ligne ; « ReleaseCheck… » ; cible de 44 px
- [ ] T02 Flutter — même fichier : D-06 (apparition en trois temps, `disableAnimations`, rejeu à 2×) et D-07 (les surfaces existantes ne bougent pas) · rouges : changement de phase immédiat, sans transition ; `SceneMotion` absent

## Lot A — corrections visuelles et lisibilité
- [ ] T10 Flutter — rail horizontal de 96 px (`AgentsRail`) : orchestrateur puis agents, nom sur une ligne, état en toutes lettres, « AGENTS A2A », « aucun agent retenu », vide avant le premier `plan` ; test avec cinq agents · test d'abord : `agents_rail_test.dart` (hauteur ≤ 96, texte ≥ 24 px, cinq agents sans débordement)
- [ ] T11 Flutter — budget des zones élastique (`genesis_canvas_page.dart`) : barre 128, rail 96, rangée du bas 140, le canevas prend le reste à partir de la hauteur disponible ; `canvas_board.dart` dimensionne la grille et le bandeau de 72 px sur cette hauteur · test d'abord : `genesis_canvas_page_layout_test.dart` (1920×1080 : canevas ≥ 670 px, cellules ≥ 290 px de haut ; 1366×768 : aucun `RenderFlex` en débordement)
- [ ] T12 Flutter — `ReleaseChecklist` et `ReviewSentiment` : retour à la ligne (`maxLines` 2) et mesure par `text_metrics.dart`, jamais d'ellipse sur un libellé de checklist ni d'avis · test d'abord : `release_checklist_test.dart`, `review_sentiment_test.dart` (cellule 620×298 : texte complet rendu, aucune ellipse, ≥ 24 px)
- [ ] T13 Flutter — `TrendChart` : titre sur sa ligne, légende en `Wrap` dessous, tracé sur le reste ; `KeyIndicator` et `CrashList` : titres entiers · test d'abord : `trend_chart_test.dart` (cellule de 620 px : titre non tronqué, légende sous le titre)
- [ ] T14 Flutter — `CatalogShelf` : six puces à noms entiers (deux colonnes de trois), « utilisé » / « inutilisé » lisibles · test d'abord : `catalog_shelf_test.dart` (aucune ellipse, 6/6)
- [ ] T15 Flutter — régie : `StageBar` en un groupe de deux contrôles à 48 px, `Semantics`, contraste du thème ; panneau du protocole déplié dans la zone (plus de débordement) · test d'abord : `stage_bar_test.dart` (`androidTapTargetGuideline`, ordre), `protocol_panel_test.dart` (déplié : hauteur ≤ zone)
- [ ] T16 Flutter — repères de zone (« AGENTS A2A », « CANEVAS ») · test d'abord : `genesis_canvas_page_test.dart` (libellés présents, aucun nom de release codé en dur)
- [ ] T17 Flutter — captures : `app-smoke` sur `act1-replay` et `crashlist-replay`, lecture des PNG, ajustements de marges (aucun nouveau test, preuve = capture)

## Lot B — apparition animée
- [ ] T20 Flutter — `SceneMotion` (durées 200 et 150 ms, courbe `easeOutCubic`, facteur de vitesse, plancher 60 ms) dans `shared_design_system`, exporté par le barrel · test d'abord : `scene_motion_test.dart`
- [ ] T21 Flutter — transitions de phase dans `canvas_board.dart` : `AnimatedSwitcher` squelette → composants, fondu des valeurs, `RepaintBoundary` par cellule, translation de 8 px, `disableAnimations` → durée zéro, durées divisées par la vitesse en rejeu · test d'abord : `canvas_board_appearance_test.dart` (t=0 squelette ; après 200 ms composants ; `disableAnimations` immédiat ; 2× : ≤ 100 ms)
- [ ] T22 Flutter — NFR-04 : test de budget (5 surfaces, pas de 16 ms, zéro reconstruction des cellules voisines) et note de mesure `--profile` à J7 · test d'abord : `appearance_budget_test.dart`

## Lot C — design system et Widgetbook
- [ ] T30 Flutter — tokens DTCG (`tokens/*.tokens.json`) repris de `SceneTheme` + `tool/build_tokens.mjs` (Style Dictionary épinglé, format custom) + `scene_tokens.g.dart` committé ; `SceneTheme` lit l'extension générée · test d'abord : `tokens_parity_test.dart` (chaque token résolu égal à la valeur de `SceneTheme`)
- [ ] T31 Flutter — contrôles d'accessibilité : contraste WCAG des paires du thème, texte ≥ 24 px des composants, cibles ≥ 48 px · test d'abord : `scene_contrast_test.dart`
- [ ] T32 Flutter — paquet `widgetbook/` (workspace pub, `widgetbook 4.0.0-beta.14` exact, `build.yaml` télémétrie coupée), story par brique (3) · test d'abord : `testWidgetbook` (aucune story, échec)
- [ ] T33 Flutter — stories des 6 composants genesis (états squelette, données, neutre ; viewports 620×298 et 940×298) · test d'abord : `testWidgetbook` couvre 6 × 3 scénarios
- [ ] T34 Flutter — scripts manuels `tool/build_tokens.sh` et `tool/build_widgetbook.sh`, README du paquet · test d'abord : aucun (documentation) ; vérifiés une fois à la main, sortie dans `status.md`

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; captures relues ; `progress.md` ; documents `product/` (écran, NFR, quality, open-questions Q-83) ; fusion et `publish.sh`
