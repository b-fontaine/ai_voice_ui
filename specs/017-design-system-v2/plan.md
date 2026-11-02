# 017 — Plan technique

Flutter seulement : aucune modification Go, aucun changement du contrat A2UI. Les décisions U1 à U11 sont dans `spec.md`.

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `packages/shared/design_system` | shared | `tokens/{primitives,semantic,scene}.tokens.json` (palette, texte, espacements, rayons, ombres, durées), `lib/src/generated/scene_tokens.g.dart` (régénéré par `tool/build_tokens.sh`), `lib/src/scene_theme.dart` (rôles → design system, styles `data`, `verdict`, `transcript`, `button`), `scene_material_theme.dart` (familles, plancher 24 px conservé), `scene_motion.dart` (durées, courbe, translation), `scene_status.dart` et `ds_status_chip.dart` (fonds `*-ghost`, glyphe ✓), `ds_skeleton.dart` (cadre de génération), **nouveaux** `scene_panel.dart` (panneau : dégradé, bordure, coins HUD, ombre), `scene_backdrop.dart` (grille de points), `scene_fonts.dart` (enregistrement des licences), `assets/fonts/*.ttf` + `assets/licenses/*.txt`, `pubspec.yaml` (déclaration des polices), barrel `shared_design_system.dart` |
| Flutter | `packages/features/canvas` | feature | `catalog/{key_indicator,trend_chart,release_checklist,review_sentiment,crash_list,action_bar}.dart` (styles et couleurs du thème, séries U3), `ui/canvas_board.dart` (cellule habillée par `ScenePanel`, sans toucher aux rectangles) ; tests sous `test/` |
| Flutter | `apps/genesis_canvas` | app | `widgets/{top_bar,voice_orb,agents_rail,delegation_links,protocol_panel,catalog_shelf,replay_bar,stage_bar}`, `pages/genesis_canvas/genesis_canvas_page.dart` (fond `ScenePanel`/`SceneBackdrop`, `main` : licences) ; `test/acceptance/acte_design_systeme.feature` + `_test.dart` |
| Flutter | `testing/real_fonts` | testing | `loadRealFonts` charge aussi Space Grotesk et JetBrains Mono (mêmes assets que l'app) ; `paragraphsTruncated` inchangé |
| Flutter | `apps/genesis_widgetbook` | app | `scene_app_builder.dart`, stories des briques nouvelles (`ScenePanel`, statuts) ; 61 tests existants à garder verts |
| Docs | `product/` | — | `functional/features/design-system-017.feature` (U-01…U-06), `architecture/design-system.md`, `roadmap/*`, PDR d'assistant de l'étape Définir ; `knowledge/` : note sur les polices variables sous Flutter Linux si le rendu est vérifié |

## Contrats
- **`SceneTheme`** reste l'unique `ThemeExtension` (RG-09). Les rôles actuels gardent leur nom ; correspondance : `background` = `void`, `surface` = `surface-100`, `textPrimary` = `ink`, `textSecondary` = `ink-muted`, `accent` = `signal`, `ok/risk/blocking Background` = `go/warn/nogo-ghost`, `ok/risk/blocking Foreground` = `go/warn/nogo`, `neutralBackground` = `surface-300`, `neutralForeground` = `ink-muted`, `highlightOutline` = `signal`, `actionNeutralBorder` = `line-strong`, `actionDangerBorder` = `nogo`, `agentWorking` = `signal`, `agentIdle` = `ink-faint`, `agentRejected` = `warn`, `agentInterrupted` = `baseline`, séries U3. Champs ajoutés : `panelTop` (`surface-200`), `panelBottom`, `line`, `lineStrong`, `inkFaint`, `plasma`, `plasmaGhost`, `signalGhost`, `onNogo`, `data`, `verdict`, `transcript`, `button` (`TextStyle`). Les jetons d'espacement, de rayon, d'ombre et de durée sont des constantes de `SceneTokens`, sans nouveau `ThemeExtension`.
- **Polices** : familles `Space Grotesk` et `JetBrains Mono` déclarées dans le `pubspec.yaml` du paquet `shared_design_system` (famille résolue par `package: 'shared_design_system'`), fichiers variables, `FontVariation('wght', n)` dans chaque style ; `FontFeature.tabularFigures()` sur les données. Repli : `Noto Sans`, `DejaVu Sans`. Aucune dépendance `google_fonts`. Licences OFL enregistrées par `registerSceneFontLicenses()` appelé dans `main()` de l'app.
- **Tokens** : `tool/build_tokens.sh` (Style Dictionary 5.7.1 exact, déjà utilisé par 013) régénère `scene_tokens.g.dart` ; l'en-tête `tokens-sha256` est recalculé ; la porte ne lance jamais Node (`tokens_hash_test`, `tokens_parity_test`). Le script manuel est lancé par la tâche, puis le fichier généré est committé.
- **Mouvement** : `SceneMotion` garde son interface (`appear`, `value`, `status`, `floor`, `translation`, `link`, `curve`, `scaled`) ; seules les valeurs changent (U2) ; `curve` devient `Cubic(.2, .8, .2, 1)`. Aucun nouveau `Ticker` hors du cadre de génération, du battement du statut Bloquant, de la liaison de délégation et de l'orbe ; tous respectent `SceneMotionScope.disabled`.
- **Peinture** : `ScenePanel` et `SceneBackdrop` sont enveloppés d'un `RepaintBoundary` posé **au-dessus** de la cellule (pas dans `_SurfaceAppearance`, qui garde le sien) ; le fond de points est un `CustomPainter` à `shouldRepaint` faux. Les halos `glow-*` ne s'appliquent qu'à un état actif (génération, voix qui parle, bouton armé) : jamais en permanence sur les six cellules.

## Références
- `product/architecture/design-system.md` (013), `product/architecture/frontend-screen.md`, `product/functional/features/design-ergonomie-013.feature` (D-01…D-07), `product/sources/design-system-2026-11-02/`.
- Notes `knowledge/` : [ds-tokens-style-dictionary], [ds-tokens-theme-extension], [ds-typography] (polices en assets, `OFL.txt` via `LicenseRegistry`), [ds-motion], [ds-a11y-wcag-contrast], [perf-repaint-boundary], [ds-widgetbook-4-testing].

## Risques
| Risque | Parade ou test qui le couvre |
|---|---|
| Une police **variable** ne rend pas les graisses sous Flutter Linux (Impeller/Skia) | T01 : test qui mesure la largeur de « 99,43 % » à `wght` 400 et 700 (elles doivent différer) + capture ; repli : instances statiques générées avec `fonttools` (`varLib.instancer`) |
| Les polices réelles changent la largeur des textes et font tronquer ou déborder des cellules (D-02, D-03, D-04, D-05) | `loadRealFonts` charge les polices de l'app **avant** de rejouer D-01…D-07 (U-03) ; `paragraphsTruncated` détecte l'ellipse |
| `kpi-xl` 76 px déborde la cellule de 302 px de haut | test de hauteur des cellules (013) ; taille réduite au plus juste, consignée |
| Ombres, dégradés et grille pèsent sur NFR-04 | `RepaintBoundary` au-dessus de la cellule, grille peinte une fois, glows seulement actifs ; `canvas_board_rebuild_test` (`debugOnRebuildDirtyWidget`, `debugOnProfilePaint`) reste vert ; mesure des 60 i/s en répétition (J7) |
| Contraste des fonds `*-ghost` (alpha) | paires mesurées **après composition** sur `surface-100` ; `scene_theme_test` étendu (U-04) |
| `ink-faint` (3,9:1) utilisé sous 24 px | U-01 interdit tout texte < 24 px ; `ink-faint` limité aux graduations et à « en veille » |
| Node absent ou version différente pour régénérer les tokens | Node 26.12.1 présent ; Style Dictionary épinglé à 5.7.1 avec `package-lock.json` ; sinon blocage documenté (`Bloquée`), pas de contournement à la main |
| Téléchargement des polices (réseau) | fichiers committés une fois (SHA-256 consigné dans `status.md`), source `github.com/google/fonts/ofl/…`, licence OFL 1.1 ; le build ne télécharge jamais rien |
| Une couleur codée en dur échappe au thème | `grep` de `Color(0x` hors `SceneTokens`, `voice_orb.dart` inclus ; un test d'architecture interdit `Color(0x` dans `lib/` hors du paquet de design |
