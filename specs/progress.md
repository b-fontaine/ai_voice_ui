# Avancement de la boucle

État global des fonctionnalités (`specs/NNN-<slug>/`). L'ordre vient de `product/roadmap/roadmap.md`. Journal : la ligne la plus récente en haut.

## Fonctionnalités
| NNN | Fonctionnalité | Backlog | Jalon | Étape | Mise à jour |
|---|---|---|---|---|---|
| 000 | Outillage de boucle dans l'app (squelette, mode capture, rejeu scripté) | EP-01 (socle) | J2 | Terminée, publiée (`b9db83c`) | 2026-10-29 |
| 001 | SP-03 : A2A en Go ↔ `genui_a2a` (spike) | EP-03 | J1 | Consigner | 2026-10-29 |

## Journal
| Date | Événement |
|---|---|
| 2026-10-29 | 001 (SP-03) : expérience terminée, résultat ✅ (`genui_a2a` 0.10.1 + agent `a2a-go` v2 via `a2acompat/a2av0` : surface rendue et action aller-retour, de bout en bout) ; reste à consigner (knowledge, spikes.md, Q-39). |
| 2026-10-29 | 001 (SP-03) : étape Définir faite (spec, plan, tâches) ; branche feat/001-sp-03-a2a-go-genui. |
| 2026-10-29 | 000 : publiée sur `origin/main` (`b9db83c`, `publish.sh` code 0, gate --full vert après fusion de `origin/main`). |
| 2026-10-29 | 000 : clôture — docs produit à jour (frontend.md, roadmap, backlog) ; fusion dans `loop` et publication par `publish.sh`. |
| 2026-10-29 | 000 : refactorisation terminée (R1 à R10, gate --full vert à `7a52729`) ; passage à la Vérification (gate + capture app-smoke). |
| 2026-10-29 | 000 : revue d'architecte rendue (1 bloquante, 5 importantes, 4 mineures) ; Q-66 ouverte (get_it/`app/di`, non bloquante) ; refactorisation en cours. |
| 2026-10-29 | 000 : TDD terminé (T01 à T14), gate --full vert ; passage à la Revue d'architecte. |
| 2026-10-29 | 000 : T13 faite (capture PNG, config, lecteur de scénario) ; H-01 à H-03 verts ; reste T14 (fixture alignée sur le jeu de données). |
| 2026-10-29 | 000 : T12 faite (`CanvasBloc` + `CanvasBoard`) ; `bloc_test` impossible (conflit analyzer), helper maison, note KB corrigée ; reste T13, T14. |
| 2026-10-29 | 000 : T11 faite (`A2uiReplaySource`) ; reste T12 à T14. |
| 2026-10-29 | 000 : T10 faite (H-01 vert) ; reste T11 à T14. |
| 2026-10-29 | 000 : Gherkin terminé (H-01 à H-03 rouges comme attendu, gate --unit vert) ; branche feat/000-loop-harness. |
| 2026-10-29 | Dispositif de boucle préparé ; boucle non lancée (en attente de validation du porteur). |
