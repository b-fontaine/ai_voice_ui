# 017 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/017-design-system-v2
- **Backlog** : EP-04, EP-01
- **Mis à jour** : 2026-11-02 19:00

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-11-02 | Définir | `spec.md` (périmètre, décisions d'UI U1 à U11, tailles ≥ 24 px, scénarios U-01 à U-06), `plan.md`, `tasks.md` (T01, T10 à T21, T90 à T92). Consultations : `product-lookup` (pdr-0083, Q-91, NFR-05), `kb-lookup` ([ds-typography], [ds-tokens-style-dictionary], [ds-motion], [ds-a11y-wcag-contrast]). Constats : les deux polices n'existent qu'en fichiers variables (dépôt `google/fonts`, `ofl/spacegrotesk` et `ofl/jetbrainsmono`, OFL) ; Node 26.12.1 disponible pour `tool/build_tokens.sh` | commit `specs/017-design-system-v2` |
| 2026-11-02 | Revue du plan | `architect-reviewer` (mode PLAN) : verdict **À AMENDER** (P1 à P3 bloquantes, P4 à P7 importantes, P8 mineure) ; toutes intégrées : `spec.md` (U1, U7 à U9, U11, U12, table de tailles complète), `plan.md` (contrats tokens, façades, peinture, polices, mouvement, risques), `tasks.md` (T01 avec D-06, T10 étendu, T11 générateur, T12a/b, T13 boucles, T19a/b/c), pdr-0084 amendée | commits de `specs/017-design-system-v2` et `product/decisions` |
| 2026-11-02 | Gherkin | T01 : `product/functional/features/design-system-017.feature` (U-01 à U-06) enregistré dans les index ; D-06 recalé (480 ms prouvé par une attente intermédiaire : 240 + 260 ms, 120 + 130 ms à 2 x) ; U-04 et U-05 passent par l'acte 2 pour voir « Bloquant » (au tableau 3.4 seuls `ok` et `risk` existent). Automatisation (`feature-developer`, tests seulement, `lib/` intact) dans `apps/genesis_canvas/test/acceptance/` : `acte_design_systeme.feature`/`_test.dart`, 20 steps, 4 supports. **Sortie rouge attendue** : U-01 et U-03 verts (garde-fous) ; U-02 rouge `données hors police JetBrains Mono : « Arrêter » : famille aucune…` ; U-04 rouge `mot « Validé » (statut ok) : couleur #8ff0b5ff, attendue go #3ef2a5ff` ; U-05 rouge `Expected: a numeric value within <0.5> of <10.0>  Actual: <8.0>` ; U-06 rouge `série « Android 3.4 » : couleur #6cb6ffff, attendue signal #3de8ffff` ; D-06 recalé rouge `le contenu de crashes est déjà pleinement visible` (240 ms) et `le contenu de checklist est déjà pleinement visible` (×2). Rejeu des steps suivants (sonde jetable) : blocking `#ffb3b8ff` attendue `nogo`, glyphe ✓ absent, battement `[]`, 7 `Ticker` actifs sous `disableAnimations` | `.omc/state/loop/gates/20261102-185534-unit-flutter.log` (8 contrôles, 340 tests, TOUT VERT) ; contrôle de la session : `flutter test test/acceptance/acte_design_systeme_test.dart` → +2 -4 |

## Revue d'architecte
**Revue du plan (mode PLAN, `architect-reviewer`, Opus) : verdict À AMENDER** — 3 bloquantes, 4 importantes, 1 mineure. Toutes intégrées dans `spec.md`, `plan.md`, `tasks.md` et [pdr-0084](../../product/decisions/pdr-0084-017-design-system-ui-details-assistant-decided.md).
- [x] **P1 (bloquante)** — U2 (480 ms) rend D-06 de 013 rouge (250 ms ; 120 ms en ×2) et des tests unitaires d'apparition : D-06 recalé par product-curate (U12), tests recalés dans T13, critère « D-06 aux durées de U2 ». Le conflit signalé par la revue (pdr-0075 D3 codée dans le Gherkin de 013) est une conséquence de pdr-0084 U2, décidée sous pdr-0062 et contestable par le porteur.
- [x] **P2 (bloquante)** — le générateur de tokens et la parité ne savent pas exprimer alpha, `shadow`, `cubicBezier`, `fontFamily`, interlettrage en px ; arrondi à une décimale ; ombre `inset` ; flou CSS ≠ `blurRadius` ; façades sans exporter `SceneTokens` : T11 étendu (générateur, règle de flou r = (B/2 − 0,5)/0,57735, `SceneSpace`/`SceneRadius`/`SceneShadow`).
- [x] **P3 (bloquante)** — le panneau est une couche décorative **sœur**, pas une enveloppe (double cadre avec `CellFrame`/`NoDataCell`/`DsSkeleton`, ombre rognée par `ClipRect`) ; cellules jointives : retrait de 4 px, marge de 16 px conservée ; rayon 16 du contour ; glow « bouton armé » retiré.
- [x] **P4 (importante)** — familles nommées avec le préfixe de paquet, repli embarqué, mesure de l'encre des glyphes (la police mono ne change pas de largeur), `fontWeight` = `wght`, couverture des glyphes, capture réelle dans T10, noms de fichiers sans crochets.
- [x] **P5 (importante)** — table de tailles complète (hauteurs de ligne, interlettrage), table usage → style des 31 usages de `label`, capitales à l'affichage seulement, T12 scindé en T12a/T12b, acceptation 013 avant chaque commit concerné.
- [x] **P6 (importante)** — orbe et squelette sous `SceneMotionScope.loop`, durées en tokens, `RepaintBoundary` locaux, halo radial, grille en `drawPoints`, inventaire des `pumpAndSettle`.
- [x] **P7 (importante)** — T19 scindé en T19a/b/c ; `DsStatusChip.measure` ; `SceneBackdrop` dans la page ; rôles d'orbe figés dès T11/T12 ; `onNogo` retiré ; test d'architecture étendu ; T01 précise que U-01 et U-03 sont des garde-fous déjà verts.
- [x] **P8 (mineure)** — contraste par `Color.alphaBlend` sur les quatre fonds réels (seuil 4,5 pour les mots de statut) ; **écart consigné : `line-strong` vaut 2,30:1 sur `surface-100`, pas 3:1 comme l'affirme la source** (jamais seule frontière d'un bouton ni anneau de focus ; focus `signal`) ; URL de police épinglée sur un commit, SHA-256 dans `README.md`/`LICENSES.md` avec test.
- Ce qui tient (revue) : périmètre UI seulement respecté, aucune contradiction cachée avec une PDR acceptée, pas de collision bloquante des rôles, Q-86 déjà tranchée (pdr-0079), aucun golden à régénérer, `--unit` relance bien les paquets dépendants.

## Questions pour le porteur
Aucune bloquante. Q-91 tranchée (pdr-0083 D4). Le porteur juge le rendu à 24 px minimum sur la capture, en répétition.

## Contraintes laissées par T01 (à respecter en TDD)
- `label` et `button` restent distincts par taille, graisse, interligne ou interlettrage (le step de polices classe les textes par rôle de style) ; `value`, `data`, `label`, `verdict` = « données » ; `title`, `body`, `button`, `transcript` = « mots ».
- Le peintre du graphique reste `TrendChartPainter` avec les champs `series` (nom, couleur, `dashed`) et `thresholdColor` (le step U-06 les lit).
- Le step des licences lit `LicenseRegistry` : `registerSceneFontLicenses()` doit s'exécuter sur le chemin de lancement des tests (T10).
- Les tests d'animation lisent l'opacité (< 0,99 = pas encore visible) et la translation rendue de `surface-<id>`.
