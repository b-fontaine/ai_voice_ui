# 000 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/000-loop-harness (créée 2026-10-29)
- **Backlog** : EP-01
- **Mis à jour** : 2026-10-29

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | spec, plan et tâches rédigés par l'assistant lors de la préparation du dispositif | — |
| 2026-10-29 | Gherkin | T01 : H-01 à H-03 automatisés (bdd_widget_test) + coque `lib/main.dart` vide. Rouge attendu (`flutter test test/acceptance`, +0 -3) : H-01 « Found 0 widgets with key canvas-board », H-02 « Found 0 widgets with type Surface », H-03 « PNG absent ». Contrats posés : clés `canvas-board`/`voice-orb`, `Surface` genui, valeur `99,57`, `exitHandler(0)`. Titres de scénario ≤ 39 car. (format bdd_widget_test). | `.omc/state/loop/gates/20261029-132939-unit-flutter.log` (VERT) |
| 2026-10-29 | TDD | T10 : app_test.dart (rouge : coque `SizedBox.shrink`, clés introuvables) puis vert ; slices `app`, `pages/genesis_canvas`, `widgets/top_bar` (orbe `voice-orb`), `widgets/canvas_board` (`canvas-board`). H-01 passe ; H-02 (Surface) et H-03 (PNG absent) restent rouges. get_it/injectable reportés à T12/T13. | `.omc/state/loop/gates/20261029-133340-unit-flutter.log` (VERT) |
| 2026-10-29 | TDD | T11 : `A2uiReplaySource` (`packages/shared/core`, Dart pur, lignes `Stream<String>` + `delay` injecté, 8 tests : ordre, délais relatifs, lignes vides, erreurs JSON/version/t_ms manquant/décroissant/message absent). Rouge : « Error when reading 'lib/shared_core.dart': No such file or directory ». Acceptation inchangée (H-01 vert, H-02/H-03 rouges). | `.omc/state/loop/gates/20261029-133817-unit-flutter.log` (VERT) |
| 2026-10-29 | TDD | T12 : package `feature_canvas` (`packages/features/canvas`) : `CanvasBloc` (un seul `on<CanvasEvent>` `sequential`, events/états `sealed` écrits à la main, `A2uiMessageReceived` ajouté aux events de frontend.md), `CanvasBoard` (Row de `Surface`), page de l'app qui crée `SurfaceController` + Bloc. 11 tests (8 Bloc, 3 widget). Rouge : « Error when reading 'lib/api/canvas.dart': No such file or directory ». H-01 vert, H-02/H-03 rouges (câblage scénario/fixture = T13/T14). **Décision contrainte** : `bloc_test` inutilisable (conflit `analyzer` avec `build_runner` 2.16.2, requis par bdd_widget_test ; versions figées NFR-10) → helper `statesAfter` ; fait consigné dans `test-bloc-test`. | `.omc/state/loop/gates/20261029-134720-unit-flutter.log` (VERT) |

## Revue d'architecte

## Questions pour le porteur
