# Avancement de la boucle

État global des fonctionnalités (`specs/NNN-<slug>/`). L'ordre vient de `product/roadmap/roadmap.md`. Journal : la ligne la plus récente en haut.

## Fonctionnalités
| NNN | Fonctionnalité | Backlog | Jalon | Étape | Mise à jour |
|---|---|---|---|---|---|
| 000 | Outillage de boucle dans l'app (squelette, mode capture, rejeu scripté) | EP-01 (socle) | J2 | Vérification | 2026-10-29 |

## Journal
| Date | Événement |
|---|---|
| 2026-10-29 | 000 : refactorisation terminée (R1 à R10, gate --full vert à `7a52729`) ; passage à la Vérification (gate + capture app-smoke). |
| 2026-10-29 | 000 : revue d'architecte rendue (1 bloquante, 5 importantes, 4 mineures) ; Q-66 ouverte (get_it/`app/di`, non bloquante) ; refactorisation en cours. |
| 2026-10-29 | 000 : TDD terminé (T01 à T14), gate --full vert ; passage à la Revue d'architecte. |
| 2026-10-29 | 000 : T13 faite (capture PNG, config, lecteur de scénario) ; H-01 à H-03 verts ; reste T14 (fixture alignée sur le jeu de données). |
| 2026-10-29 | 000 : T12 faite (`CanvasBloc` + `CanvasBoard`) ; `bloc_test` impossible (conflit analyzer), helper maison, note KB corrigée ; reste T13, T14. |
| 2026-10-29 | 000 : T11 faite (`A2uiReplaySource`) ; reste T12 à T14. |
| 2026-10-29 | 000 : T10 faite (H-01 vert) ; reste T11 à T14. |
| 2026-10-29 | 000 : Gherkin terminé (H-01 à H-03 rouges comme attendu, gate --unit vert) ; branche feat/000-loop-harness. |
| 2026-10-29 | Dispositif de boucle préparé ; boucle non lancée (en attente de validation du porteur). |
