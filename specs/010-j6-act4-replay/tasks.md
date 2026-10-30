# 010 — Tâches

Ordre amendé par la revue du plan (A1 à A8, `plan.md`, bloc « Amendements », prioritaire).

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Pile unique (Flutter) : **une tâche à la fois**. `product/`, `specs/`, `pubspec.yaml` racine, `workspace_dependency_rules_test.dart` : session principale seule.

## Sonde et socle
- [x] T05 Flutter — **sonde genui 0.10.4** : `deleteSurface` puis `createSurface` du même identifiant, validateur remis à zéro, redonne le même rendu (surfaces de l'acte 1) · test d'abord : le test lui-même ; **s'il échoue : fonctionnalité Bloquée, Q-xx pour le porteur** (pas de repli)
- [x] T03a session principale — workspace racine, `packages/features/replay/pubspec.yaml`, dépendance `feature_replay` dans `apps/genesis_canvas/pubspec.yaml`, ajout à `workspace_dependency_rules_test.dart` · test d'abord : le test de règles de dépendances
- [x] T11 Flutter — `testing/backend_fakes` : compteur de **toutes** les requêtes HTTP du `FakeBackend` (aujourd'hui seulement `canvasResets`) · test d'abord : `fake_backend_test.dart`
- [x] T12 Flutter — `GenesisApp` : paramètre `clock` (frontière « temps ») vers `AppClock` de la DI · test d'abord : une app lancée avec une horloge fausse l'utilise
- [x] T13 Flutter — `feature_protocol_feed` : `ProtocolFeedEntriesCleared` (vide les entrées, garde `expanded`) · test d'abord : `protocol_feed_bloc_test.dart`

## Gherkin (acceptation Flutter, `bdd_widget_test`)
- [x] T01 Flutter — `acte4_rejouer.feature` : R-01 à R-09 (R-09 : « Remettre à vide » pendant un rejeu = Direct), démontage de la page pendant une lecture sans minuteur actif, curseur glissé = un seul seek ; acte 1 depuis les fixtures, `pump(durée)`, compteur de requêtes (T11) · rouges pour la bonne raison : commandes de la zone Rejeu inactives (`onPressed: null`), aucun journal ; `loop_harness.feature` : capture à `GENESIS_REPLAY_AT` (A3)

## TDD
- [x] T02 Flutter — `entity_session` : `A2uiJournal`/`JournalEntry` (copie profonde non modifiable, `t_ms` relatif au premier message et croissant, `seq`, plafond `maxEntries`, `toString` sans contenu) · test d'abord : `a2ui_journal_test.dart`
- [x] T03b Flutter — `ReplayPlayer` (`feature_replay`) : pas fixe `Timer.periodic`, vitesses, pause, plafond d'écart, seek avec barrière d'un tour de boucle, fin, `dispose` synchrone sans minuteur actif · test d'abord : `replay_player_test.dart` (durée ∝ 1/vitesse, seek arrière puis avant sans doublon)
- [x] T04 Flutter — `ReplayRouter` (sortie `sync: true`, modes vivant / rejeu, `enterReplay()` atomique avec copie figée, `inject`, jet et **comptage** des messages vivants en rejeu, `journalSize`, `liveDone`, pas de fermeture du gate à la fin du rejeu) · test d'abord : `replay_router_test.dart` (message vivant dans la même pile que `enterReplay()` ni rendu ni enregistré)
- [x] T06 Flutter — `ReplayBloc(router, player, stage)` (deux handlers : commandes `sequential`, abonnement au lecteur `restartable` ; `canPlay` combiné ; Direct = `player.stop` → `stage.exit` → `router.exitReplay`) · test d'abord : `replay_bloc_test.dart` (Pause traitée pendant une lecture)
- [x] T07 Flutter — `ReplayBar` à 480 px : deux rangées de 48 px, Lecture/Pause, Recommencer, `Slider` (seek sur `onChangeEnd`, `onChanged` = affichage seul), cinq vitesses, Direct ; libellés accessibles, texte ≥ 24 px · test d'abord : `replay_bar_test.dart` (aucun débordement, un seek par glisser)
- [x] T08 Flutter — `StageBar` : « Acte 4 · Rejeu » non cliquable en rejeu ; « Remettre à vide » = `ReplayDirectPressed` en rejeu · test d'abord : `stage_bar_test.dart`

## Câblage de la page
- [x] T09a Flutter — routeur sur la source vivante, journal, renommage `_replayMode` → `_scenarioMode`, aucun changement visible · test d'abord : actes 1 à 3 et `loop_harness` restent verts (régression), `genesis_canvas_page_replay_test.dart` (enregistrement)
- [x] T09b Flutter — `ReplayBloc`, `ReplayStage` (`clear`/`exit`), barrière, fermeture ordonnée (lecteur synchrone dans `dispose`), `genesis_canvas_page_layout_test.dart` (étagère 900 px, zone Rejeu 480 px, 1920 × 1080) · R-01 à R-04 et R-08 verts
- [x] T09c Flutter — isolation (`startEnabled`, `CanvasActionScope.enabled` coupés en rejeu), relais booléen `ReplayBusyChanged`, Direct, remise à vide en rejeu, ligne `errorSink` du nombre de messages écartés · R-05 à R-07 et R-09 verts
- [x] T09d Flutter — `replayMaxGap`, `replayJournalMaxEntries`, `tick`, `defaultSpeed` dans `GenesisCanvasPageSettings`/`GenesisConfig` (tests de réglages), `GENESIS_REPLAY_AT` et capture sur `liveDone` (A3) · test d'abord : `genesis_config_test.dart`, `loop_harness.feature`

## Clôture
- [x] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer (mode CODE) + refactorisations par lots
- [ ] T92 Vérification : `gate --full`, `GENESIS_REPLAY_AT=0.5 app-smoke.sh` (capture lue) ; clôture : docs `product/` (screen budget, business-rules, frontend-screen, backlog EP-07/EP-05, roadmap J6, requirements FR-09 livrée), note `knowledge/` si fait nouveau, `specs/progress.md`, `publish.sh`
