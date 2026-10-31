---
id: p-ar-design-system
title: Design system, tokens, apparition animée et catalogue Widgetbook (livré par 013)
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/013-design-ergonomie/spec.md, specs/013-design-ergonomie/plan.md, specs/013-design-ergonomie/status.md, packages/shared/design_system/tool/build_tokens.mjs, apps/genesis_widgetbook/README.md, knowledge:ds-tokens-style-dictionary, knowledge:ds-motion, knowledge:ds-widgetbook-4-genui]
links: [pdr-0072-design-ergonomics-013, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0007-closed-catalog-stage-theme, p-ar-frontend-screen, p-ar-frontend, p-ar-quality, p-ar-stack, p-fn-screen, p-fn-nfr, p-fn-catalog, p-fn-feature-design-ergonomics-013, p-rm-open-questions, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0006-ds-no-widgetbook-cloud, adr-0008-ds-widgetbook-4-beta, ds-tokens-style-dictionary, ds-tokens-theme-extension, ds-motion, ds-a11y-wcag-contrast, ds-a11y-wcag-focus-target, ds-widgetbook-4-setup, ds-widgetbook-4-stories, ds-widgetbook-4-testing, ds-widgetbook-4-spike, ds-widgetbook-4-genui, perf-repaint-boundary]
tags: [design-system, tokens, widgetbook, animation, nfr-04, nfr-05, 013]
---
# Design system, apparition animée et catalogue Widgetbook (013)

**En bref.** La fonctionnalité 013 (2026-10-31) ancre le thème de scène dans des **tokens DTCG** générés en Dart, anime l'apparition des surfaces sans rien déplacer (FR-04, NFR-04) et publie un **catalogue Widgetbook** des briques et des six composants genesis. Détails d'interface tranchés par la boucle ([pdr-0075](../decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md) D3 et D4, sous pdr-0062) ; mise en page : [p-fn-screen](../functional/screen.md), [p-ar-frontend-screen](frontend-screen.md).

## Tokens et thème (`packages/shared/design_system`)

| Élément | Livré |
|---|---|
| Source | `tokens/{primitives,semantic,scene}.tokens.json`, DTCG 2025.10 : couleurs `{colorSpace, components, hex}`, dimensions et durées avec unité, alias primitives → sémantique → scène ; valeurs reprises à l'identique de `SceneTheme.dark()` et `SceneMotion` |
| Générateur | `tool/build_tokens.mjs`, **Style Dictionary 5.7.1 exact**, `package-lock.json` committé, `npm ci --ignore-scripts`, `log.warnings: error`, `dart format` sur la sortie ; script manuel `tool/build_tokens.sh` (supprime `node_modules`) |
| Sortie | `lib/src/generated/scene_tokens.g.dart` **committé** : `SceneTokens`, constantes ; **interne au paquet**, non exporté par le barrel |
| Contrôle sans Node | l'en-tête porte un `tokens-sha256` (les `*.tokens.json` triés par nom, puis le générateur, octets bruts ; Node et Dart donnent le même) ; `tokens_hash_test` le recalcule, `tokens_parity_test` compare chaque token `scene.*` au thème (table de lecture unique, indépendante de l'ordre). **La porte de la boucle n'exécute jamais Node** |
| Fin de ligne | `.gitattributes` : `tokens/*.tokens.json`, `tool/build_tokens.mjs` et `scene_tokens.g.dart` en `text eol=lf` (le hash porte sur les octets) |
| Thème | `SceneTheme` reste l'**unique `ThemeExtension`** (RG-09, [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md)) ; `sceneTextStyle(context, style)` (= `DefaultTextStyle` fusionné) et `sceneMaterialTheme()` (plancher de 24 px, NFR-05) partagés par l'app, les tests et Widgetbook |
| Non tokenisé | espacements et rayons (absents de `SceneTheme`) ; la translation de 8 px l'est (`scene.motion.translation`) |

⚠️ **Écarts à [adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md)** (constantes `SceneTokens` au lieu d'une `ThemeExtension` générée ; test de hash et de parité au lieu de la régénération et de `git diff --exit-code` en CI) : consignés dans pdr-0075 D4, contestables, **ouverts au porteur** : [Q-86](../roadmap/open-questions.md). `npm audit` signale un avis modéré (`deepmerge`, prototype poisoning) tiré par Style Dictionary 5.7.1 : outil de développement sur des tokens locaux, hors exécution et hors porte ; correctif proposé (retour à la v3) non appliqué ; au porteur.

## Mouvement et périmètre de reconstruction (FR-04, NFR-04)

- **`SceneMotion`** : durées 200 ms (squelette → composants), 150 ms (valeurs), 400 ms (statut de décision), `easeOutCubic`, plancher 60 ms ([ds-motion]). **`SceneMotionScope`** (posé par la page) : durée nulle sous `MediaQuery.disableAnimations`, en mode scénario ou en capture ; divisée par `ReplayActive.snapshot.speed` en rejeu ; `play(context, controller, base)` ; **jamais de `TickerMode`** sur le canevas (il figerait l'opacité à 0).
- **`_SurfaceAppearance`** : un `AnimationController` par surface, fondu et translation de 8 px sous `surface-<id>`, dans `RepaintBoundary(ClipRect(…))` à place fixe ; le contour de surbrillance est un frère du `RepaintBoundary` (il ne repeint pas le contenu). Le squelette part dès le passage aux composants (F-02 de 012, C6 de 009), sans fondu croisé ; une surface présente au premier rendu s'affiche sans fondu. `_ValueFade` (dans `boundCatalogItem`) : fondu de 150 ms du seul passage « sans données » → « données », jamais rejoué par un `updateDataModel`. `_DecisionStatus` suit le scope.
- **Périmètre de reconstruction** : `CanvasBoard` se reconstruit sur `surfaceIds` ; une `_SurfaceCell(id)` mémorisée par surface, à `BlocSelector<CanvasBloc, CanvasState, SurfacePhase?>` ; surbrillance par `ValueListenable`. Tests : `canvas_board_rebuild_test.dart` (`debugOnRebuildDirtyWidget`, `debugOnProfilePaint`, `debugSymmetricPaintCount` : l'arrivée d'une surface ne reconstruit ni ne repeint ses voisines), `canvas_board_appearance_test.dart`, scénarios D-06 et D-07 ([p-fn-feature-design-ergonomics-013](../functional/features/design-ergonomie-013.feature)).
- **NFR-04** : le périmètre est prouvé par test ; **les 60 i/s eux-mêmes restent à mesurer au profil `--profile` sur la machine de démo en répétition (J7)** ([p-ar-quality](quality.md) § Mesure de 013).

## Catalogue Widgetbook (`apps/genesis_widgetbook`)

- **Application de la couche app**, membre du workspace pub, sans Widgetbook Cloud ([adr-0006](../../knowledge/decisions/adr-0006-ds-no-widgetbook-cloud.md)) : `shared/*` ne peut pas dépendre de `feature_canvas` ; la résolution pub est restée sans conflit (`widgetbook 4.0.0-beta.14` exact, [adr-0008](../../knowledge/decisions/adr-0008-ds-widgetbook-4-beta.md), `resizable_widget 1.0.5` en plus au lock) et les règles d'architecture passent sans adaptation : pas de coupe C2.
- **Stories** : 3 briques (`DsStatusChip` ×4 états, `DsSkeleton`, `DsNeutralState`) et 6 composants genesis × 3 états (données, sans données, neutre) × 2 viewports (640×318 et 952×318, soit des cellules de 624×302 et 936×302 et une marge de 8 px). Hôte `GenesisSurfaceState` : `SurfaceController(catalogs: [genesisCatalog()])`, exemples `contracts/a2ui/genesis/v1/examples/*.jsonl` copiés dans `assets/examples/` (un test de dérive les compare aux originaux), `DeleteSurfaceMessage` avant chaque rechargement, erreur de lecture visible (`host-error`), `SceneMotionScope(disabled: true)` ([ds-widgetbook-4-genui]).
- **Tests** : `testWidgetbook` (61 tests) et un test d'ensemble (composants de la configuration = `GenesisContract.components` + 3 briques) : `testWidgetbook` n'échoue pas de lui-même sans story.
- **Build web** : `apps/genesis_widgetbook/tool/build_widgetbook.sh <base-href>` (manuel, hors porte). Pas de runner `linux/` versionné.
- Contournements du spike utilisés ([ds-widgetbook-4-spike]) : import `flutter/widgets.dart`, marge de 8 px dans l'`appBuilder`, `ScenarioDefinition` explicites.

## Outillage de test (`testing/real_fonts`)

Polices réelles Noto Sans et DejaVu Sans (`loadRealFonts`, option de famille de `PageRig`) et `paragraphsTruncated(tester, root:)` : détecte la troncature par `maxLines` et la coupe verticale (`size.height < getMaxIntrinsicHeight − 0.5`), hors `crash-label-*` (ellipse voulue, pdr-0074 D10). Avec Ahem (police de test) une troncature ne se mesure pas ; les cibles tactiles se testent sous `TargetPlatform.linux`. Aucun texte coupé verticalement n'a été trouvé dans l'app.
