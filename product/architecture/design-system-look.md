---
id: p-ar-design-system-look
title: Habillage du design system du 2026-11-02 (017) : palette, typographie, panneaux, statuts, boucles
area: architecture
status: draft
updated: 2026-11-02
sources: [specs/017-design-system-v2/spec.md, specs/017-design-system-v2/plan.md, specs/017-design-system-v2/status.md, product/sources/design-system-2026-11-02/README.md, packages/shared/design_system/lib/src/scene_theme.dart, packages/shared/design_system/lib/src/scene_panel.dart, packages/shared/design_system/lib/src/scene_backdrop.dart, packages/shared/design_system/lib/src/scene_fonts.dart, packages/shared/design_system/lib/src/scene_weight.dart, packages/shared/design_system/lib/src/ds_status_chip.dart, packages/shared/design_system/assets/fonts/LICENSES.md, packages/features/canvas/lib/src/ui/canvas_board.dart, apps/genesis_canvas/test/architecture/no_hardcoded_style_test.dart, knowledge:ds-typography, knowledge:ds-a11y-wcag-contrast, knowledge:perf-repaint-boundary]
links: [p-ar-design-system, pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0079-013-tokens-exception-to-adr-0005, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0007-closed-catalog-stage-theme, p-ar-frontend-screen, p-ar-quality, p-fn-nfr, p-fn-feature-design-system-017, p-fn-feature-design-ergonomics-013, p-sources, p-rm-backlog, p-rm-open-questions, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0008-ds-widgetbook-4-beta, ds-typography, ds-motion, ds-a11y-wcag-contrast, ds-tokens-style-dictionary, ds-tokens-theme-extension, perf-repaint-boundary]
tags: [design-system, typographie, polices, panneaux, statuts, contraste, nfr-04, nfr-05, 017]
---
# Habillage du design system du 2026-11-02 (017)

**En bref.** 017 (UI seulement, [pdr-0083](../decisions/pdr-0083-design-system-v2-ui-only.md)) habille l'app avec le design system du 2026-11-02 sans toucher au comportement, aux données, au contrat A2UI ni à la disposition de 013 (rectangles de S-02 et D-01 à D-07 inchangés). Tout texte fait **au moins 24 px** (NFR-05, pdr-0083 D4). Détails tranchés par la boucle : [pdr-0084](../decisions/pdr-0084-017-design-system-ui-details-assistant-decided.md) U1 à U15 (sous pdr-0062, contestables). Socle (tokens, générateur, mouvement, Widgetbook) : [p-ar-design-system](design-system.md). Scénarios : U-01 à U-06 ([p-fn-feature-design-system-017](../functional/features/design-system-017.feature)).

## Palette et rôles de `SceneTheme` (RG-09)

`SceneTheme` reste l'unique `ThemeExtension` ; ses rôles ont été figés avant les consommateurs (chaque ajout oblige à régénérer les tokens). `onNogo` n'existe pas (il ne servirait qu'à « Bloquer » par appui long, hors périmètre).

| Rôle | Couleur du design system |
|---|---|
| `background`, `surface`, `surface200`, `surface300`, `panelTop` | `void`, `surface-100`, `surface-200`, `surface-300`, `surface-200` (haut du dégradé) |
| `textPrimary`, `textSecondary`, `inkFaint` | `ink`, `ink-muted`, `ink-faint` |
| `accent`, `highlightOutline`, `agentWorking` | `signal` |
| `ok/risk/blocking Background` ; `…Foreground` | `go/warn/nogo-ghost` ; `go/warn/nogo` |
| `neutralBackground` ; `neutralForeground` | `surface-300` ; `ink-muted` |
| `actionNeutralBorder` ; `actionDangerBorder` | **`ink-muted`** (pas `line-strong`, voir contraste) ; `nogo` |
| `chartIos`, `chartAndroid`, `chartOther` | `ink`, `signal`, `baseline` (U3 ; « 3.3 » en pointillés, seuil `nogo` en tirets) |
| `agentIdle`, `agentRejected`, `agentInterrupted` | `ink-faint`, `warn`, `baseline` |
| Ajouts | `panelHighlight`, `line`, `lineStrong`, `plasma` (voix, jamais une donnée), `plasmaGhost`, `signalGhost`, `orbVeil` |

**Contraste** ([ds-a11y-wcag-contrast], mesuré au test, `Color.alphaBlend` sur les quatre fonds réels) : `line-strong` ne vaut que **2,30:1 sur `surface-100` et 2,44:1 sur `void`**, pas 3:1 comme l'affirme la source : réservée aux séparateurs et aux coins HUD, jamais seule frontière d'un bouton ni anneau de focus (le focus est `signal`, 3 px). `ink` vaut 13,86:1 sur `surface-300` (la source annonce ≥ 15:1 partout) : le test exige 15:1 sur `void`, `surface-100`, `surface-200` et 13:1 sur `surface-300`. `ink-faint` : 4,35 / 4,10 / 3,79 / 3,40:1 (grand texte, 3:1). `nogo` sur `nogo-ghost` : 6,02 / 5,57 / 5,10 / 4,54:1 (seuil 4,5 pour les mots de statut).

## Typographie ([ds-typography])

- **Polices embarquées** dans `packages/shared/design_system/assets/fonts/` : Space Grotesk (`wght` 300 à 700) et JetBrains Mono (`wght` 100 à 800), **variables** (elles n'existent qu'ainsi dans le dépôt Google Fonts), plus DejaVu Sans en repli. Source épinglée sur un commit de `google/fonts`, SHA-256 dans `README.md` et `LICENSES.md` (recalculés par un test), aucune dépendance `google_fonts`, aucun téléchargement. Familles déclarées **sans préfixe** au `pubspec.yaml` (Flutter pose `packages/shared_design_system/`) ; les styles utilisent les noms préfixés `SceneFonts.sans/.mono/.fallback` sans le paramètre `package:`.
- **Graisse** : `sceneWeight(n)` pose `FontWeight(n)` **et** `FontVariation('wght', n)`. Mesuré sous le vrai moteur (Impeller OpenGLES sous Xvfb, 3 lancements, bruit nul) : écart d'encre **0,0 %** entre l'axe seul et l'assistant à 500, 600 et 700 pour les deux familles ; **pas de gras synthétique** (U11 reconfirmée). Le moteur de la machine de démo reste à revérifier en J7.
- **Repli `DejaVu Sans`** dans les 9 styles : ✓ ▲ ▶ ↺ ◆ ★ et U+202F sont **absents des deux polices** (✓ ↺ ★ et U+202F de JetBrains Mono seulement) ; DejaVu Sans les couvre.
- **Licences** : OFL 1.1 des deux polices (sans « Reserved Font Name ») et licence DejaVu embarquées, enregistrées par `registerSceneFontLicenses()` ; `main()` appelle `registerAppLicenses()` (`app/bootstrap/app_licenses.dart`).
- **Tailles** (≥ 24 px, hiérarchie par graisse, famille, couleur, interlettrage) : `value` (kpi-xl) 76 px mono 600 (tient dans la cellule 624×302), `verdict` 28 mono 700, `actIndicator` 28 sans 700, `title` 24 sans 600, `body`, `button`, `transcript`, `data` et `label` 24. Chiffres tabulaires sur `data`, `value`, `verdict`. Hauteurs de ligne de 013 conservées (1,2 à 1,3 : `lineHeightOf` fixe le nombre de lignes des avis, D-02).
- **`label`** (mono, interlettré, `ink-muted`) est réservé à **5 étiquettes HUD** : « CATALOGUE · » et « n / 6 utilisés », « REJEU », « AGENTS A2A », « FLUX A2UI · live ». Leurs **capitales sont reportées** (une vingtaine de tests cherchent la casse d'origine ; `sceneCaps` retiré, pdr-0084 U14). Données (valeurs, deltas, noms d'agents, graduations, JSON du protocole) en `data` ; mots en `body`. Les **puces de statut, seuils et valeurs de la checklist sont en `body`** (la mono, plus large, casse D-02 ; U13).

## Panneaux et fond (U1, U9)

- **`ScenePanelDecoration`** : couche décorative **statique, sœur** du contenu (jamais une enveloppe : l'ombre ne doit pas être rognée par le `ClipRect` de l'apparition, et `CellFrame`, `NoDataCell`, `DsSkeleton`, `DsNeutralState` perdent fond et rayon pour éviter un double cadre). Dégradé `panelTop` → `surface`, bordure `line` 1 px, filet de 1 px `panelHighlight` (remplace la ligne `inset` du CSS, que `BoxShadow` ne sait pas rendre), ombre `SceneShadow.panel` (+ `glow` facultatif, sans consommateur), rayon 16, **deux** coins HUD en L de 10 px (haut gauche, bas droit, `lineStrong` à 80 %, comme le CSS), un `RepaintBoundary` à la racine, aucun `Clip*`.
- **`ScenePanel`** : décoration + enfant ; `inset` de **4 px** = `ScenePanel.cellInset` (`SceneSpace.space1`) car les cellules de la grille sont jointives (deux panneaux gardent 8 px visibles) ; marge interne de 16 px conservée (le `space-6` de 24 px prendrait de la largeur aux textes de 24 px). Dans `CanvasBoard`, chaque `_SurfaceCell` empile `ScenePanelDecoration` (inset 4), `RepaintBoundary(ClipRect(contenu animé))`, contour de surbrillance (inset 4, rayon 16). Étagère, barre de rejeu et panneau du protocole : `ScenePanel(inset: 0)`.
- **`SceneBackdrop`** : `void` et grille de points `line` de 2 px au centre de chaque tuile de 24 px, soit **3600 points** (80 × 45) à 1920×1080, en **un seul `drawRawPoints`** (`Float32List`), `shouldRepaint` sur la couleur seule ; posée dans la frontière de capture de la page. Bordure de panneau et fond peu contrastés : cela suit la source.

## Statuts, orbe et boucles (U6, U7, U8)

- **Statuts** : fond `*-ghost`, texte `go/warn/nogo`, toujours le mot. `ok` ajoute **✓** (`Text` séparé, sous `ExcludeSemantics`) ; `blocking` un **point `nogo` de 8 px battant** (halo de 7 px sur 70 % de `SceneMotion.beacon`, `RepaintBoundary` local, figé et sans halo sous `disabled`) ; `risk` et statut inconnu sans glyphe ni point. Parmi les statuts, **seul Bloquant bat**. **`DsStatusChip.measure(context, status, label)`** est la source unique de la géométrie de la puce (`release_checklist.dart` ne recalcule plus) ; remplissage horizontal 12 px, écart 6 px.
- **Orbe** (`voice_orb.dart`) : corps et arc `plasma`, éclair `textPrimary`, voile `orbVeil`, halo en `RadialGradient` `plasmaGhost` (ni `MaskFilter` ni `saveLayer`), rayon plafonné au cadre de 64 px ; période `SceneMotion.orb`, **divisée par la vitesse de rejeu**. Le `glow-plasma` complet n'est pas repris (U8 amendée).
- **Boucles** : orbe, squelette (`SceneMotion.skeleton`), battement et liaison de délégation passent par `SceneMotionScope.loop` et s'arrêtent sous `disableAnimations`, chacune dans son `RepaintBoundary`. `TopBar` est sous le `SceneMotionScope` de la page.

## Tests d'architecture et régression

`apps/genesis_canvas/test/architecture/no_hardcoded_style_test.dart` : **un seul détecteur**, sans liste d'exceptions, sur tout `lib/` de `apps/` et `packages/` hors `*.g.dart` et hors `packages/shared/design_system` (Widgetbook compris). Il interdit `Color(0x`, `Color.from(`, `Colors.` (Material et Cupertino), `HSLColor.`/`HSVColor.`, `fontFamily:`, `letterSpacing:` numérique, `fontWeight:`, `Radius.circular(<nombre>)` (et `BorderRadius.circular`) et tout `fontSize:` littéral sous 24 px ; un auto-test par motif. Limite connue : `fontSize: <identifiant>` n'est pas vu.

La régression R-01 (rejeu) de T12b est née du texte plus large : le panneau du protocole déplié recouvre 304 px des 480 px de la barre de rejeu ; R-01 ne tient que par **3,2 px**. Voir [Q-92](../roadmap/open-questions.md).
