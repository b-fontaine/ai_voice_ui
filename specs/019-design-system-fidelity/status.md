# 019 — État

- **Étape** : Gherkin
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
