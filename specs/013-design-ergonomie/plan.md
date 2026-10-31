# 013 — Plan

Références : [pdr-0072](../../product/decisions/pdr-0072-design-ergonomics-013.md), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md), [p-fn-screen](../../product/functional/screen.md), [p-ar-frontend-screen](../../product/architecture/frontend-screen.md), [p-fn-catalog](../../product/functional/catalog.md), [p-fn-nfr](../../product/functional/nfr.md).
Notes `knowledge/` : [ds-motion], [ds-a11y-wcag-contrast], [ds-a11y-wcag-focus-target], [ds-package-structure], [ds-tokens-style-dictionary], [ds-tokens-theme-extension], [ds-widgetbook-4-setup], [ds-widgetbook-4-stories], [ds-widgetbook-4-testing], [ds-widgetbook-4-spike], [perf-repaint-boundary], [ux-desktop-focus], [test-golden-alchemist].

Aucun changement Go ni contrat : tout est Flutter (`apps/genesis_canvas`, `packages/features/canvas`, `packages/shared/design_system`) plus un nouveau paquet de catalogue sous `packages/shared/design_system/widgetbook`.

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `apps/genesis_canvas` | page, widgets | `pages/genesis_canvas/genesis_canvas_page.dart` (budget des zones), `widgets/agents_rail/agents_rail.dart` (rail horizontal), `widgets/stage_bar/stage_bar.dart` et `widgets/top_bar/top_bar.dart` (régie), `widgets/catalog_shelf/catalog_shelf.dart` (noms entiers), `widgets/protocol_panel/protocol_panel.dart` (débordement) |
| Flutter | `packages/features/canvas` | ui, catalogue | `src/ui/canvas_board.dart` (apparition animée, hauteur élastique), `src/catalog/{release_checklist,review_sentiment,trend_chart,key_indicator,crash_list}.dart` (retour à la ligne, titre et légende), `src/catalog/text_metrics.dart` |
| Flutter | `packages/shared/design_system` | shared | `lib/src/scene_theme.dart` (nourri par les tokens), `lib/src/generated/scene_tokens.g.dart`, `lib/src/scene_motion.dart` (durées et courbes), `tokens/*.tokens.json`, `tool/build_tokens.mjs` et `tool/package.json` (Style Dictionary épinglé), `widgetbook/` |
| Tests | `apps/genesis_canvas/test/acceptance/` | acceptation | `acte_design_ergonomie.feature` + `_test.dart` (D-01 à D-07) |

## Mise en page (A1, A5, A6 — décision pdr-0075 D1)
Le vide vient du rail : 200 px fixes (cinq lignes), vides tant qu'aucun `plan` n'est arrivé et pendant le rejeu. Le rail devient une **rangée horizontale** de 96 px (orchestrateur puis agents, nom sur une ligne et état en toutes lettres sur la seconde, texte ≥ 24 px) ; sans agent : « AGENTS A2A » et « aucun agent retenu » / rien tant qu'aucun plan n'est arrivé (RG-01, RG-08). Budget à 1920×1080 : barre 128, rail 96, rangée du bas 140, marges et intervalles 40 → canevas ≈ 676 px (grille 2 × ≈ 298 + bandeau de 72). Le budget de hauteur est calculé à partir de `LayoutBuilder` (hauteur disponible), pas de constantes de pixels, pour tenir aussi à 1366×768 en répétition. Largeurs inchangées (grille 2×2 puis 3×2, étagère 900, rejeu 480, panneau replié 460).
Régie : `StageBar` devient un groupe de deux contrôles homogènes (« Acte n/3 · Créer » puis « Remettre à vide »), hauteur 48 px, `Semantics` par bouton, bordure et contraste du thème de scène ; l'indicateur reste cliquable pour corriger (pdr-0071).
Panneau du protocole déplié : sa hauteur maximale est celle de la zone du canevas moins l'intervalle (plus de débordement de 39 px) ; `Positioned` dans la zone, pas dans la rangée du bas.
Repères de zone (A6) : libellés en petites capitales du thème (« AGENTS A2A », « CANEVAS · release-3-4 » seulement si un nom de release vient du contrat, sinon « CANEVAS »), « CATALOGUE · n / 6 utilisés » existant. Aucun libellé ne vient de la maquette pour une donnée.

## Cellules lisibles (A2, A3, A4 — D2)
- Un `Text` des composants passe à `maxLines: 2` avec retour à la ligne là où la cellule a la hauteur (checklist, avis, titres) ; la hauteur de ligne est mesurée par `text_metrics.dart` (existant) pour décider du nombre de lignes affichables, jamais d'ellipse sur un libellé de checklist ni d'avis (une ligne de crash garde l'ellipse, pdr-0074 D10).
- `TrendChart` : titre sur sa propre ligne (`Flexible` + retour à la ligne), légende en `Wrap` dessous ; la hauteur du tracé prend le reste.
- Étagère : nom entier sur la première ligne de la puce, « utilisé » / « inutilisé » à droite ou dessous selon la place ; 6 puces en deux colonnes de trois (la zone fait 900 px).
- Critère de capture : 1920×1080, `act1-replay` et `crashlist-replay`.

## Apparition animée (B1 à B3 — D3)
- Une surface suit trois phases (existantes : `skeleton`, `components`, `data`, lues dans `CanvasState`). Chaque changement de phase déclenche une transition **implicite** : `AnimatedSwitcher` (fondu 200 ms, `Curves.easeOutCubic`) entre squelette et composants, puis fondu des valeurs 150 ms ; le tout enveloppé d'un `RepaintBoundary` par cellule. Valeurs de durée et de courbe dans `SceneMotion` (source : [ds-motion], jamais d'`Easing.emphasized` qui n'existe pas).
- `MediaQuery.disableAnimations` (ou le réglage existant `_animationsOff` de la page) → durée zéro. En rejeu à la vitesse v, les durées sont divisées par v (bornées à 60 ms au plus bas) pour que le rejeu à 2× ne soit pas ralenti par les fondus ; le gate A2UI ne les attend jamais.
- Une transition ne change pas la place d'une surface (S-02) : `Opacity` et translation de 8 px seulement, jamais de changement de taille.
- NFR-04 : test de budget par `tester.pump` à pas de 16 ms pendant l'apparition de cinq surfaces, qui compte les reconstructions des widgets voisins (zéro pour les cellules non concernées) ; la mesure DevTools `--profile` reste à J7 (hors de ce que la boucle peut observer).

## Design system (C1 à C3 — D4)
- **Tokens** : `packages/shared/design_system/tokens/{primitives,semantic,scene}.tokens.json` (DTCG 2025.10) : couleurs (sRGB hexadécimal, pas d'OKLCH), typographie, espacements, rayons, durées. Sources : valeurs actuelles de `SceneTheme` (la mise en page ne change pas les couleurs en C1 : parité exacte).
- **Génération** : `tool/build_tokens.mjs` (Style Dictionary 5.x épinglé dans `tool/package.json`, format custom → `scene_tokens.g.dart` avec `ThemeExtension`, `lerp`). Le fichier généré est committé. La porte de la boucle n'exécute pas Node (hypothèse « Node en CI » de adr-0005 non confirmée, et `tools/loop/` n'est pas modifiable par la boucle) : un test Dart de **parité** lit les `.tokens.json`, résout les alias et compare chaque valeur à `SceneTheme`, ce qui détecte un fichier généré périmé sans Node. La régénération par Node est un script manuel (`tool/build_tokens.sh`), noté dans le README du paquet.
- **Widgetbook** : sous `packages/shared/design_system/widgetbook/` (app imbriquée, [ds-package-structure]), `widgetbook 4.0.0-beta.14` épinglé exactement, membre du workspace pub ; `*.stories.dart` : une story par `CatalogItem` genesis (6) et par brique (`DsStatusChip`, `DsSkeleton`, `DsNeutralState`), trois états ; thème de scène seul ; viewport 620×298 et 940×298 (cellules réelles). Tests : `testWidgetbook` (PNG et JSON sans comparaison, [ds-widgetbook-4-testing]) dans la porte `flutter` ; build web statique par script manuel (`tool/build_widgetbook.sh`, hébergement hors sujet). Pas de Widgetbook Cloud (adr-0006).
- **Accessibilité en test** (C3) : test qui calcule le contraste WCAG de chaque paire texte/fond du thème de scène (≥ 4,5 : 1, ≥ 3 : 1 au-dessus de 24 px gras) et les tailles de texte des composants (≥ 24 px) ; `meetsGuideline(androidTapTargetGuideline)` à 48 px pour les boutons de la régie.
- RG-09 inchangée : les composants du catalogue n'acceptent aucune couleur ni taille d'un message A2UI ; le thème de scène reste leur seule source.

## Contrats
Aucun contrat A2UI, canal ou Go. Tokens : fichiers DTCG (`$value`, `$type`, alias `{…}`) ; API Dart publique de `shared_design_system` inchangée (ajout de `SceneMotion` et du `ThemeExtension` généré).

## Cycle de vie et erreurs
Les `AnimationController` d'apparition sont créés et libérés par les widgets de cellule (`dispose`) ; aucune n'est détenue par un Bloc. Un message A2UI refusé n'anime rien. Pas de `getIt` dans les widgets (pdr-0057). Aucun Cubit.

## Sécurité
Aucun changement de surface d'attaque : pas de réseau, pas de secret. Node et Style Dictionary n'interviennent qu'en développement (génération), jamais à l'exécution ni dans la porte ; version épinglée, `package-lock.json` committé.

## Ordre et parallélisme
Lot A (mise en page : session principale + `feature-developer`, fichiers partagés de la page) → lot B (canevas) → lot C (design system). A et B touchent des fichiers voisins (`canvas_board.dart`, page) : **séquentiels**. C1 (tokens) peut avancer en parallèle de B après A si les fichiers sont disjoints (`design_system` seul) ; le Widgetbook (C2) dépend de C1. `product/`, `specs/`, `pubspec.yaml` racine : session principale seule.

## Risques
- Rail horizontal : cinq agents et leurs états ne tiennent pas dans 1872 px à 24 px → test avec cinq agents (la limite connue) ; repli : deux rangées de 56 px, budget déjà prévu.
- 1366×768 (répétition possible) : texte ≥ 24 px impose le défilement ? → non : le budget élastique réduit les cellules ; si une cellule ne tient pas, la liste de crashs montre moins de lignes (`count` borné) ; critère à 1920×1080 seulement, à 1366×768 « sans débordement ».
- Widgetbook 4 bêta : rupture possible → version exacte, spike mesuré ([ds-widgetbook-4-spike], 5 contournements connus) ; coupe C2 déclarée dans `progress.md` si le build bloque après 3 tentatives (la porte n'en dépend pas : le paquet est isolé).
- Style Dictionary absent sur la machine du porteur → fichier généré committé, parité testée : l'app ne dépend pas de Node.
- `no_placeholders` interdit les marqueurs d'inachevé dans le code : aucun dans les fichiers générés.
