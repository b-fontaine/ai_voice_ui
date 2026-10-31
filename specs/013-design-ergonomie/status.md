# 013 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/013-design-ergonomie
- **Backlog** : EP-04, EP-01
- **Mis à jour** : 2026-10-31

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md` (3 lots A/B/C, D-01 à D-07), `plan.md`, `tasks.md` (T01-T34 + clôture), [pdr-0075](../../product/decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md) acceptée (délégation pdr-0062) ; constats tirés des captures 1920×1080 `act1-replay` et `crashlist-replay` de 012 (`.omc/state/loop/snapshots/20261031-005526-act1-replay.png`, `…005647-crashlist-replay.png`) ; `product_lint.py` : 0 erreur | commit de l'étape |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER**, 8 amendements P1 à P8 tous intégrés dans `spec.md`, `plan.md`, `tasks.md`, pdr-0075 ; Q-85 créée (`open-questions.md`, `roadmap.md` J7) ; `product_lint.py` : 0 erreur | commit de l'étape |

## Revue d'architecte
### Revue du plan (2026-10-31) — verdict : À AMENDER (tous intégrés)
- [x] **P1 bloquant** Widgetbook : `apps/genesis_widgetbook/` (couche app) et non sous `shared/design_system` (règle d'import `shared/*` → `feature_*`) ; « paquet isolé » faux (résolution pub unique, `verify.sh` y lance `build_runner`/`format`/`analyze`) → T32a d'abord, coupe C2 sinon ; hôte `SurfaceController` alimenté par les exemples du contrat ; test d'ensemble des composants (T33). pdr-0075 D4 corrigée.
- [x] **P2 bloquant** Lisibilité : tests en polices réelles (T03, `paragraphsTruncated`), `measureTextHeight` et capacité de checklist à hauteurs variables ; avis = extraits entiers puis « + N avis » ; étagère en deux rangées de trois, état par icône + `Semantics` ; T12 scindée (T12a, T12b).
- [x] **P3** Rail : tuile « état · tâche », « AGENTS A2A » en colonne de tête, pas de « CANEVAS » ni « release-3-4 » ; RG-29 ; liaison animée → Q-85 (porteur), intervalle libre.
- [x] **P4** D-01 et D-07 réécrits en mesures vérifiables ; 1366×768 retiré ; pas de `LayoutBuilder` ; 676 = 2 × 302 + 72 ; tests calés sur l'ancien budget listés (T11).
- [x] **P5** Apparition : `SceneMotionScope`, jamais de `TickerMode` ; `_SurfaceAppearance` (un contrôleur) ; fondu des données seulement « sans données » → « données » ; 400 ms de `_DecisionStatus` via `SceneMotion` ; quatre tests à mettre à jour (T21c).
- [x] **P6** NFR-04 : cellules sélectives (`BlocSelector` par surface), surbrillance en `ValueListenable`, test de périmètre de reconstruction et de peinture ; T21 scindée (T21a, T21b, T21c).
- [x] **P7** Régie : tests sous `TargetPlatform.linux`, contrôles empilés de largeur égale à 48 px ; panneau : entrées selon la hauteur disponible ; T31 supprimée (déjà couvert, paires nouvelles dans T14/T15).
- [x] **P8** Tokens : constantes `SceneTokens` (un seul `ThemeExtension`), hash sha256 en en-tête + test, `dart format` et `--ignore-scripts` ; T30 scindée (T30a, T30b).
- **Conflits avec une décision (remontés)** : écarts à adr-0005 (constantes, pas de Node en porte) consignés dans pdr-0075 D4 ; liaison animée → Q-85.

## Questions pour le porteur
Aucune bloquante. **Q-85** (liaison animée de délégation du rail, mise en scène) : ouverte, hors périmètre de 013 tant que non tranchée. Q-83 traitée par pdr-0075 D2 (à clore à la clôture). Détails d'interface tranchés par la boucle (contestables) : rail horizontal de 96 px plutôt que colonne de la maquette, ordre A → B → C avec coupe possible du lot C.
