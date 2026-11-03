# 019 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/019-design-system-fidelity
- **Backlog** : EP-04, EP-01
- **Mis à jour** : 2026-11-03 10:45

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-11-03 | Définir | `spec.md`, `plan.md`, `tasks.md` (T01, T10 à T13, T20 à T24, T30 à T34, T40, T41, T90 à T92) ; détails d'interface tranchés sous pdr-0062 : [pdr-0088](../../product/decisions/pdr-0088-019-design-system-fidelity-ui-details-assistant-decided.md) (F1 à F11, contestables) ; hypothèse sur l'indicateur d'acte en rejeu : effet attendu du mode scénario (`_reachAct` sans effet en scénario et en rejeu), à confirmer par T40 ; `product_lint` : 0 erreur | `python3 -I product/_tools/product_lint.py` |
| 2026-11-03 | Revue du plan | `architect-reviewer` (Opus), mode PLAN : verdict **À AMENDER** (3 bloquantes, 4 importantes, 1 mineure) ; P1 à P8 intégrées dans `spec.md`, `plan.md`, `tasks.md` et [pdr-0088](../../product/decisions/pdr-0088-019-design-system-fidelity-ui-details-assistant-decided.md) (F1, F3, F4, F5, F8, F11 amendées ; F12, F13 ajoutées) ; **Q-94** ouverte (non bloquante) ; tâches réordonnées (T40 en tête, T10 scindée en a/b/c, T32 en a/b) ; `product_lint` : 0 erreur | `python3 -I product/_tools/product_lint.py` |
| 2026-11-03 | Gherkin | T01 : `acte_fidelite_design.feature` (V-01 à V-11, A-01 à A-07, I-01 ; 22 cas : **19 rouges pour la bonne raison, 3 verts** = I-01 tel quel) ; copie documentaire en trois fichiers (`design-system-019{,-ecran,-mouvement}.feature`, limite de 250 lignes du lint) ; U-01 retiré de 017 (remplacé par V-01), U-05 renvoie à A-01 pour le flou ; contrat de clés `FidelityKeysContract` (`support/keys.dart`). Rouges attendus : V-01 « taille du style data : attendu 15, obtenu 24.0 » ; V-02 `kpi-value` introuvable ; V-03 `trend-plot` introuvable ; V-04 `checklist-table` introuvable ; V-05 `reviews-split` introuvable ; V-06 `agents-rail-label` introuvable ; V-07 `voice-orb-core` introuvable ; V-08 aucun cadre de génération ; V-09 `actions-label` introuvable ; V-10 hauteur de `shelf-KeyIndicator` 31 au lieu de 30 ; V-11 échelle non appliquée ; A-01 flou σ 0 au lieu de 4 ; A-02 `checklist-row-0` ; A-03 `trend-reveal` ; A-04 `kpi-value` ; A-05 `generation-frame-crashes` ; A-06 `voice-wave` ; A-07 `kpi-gauge` introuvable | `.omc/state/loop/gates/20261103-104916-unit-flutter.log` (8 contrôles, tout vert, 382 tests) ; `python3 -I product/_tools/product_lint.py` : 0 erreur |
| 2026-11-03 | TDD | **T40 faite, sans code** : l'hypothèse est confirmée et déjà verrouillée par `genesis_canvas_page_act_test.dart` (7 tests verts : en mode scénario la surface `actions` ne touche pas l'acte ; pendant le rejeu elle ne l'avance pas) et par les 3 scénarios I-01 de l'acceptation (verts : « Acte 1/3 · Créer » en scénario, « Acte 4 · Rejeu » en rejeu réel, 1/3 → 2/3 → 3/3 en vivant). Pas de bogue. | `flutter test apps/genesis_canvas/test/pages/genesis_canvas_page_act_test.dart` (7 verts) ; `flutter test test/acceptance/acte_fidelite_design_test.dart --plain-name "I-01"` (3 verts) |
| 2026-11-03 | TDD | **T10a faite** : les 9 rôles de texte aux tailles du design system (body 15, label 11 à 0,14 em, title 18, data 15, transcript 20, button 15 ; value 76, verdict 28, actIndicator 28 inchangés), `scene_tokens.g.dart` régénéré (hash et parité verts) ; `scene_theme_scale_test` (rouge : 8 échecs « 24 au lieu de 15/11/18/20 »), `text_contrast_small_test`, garde `small_text_color_guard_test` (rouge : `trend_chart.dart:152` graduations en `inkFaint`, corrigé en `textSecondary`) ; ≥ 24 px recalés en « ≥ 11 » (plus petit style de l'échelle) dans ~25 tests unitaires et 3 scénarios (C6, F-02 de la CrashList, D-02 de 013) ; **conséquences directes de la taille recalées** (titres qui ne passent plus à la ligne, lignes de checklist de 45 à 36 px, cellules réduites de `review_sentiment_test`) : T22 et T23 retouchent ces tailles. **D-02 de 013 est rouge** (les 3 extraits d'avis tiennent en entier à 15 px dans 624×302, donc pas de « + N avis ») : T23 le recalcule. V-01 et V-11 de 019 passent au vert | `.omc/state/loop/gates/20261103-110456-unit-flutter.log` (17 contrôles, tout vert) |
| 2026-11-03 | TDD | **Suite d'acceptation complète après T10a** (hors porte `--unit`, pour détecter une régression comme en 017) : 119 verts, 18 rouges = **D-02 de 013** (attendu, T23) + 17 cas de 019 attendus (V-02 à V-10, A-01 à A-07 ; V-01, V-11 et I-01 verts) ; **aucune autre régression** (S-02, D-01, D-03 à D-07, R-01, RB-xx, U-02 à U-06 verts) | `flutter test test/acceptance` dans `apps/genesis_canvas` (sortie : scratchpad `acc-t10a.log`) |

## Revue d'architecte
### Revue du plan (mode PLAN) — verdict À AMENDER
- [x] **P1 bloquante** données du KPI et du graphique absentes des modèles : `parseFrPercent`, deltas « Tendance » / « vs comparaison » (pas de « vs seuil » : Q-94), série courante, franchissement strict (« dès J5 »), abscisse interpolée, en-tête de checklist neutre, fonctions pures (pdr-0088 F3, F4).
- [x] **P2 bloquante** `SceneMotionScope` ne couvre pas le pied ni le panneau du protocole ; cycle de vie des boucles : scope de scène, `SceneOneShot` (pas de `TweenAnimationBuilder`), phases de repos, hystérésis, tracé par clipper, test `transientCallbackCount == 0` (T12, T33, T34, F13).
- [x] **P3 bloquante** `DsRise` recréait le `State` de `Surface` : arbre constant `Opacity` > `Transform` > `ImageFiltered(enabled: t < 1)` (F5).
- [x] **P4 importante** tests cassés non cités (compteur en vivant, C6, F-02 de la CrashList, ~25 tests unitaires, D-05, D-04, U-05, `pumpAndSettle`) : listés dans `plan.md` et T01/T10a.
- [x] **P5 importante** `ink-faint` sous 4,5:1 pour du texte < 24 px : F12 et test de contraste (T10a).
- [x] **P6 importante** découpage : T40 en tête, T10 en a/b/c, jetons `scene.motion.*` en T12, T11 d'abord insensible à la casse, T41 via `_expectedBricks`.
- [x] **P7 importante** cadre de génération sans port : T32a (port, `CanvasBoard(generation: ValueListenable)`) puis T32b, F11.
- [x] **P8 mineure** I-01 confirmée par le code (état initial « Acte 1/3 » du mode scénario) et corrigée ; F1 contre F8 (`segment`) ; ids V-01 à V-11 ; étiquette du bandeau = `title` de `/actions` ; 5 autres états du rail ; registre : pdr-0087 `supersedes` pour un remplacement partiel, signalé sans contester.

### Revue du code
<!-- Verdict et R1…Rn ; cocher celles appliquées. -->

## Questions pour le porteur
Aucune bloquante. **Q-94** (non bloquante, avant J7) : afficher ou non un écart « vs seuil » calculé (le design system l'affiche, les données de l'app n'ont que `trend`, `threshold` et `comparison` ; retenu : pas de « vs seuil »). À observer en répétition : lisibilité au fond de la salle (NFR-05 suspendue, pdr-0087 D1) ; 60 i/s avec le flou de `gc-rise` et les boucles (pdr-0088 F5, F9).
