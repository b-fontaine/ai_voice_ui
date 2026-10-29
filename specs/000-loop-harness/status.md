# 000 — État

- **Étape** : Revue
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
| 2026-10-29 | TDD | T13 : `SnapshotService` (`shared_core`, devenu package Flutter), `GenesisConfig.fromEnvironment`, `ScenarioPlayer` (asset `assets/replays/<scénario>.jsonl`, `loadString(cache:false)`), page câblée (capture après 2 frames puis `exitHandler`), fixture `act1-replay.jsonl` v1 (3 messages, `t_ms` 0/50/100 — écarts < 100 ms pour `pumpAndSettle`, à garder en T14). Rouge : `SnapshotService`/`GenesisConfig` introuvables. Step « PNG non vide » : attente en temps réel (`tester.runAsync`, jusqu'à 5 s) car `toImage` ne s'achève pas sous la fausse horloge ; assertions inchangées. Acceptation : 3/3 vert sur 3 lancements (H-02 vert aussi). | `.omc/state/loop/gates/20261029-135954-unit-flutter.log` (VERT) |
| 2026-10-29 | TDD | T14 : aucune modification de code — la fixture `act1-replay.jsonl` de T13 porte déjà les valeurs du jeu (`product/functional/dataset.md` : « Sessions sans crash », global 7 j 99,57 %) et H-02 passe avec elles. Fin du TDD : toutes les tâches de la section TDD cochées, `gate.sh --full` vert sur arbre propre (acceptation H-01 à H-03 comprise). | `.omc/state/loop/gates/20261029-140218-full.log` (VERT, arbre propre) |

## Revue d'architecte

## Questions pour le porteur
