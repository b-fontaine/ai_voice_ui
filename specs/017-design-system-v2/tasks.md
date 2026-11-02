# 017 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Une seule pile (Flutter) : aucune tâche n'est parallélisable.

## Gherkin
- [ ] T01 Flutter — ajouter `product/functional/features/design-system-017.feature` (product-curate), puis automatiser U-01 à U-06 avec bdd_widget_test dans `apps/genesis_canvas/test/acceptance/acte_design_systeme_test.dart` · test d'abord : chaque scénario échoue pour la bonne raison (texte sous 24 px absent aujourd'hui sauf U-01 ; familles absentes pour U-02 ; ✓ et mouvement U-05 absents)

## TDD
- [ ] T10 Flutter — polices embarquées : fichiers variables Space Grotesk et JetBrains Mono dans `assets/fonts/`, licences, `pubspec.yaml`, `registerSceneFontLicenses`, `loadRealFonts` étendu ; spike de rendu des graisses · test d'abord : `scene_fonts_test` (familles dans le `FontManifest`, licences enregistrées) et un test de largeur de « 99,43 % » à `wght` 400 contre 700
- [ ] T11 Flutter — tokens DTCG : palette du design system, styles de texte (tailles de la table de `spec.md`), espacements, rayons, ombres, durées ; régénération par `tool/build_tokens.sh` ; `tokens_hash_test` et `tokens_parity_test` à jour · test d'abord : parité rouge (nouveaux tokens absents du thème)
- [ ] T12 Flutter — `SceneTheme` : rôles → design system, champs ajoutés, styles `data`/`verdict`/`transcript`/`button`, familles et chiffres tabulaires ; `sceneMaterialTheme` · test d'abord : `scene_theme_test` étendu (valeurs des rôles, tailles ≥ 24, contrastes AA après composition des `*-ghost`)
- [ ] T13 Flutter — `SceneMotion` : durées 480/160 ms, translation 10 px, `Cubic(.2,.8,.2,1)`, battement du statut Bloquant, cadre de génération du squelette · test d'abord : `scene_motion_test` (durées, plancher, division par la vitesse de rejeu, durée nulle sous `disableAnimations`)
- [ ] T14 Flutter — `ScenePanel` (dégradé, bordure, coins HUD, ombre, `RepaintBoundary`) et `SceneBackdrop` (grille de points) · test d'abord : `scene_panel_test` (décoration, coins, `RepaintBoundary` présent, taille inchangée de l'enfant)
- [ ] T15 Flutter — statuts : `DsStatusChip` et `SceneStatus` (fonds `*-ghost`, texte `go/warn/nogo`, ✓ séparé pour `ok`, hors `Semantics`) · test d'abord : `bricks_test` étendu (mot + couleur par statut, ✓ pour `ok`, `Semantics` inchangée)
- [ ] T16 Flutter — composants `KeyIndicator`, `ReleaseChecklist`, `ReviewSentiment` : styles du thème (`value`, `title`, `data`, `body`, `label`), couleurs, aucune couleur codée en dur · test d'abord : tests existants de chaque composant verts avec les polices réelles + assertion des styles
- [ ] T17 Flutter — `TrendChart` (séries U3, « 3.3 » pointillée, seuil `nogo` en tirets, axes `ink-faint`) et `CrashList`, `ActionBar` (U4) · test d'abord : `trend_chart_test` (couleur par plateforme, pointillés, seuil) ; interaction de la Barre d'actions inchangée
- [ ] T18 Flutter — `CanvasBoard` : chaque cellule habillée par `ScenePanel` sans changer un rectangle ; fond `SceneBackdrop` sous le canevas · test d'abord : `canvas_board_rebuild_test` et D-01…D-07 verts (rectangles identiques) + test du `RepaintBoundary`
- [ ] T19 Flutter — enveloppe de l'app : barre du haut, orbe (`plasma`, `glow-plasma` quand l'IA parle, aucune couleur codée en dur), rail, liaison de délégation, panneau du protocole, étagère, rejeu, régie, page · test d'abord : tests de widgets existants verts ; `no_hardcoded_color_test` (architecture) interdit `Color(0x` hors du paquet de design
- [ ] T20 Flutter — `genesis_widgetbook` : `scene_app_builder` avec les polices embarquées, stories de `ScenePanel` et des statuts · test d'abord : `testWidgetbook` (61 tests + nouveaux) et test d'ensemble
- [ ] T21 Flutter (optionnelle, coupe possible) — `gc-row` (cascade des lignes de checklist, 180 ms) et `gc-wipe` (tracé du graphique) · test d'abord : durée nulle sous `disableAnimations`, aucun rectangle ne bouge, pas de reconstruction des cellules voisines

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; vérification (capture `app-smoke` 1920×1080 des scénarios d'acte comparée aux `preview.html`) ; `progress.md`, `product/` (design-system.md, PDR de l'étape Définir passée en « livrée », Q-91), `knowledge/` si fait nouveau ; fusion et `publish.sh`
