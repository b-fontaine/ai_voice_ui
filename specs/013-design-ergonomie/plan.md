# 013 — Plan

Références : [pdr-0072](../../product/decisions/pdr-0072-design-ergonomics-013.md), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md), [p-fn-screen](../../product/functional/screen.md), [p-ar-frontend-screen](../../product/architecture/frontend-screen.md), [p-fn-catalog](../../product/functional/catalog.md), [p-fn-nfr](../../product/functional/nfr.md).
Notes `knowledge/` : [ds-motion], [ds-a11y-wcag-contrast], [ds-a11y-wcag-focus-target], [ds-package-structure], [ds-tokens-style-dictionary], [ds-tokens-theme-extension], [ds-widgetbook-4-setup], [ds-widgetbook-4-stories], [ds-widgetbook-4-testing], [ds-widgetbook-4-spike], [ds-widgetbook-4-genui], [perf-repaint-boundary], [ux-desktop-focus], [test-golden-alchemist].

Aucun changement Go ni contrat : tout est Flutter. Revue du plan (2026-10-31) : verdict À AMENDER, amendements P1 à P8 intégrés ci-dessous (voir `status.md`).

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `apps/genesis_canvas` | page, widgets | `pages/genesis_canvas/genesis_canvas_page.dart` (constante `_railHeight`, `SceneMotionScope`, surbrillance en `ValueListenable`), `widgets/agents_rail/agents_rail.dart` (rail horizontal), `widgets/stage_bar/stage_bar.dart` (régie), `widgets/catalog_shelf/catalog_shelf.dart`, `widgets/protocol_panel/protocol_panel.dart` |
| Flutter | `packages/features/canvas` | ui, catalogue | `src/ui/canvas_board.dart` (cellules sélectives, apparition), `src/catalog/{release_checklist,review_sentiment,trend_chart,key_indicator,crash_list,bound_item}.dart`, `src/catalog/text_metrics.dart` (`measureTextHeight`) |
| Flutter | `packages/shared/design_system` | shared | `lib/src/scene_theme.dart` (valeurs depuis `SceneTokens`), `lib/src/generated/scene_tokens.g.dart`, `lib/src/scene_motion.dart` (`SceneMotion`, `SceneMotionScope`), `tokens/*.tokens.json`, `tool/` (Style Dictionary épinglé) |
| Flutter | `apps/genesis_widgetbook` (nouveau, couche app, P1) | catalogue | `lib/`, `*.stories.dart`, `test/` ; membre du workspace pub ; dépend de `feature_canvas` et `shared_design_system` |
| Flutter | `testing/` (T03) | outils de test | polices réelles et `loadRealFonts` déplacés depuis `packages/features/canvas/test/fixtures/fonts` ; option de police de `PageRig` ; `paragraphsTruncated` |
| Tests | `apps/genesis_canvas/test/acceptance/` | acceptation | `acte_design_ergonomie.feature` + `_test.dart` (D-01 à D-07) |

## Mise en page (A1, A5, A6 — pdr-0075 D1)
- **Rail horizontal de 96 px** (budget à 1920×1080 : barre 128, rail 96, rangée du bas 140, marges et intervalles 40, canevas **676 px = 2 × 302 + 72**). La page change seulement la constante `_railHeight` : le canevas est déjà `Expanded` (pas de `LayoutBuilder`). Hauteur du rail **fixe même vide** : l'arrivée du premier `plan` ne déplace rien.
- Le rail : colonne de tête « AGENTS A2A » à gauche de la rangée ; tuiles à droite (orchestrateur puis agents). Tuile = ligne 1 : pastille et nom ; ligne 2 : « état · tâche » (`AgentStatus.label`/`detail`), ellipse sur la tâche seule ; texte ≥ 24 px. Cinq tuiles au pire cas (noms et tâches réels, polices réelles) doivent tenir dans 1872 px.
- **Liaison animée de délégation** (fiche, jamais livrée) : hors périmètre tant que le porteur n'a pas tranché ([Q-85](../../product/roadmap/open-questions.md)). Le rail laisse l'intervalle orchestrateur → agents libre (pas de contenu) pour un connecteur futur.
- **Repères de zone** : « AGENTS A2A » (rail), « CATALOGUE · n / 6 utilisés » (existant). Pas de libellé « CANEVAS » (aucun budget de hauteur, aucune donnée de release dans les messages) ; la maquette n'inspire que la structure.
- **Régie** : `StageBar` empile verticalement deux contrôles de largeur égale, 48 px chacun (`VisualDensity.standard`, `minimumSize` 48 explicites) : « Acte n/3 · … » puis « Remettre à vide » (48 + 4 + 48 ≤ 104 px utiles dans la barre de 128), testés avec le libellé le plus long et sous `TargetPlatform.linux` (par défaut `flutter_test` simule Android et la cible `padded` fausserait le test).
- **Panneau du protocole** déplié : le débordement de 39 px vient de son contenu (4 entrées dont le JSON `actions`) ; le nombre d'entrées affichées est calculé sur la hauteur disponible, hauteur dépliée ≤ zone du canevas. Test : 4 entrées dont une refusée plus `actions`, aucune exception.
- Tests calés sur l'ancien budget à mettre à jour (T11) : `genesis_canvas_page_layout_test.dart` (l. 66-67), `gridCell` et `gridCell3x2` de `cell_height_real_fonts_test.dart`, `review_sentiment_test.dart` (l. 88), `decision_status_test.dart` (l. 37).
- 1366×768 : hors critère (limite assumée de `screen.md`) ; pdr-0075 « Réexaminer si » la couvre.

## Cellules lisibles (A2, A3, A4 — pdr-0075 D2)
- **Mesure** : `text_metrics.dart` gagne `measureTextHeight(context, text, style, maxWidth)` (hauteur d'un paragraphe à largeur donnée). La capacité de la checklist est récrite avec des **hauteurs de ligne variables**, en gardant la priorité bloquant puis à risque ; « + N autres critères » reste.
- **Avis** : on n'affiche que les extraits **entiers** qui tiennent dans la cellule (retour à la ligne, jamais d'ellipse), puis « + N avis » ; en 3×2 (≈ 624 × 302) un ou deux extraits tiennent, c'est assumé et vérifié (D-02 compte les extraits affichés avec les données de l'acte 2).
- **Checklist** : libellés à la ligne, plus d'ellipse ; la ligne d'un crash garde l'ellipse (pdr-0074 D10).
- `TrendChart` : titre sur sa ligne (retour à la ligne permis), légende en `Wrap` dessous, tracé sur le reste.
- **Étagère** : deux rangées de trois puces, nom entier ; l'état est porté par l'icône (coche pour « utilisé », cercle vide pour « inutilisé ») et par `Semantics` (« utilisé » / « inutilisé ») ; le compte reste dans l'en-tête « CATALOGUE · n / 6 utilisés ». Disposition à confirmer par la capture (T17) avant d'être figée.
- **Tests de lisibilité en polices réelles** (T03) : Ahem (≈ 24 px par glyphe) ne permet pas d'asserter « non tronqué ». `paragraphsTruncated(tester, root:)` (fondé sur `RenderParagraph.didExceedMaxLines`, en excluant `crash-label-*`) tourne avec les polices réelles ; le test Ahem existant reste le contrôle de débordement.

## Apparition animée (B1 à B3 — pdr-0075 D3)
- **`SceneMotionScope`** (InheritedWidget de `shared_design_system`, exporté par le barrel), posé par la page : durée nulle si `MediaQuery.disableAnimationsOf(context) || _animationsOff`, vitesse de rejeu = `ReplayActive.snapshot.speed` (la slice `feature_canvas` ne lit pas `ReplayBloc`). **Jamais de `TickerMode` sur le canevas** (il figerait l'animation à l'opacité 0 en scénario et en capture).
- **Un `_SurfaceAppearance`** (`StatefulWidget`, `SingleTickerProviderStateMixin`, un seul `AnimationController` par surface, libéré dans `dispose`) pilote le passage squelette → composants (fondu 200 ms, `easeOutCubic`, translation de 8 px **sous** `surface-<id>`) ; le `RepaintBoundary` reste toujours présent, à place fixe, pour ne pas remonter `Surface`. Le fondu des valeurs (150 ms) n'est posé que dans `boundCatalogItem`, du passage « sans données » à « données », avec une clé par état et **jamais par valeur** : un `updateDataModel` de l'acte 2 ne rejoue rien et ne recrée pas le `State` de `_DecisionStatus` (pdr-0064 D1, S-02). Les 400 ms codées en dur de `_DecisionStatus` passent par `SceneMotion`.
- Rejeu à la vitesse v : durées divisées par v (plancher 60 ms) ; le gate A2UI n'attend jamais les fondus. `_captureWhenSettled` (10 frames) : durée nulle en scénario et capture, sinon la capture tomberait en plein fondu.
- Tests existants qui supposent l'absence du squelette juste après un `pump`, à mettre à jour (T21c) : `catalog_harness.dart` (l. 205), `canvas_board_test.dart` (l. 123), `genesis_catalog_test.dart` (l. 125), `crash_list_test.dart` (l. 138). D-06 mesure l'opacité rendue sans importer `SceneMotion` (le rouge vient d'un comportement, pas d'une compilation).
- **Périmètre de reconstruction (NFR-04 — P6)** : aujourd'hui `CanvasBoard` reconstruit toutes les cellules à chaque changement de phase (`buildWhen`) et la page le reconstruit à chaque `highlightedSurfaceId`. Refonte : le board ne se reconstruit que sur `surfaceIds` ; chaque cellule est un `_SurfaceCell(id)` avec `BlocSelector<CanvasBloc, CanvasState, SurfacePhase?>` ; la surbrillance passe par un `ValueListenable<String?>` créé par la page, libéré dans `dispose`, lu par chaque cellule. Test de **périmètre de reconstruction et de peinture** (`debugOnRebuildDirtyWidget`, `RenderRepaintBoundary.debugSymmetricPaintCount`) : l'arrivée d'une surface ne reconstruit ni ne repeint les cellules voisines. Les 60 i/s eux-mêmes restent mesurés à J7 (DevTools `--profile`).

## Design system (C1 à C3 — pdr-0075 D4)
- **Tokens** : `packages/shared/design_system/tokens/{primitives,semantic,scene}.tokens.json` (DTCG 2025.10, couleurs sRGB hexadécimales, typographie, espacements, rayons, durées dont celles de `SceneMotion`). Parité exacte avec les valeurs actuelles de `SceneTheme`.
- **Génération (écart à adr-0005, noté dans pdr-0075)** : le format custom émet des **constantes** (`abstract final class SceneTokens { static const … }`) consommées par `SceneTheme.dark()` ; `SceneTheme` reste l'**unique** `ThemeExtension` (RG-09), sans second `ThemeExtension` aux valeurs dupliquées, et `const SceneTheme.dark()` (repli de `SceneTheme.of`) continue de fonctionner. Le script exécute `dart format` sur sa sortie, `log.warnings: 'error'`, `npm ci --ignore-scripts`, Style Dictionary ≥ 5.7.1 épinglé exactement, `package-lock.json` committé, `node_modules` dans `.gitignore`.
- **Contrôle sans Node dans la porte** (`tools/loop/` intouchable par la boucle) : l'en-tête de `scene_tokens.g.dart` porte le **sha256** des `tokens/*.tokens.json` ; un test Dart recalcule ce hash et échoue si le fichier généré est périmé ; la parité des valeurs (tokens résolus ↔ `SceneTheme`) complète. Le fichier généré passe `dart format --set-exit-if-changed` et `analyze --fatal-infos`.
- **Widgetbook (P1)** : application `apps/genesis_widgetbook/` (couche app : autorisée à dépendre de `feature_canvas` et `shared_design_system`, sans toucher `workspace_dependency_rules_test.dart` qui interdit `shared/*` → `feature_*`), `widgetbook 4.0.0-beta.14` épinglé exactement, membre du workspace. **Pas « isolé » :** membre du workspace il entre dans la résolution pub unique (conflit possible entre le générateur embarqué de Widgetbook 4 — analyzer, source_gen — et `injectable_generator`, `bdd_widget_test`) et `verify.sh` y lance `build_runner`, `dart format`, `analyze --fatal-infos` (y compris les `*.stories.g.dart`). T32a vérifie tout cela **avant** la première story ; en cas d'échec, coupe C2 en retirant le membre.
  - Stories des 6 composants genesis : un hôte `StatefulWidget` crée un `SurfaceController(catalogs: [genesisCatalog])`, libéré dans `dispose`, alimenté par les exemples `contracts/a2ui/genesis/v1/examples/*.jsonl` embarqués en assets (motif `CachedSurface`, [ds-widgetbook-4-genui], non testé par le spike : T33 le valide). Les vues des composants sont privées, seul le `CatalogItem` est public.
  - États par composant : données, sans données, neutre. Le squelette est couvert **une fois** par la story `DsSkeleton` (pas six stories identiques). Briques : `DsStatusChip`, `DsSkeleton`, `DsNeutralState`. Viewports 620×302 et 940×302. Pas de Widgetbook Cloud (adr-0006).
  - Test : `testWidgetbook` n'échoue jamais sur une story absente ; T33 ajoute un test qui compare l'ensemble des composants de la configuration à `GenesisContract.components` plus les 3 briques.
  - Build web statique : script manuel `tool/build_widgetbook.sh`.
- **Accessibilité (C3)** : le contraste des paires du thème et le texte ≥ 24 px sont déjà testés (`scene_theme_test.dart` l. 25-145, `paragraphsBelowMinimum`) : seules les paires nouvelles de 013 (bordures de la régie, repères, icônes de l'étagère) et les tailles sous Linux s'ajoutent, dans les tâches d'interface concernées.
- RG-09 inchangée : aucune couleur ni taille ne vient d'un message A2UI.

## Contrats
Aucun contrat A2UI, canal ou Go. Tokens : DTCG (`$value`, `$type`, alias `{…}`). API publique de `shared_design_system` : ajout de `SceneMotion`, `SceneMotionScope`, `SceneTokens`.

## Cycle de vie et erreurs
`AnimationController` et `SurfaceController` créés et libérés par leurs widgets (`dispose`) ; aucun détenu par un Bloc ; le `ValueListenable` de surbrillance est libéré par la page. Un message A2UI refusé n'anime rien. Pas de `getIt` dans les widgets (pdr-0057), aucun Cubit.

## Sécurité
Pas de réseau ni de secret ajoutés. Node et Style Dictionary servent en développement uniquement (jamais à l'exécution ni dans la porte) ; versions épinglées, scripts npm désactivés (`--ignore-scripts`).

## Ordre et parallélisme
Une seule pile : tâches séquentielles. T03 (outillage de test) précède les tests de lisibilité ; lot A, puis lot B (T21a avant T21b et T21c), puis lot C (T30a, T30b, T32a, T32, T33). `product/`, `specs/`, `pubspec.yaml` racine : session principale seule.

## Risques
- Rail à cinq tuiles : ne tient pas à 24 px → repli : état et tâche sur une seule ligne, ou deux rangées de 56 px ; décidé par la capture et le test de cinq tuiles.
- Avis : en 3×2 un seul extrait peut tenir ; si c'est jugé insuffisant à la capture, Q au porteur (disposition de la cinquième surface, option 2 de Q-83).
- Refonte des cellules (P6) : régression de rendu → les tests existants de `canvas_board` restent la référence ; chaque étape garde `gate --unit flutter` vert.
- Résolution pub avec Widgetbook 4 bêta → T32a avant tout, coupe C2 sinon.
- Style Dictionary absent chez le porteur → fichier généré committé et hash testé : l'app ne dépend pas de Node.
- `no_placeholders` interdit les marqueurs d'inachevé dans le code : aucun dans les fichiers générés.
