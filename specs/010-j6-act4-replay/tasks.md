# 010 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Pile unique (Flutter) : **une tâche à la fois**. `product/`, `specs/`, `pubspec.yaml` racine : session principale seule.

## Gherkin (acceptation Flutter, `bdd_widget_test`)
- [ ] T01 Flutter — `acte4_rejouer.feature` : R-01 à R-08 sur le faux backend (acte 1 depuis les fixtures `act1-*`, horloge virtuelle du lecteur injectée, compteur de requêtes) · rouges pour la bonne raison : les commandes de la zone Rejeu sont inactives (`onPressed: null`), aucun journal

## TDD
- [ ] T02 Flutter — `entity_session` : `A2uiJournal`/`JournalEntry` (ajout, `t_ms` relatif au premier message, `seq`, JSONL aller-retour, lecture du format `{t_ms, message}` de 000) · test d'abord : `a2ui_journal_test.dart`
- [ ] T03 Flutter — nouvelle slice `packages/features/replay` (pubspec, workspace racine, `analysis_options`) et `ReplayPlayer` : lecture, pause, vitesses, plafond d'écart, seek (avant, arrière, réinjection après `clear`), fin, `dispose` sans minuteur actif ; horloge virtuelle injectée · test d'abord : `replay_player_test.dart` (durée ∝ 1/vitesse, seek arrière puis avant sans doublon)
- [ ] T04 Flutter — `ReplayRouter` (modes vivant / rejeu, enregistrement, jet des messages vivants en rejeu, abonné unique, pas de fermeture du gate à la fin du rejeu) · test d'abord : `replay_router_test.dart` (course message vivant / entrée en rejeu)
- [ ] T05 Flutter — **sonde** : test de widget sur genui 0.10.4 verrouillé : `deleteSurface` puis `createSurface` du même identifiant, rejoué avec le validateur remis à zéro, redonne le même rendu (surfaces de l'acte 1) · test d'abord : le test lui-même ; s'il échoue, consigner et appliquer le repli du plan
- [ ] T06 Flutter — `ReplayBloc` (états/événements scellés, `sequential`, dérivé du lecteur, `canPlay` faux sans journal ou agents occupés) · test d'abord : `replay_bloc_test.dart` (harnais `bloc_harness`)
- [ ] T07 Flutter — `ReplayBar` active (Lecture/Pause, Recommencer, curseur, cinq vitesses, Direct), libellés accessibles, cibles ≥ 48 px, texte ≥ 24 px, pas de débordement à 340 px et à la largeur retenue · test d'abord : `replay_bar_test.dart`
- [ ] T08 Flutter — `StageBar` : « Acte 4 · Rejeu » non cliquable en état Rejeu · test d'abord : `stage_bar_test.dart`
- [ ] T09 Flutter — câblage de `GenesisCanvasPage` : routeur sur la source vivante, journal, `ReplayBloc`, port `ReplayStage` (`enter`/`clear`/`emit`/`exit`), `startEnabled` et `CanvasActionScope.enabled` coupés en rejeu, relais de `anyBusy`, fermeture ordonnée, `_scenarioMode` pour l'ancien mode, réglage `replayMaxGap`, DI · test d'abord : `genesis_canvas_page_replay_test.dart` + R-01 à R-08 verts

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer (mode CODE) + refactorisations par lots
- [ ] T92 Vérification : `gate --full`, `app-smoke.sh` (capture lue) ; clôture : docs `product/` (replay.md → `validated` pour le journal et le lecteur, screen, business-rules, frontend-screen, backlog EP-07/EP-05, roadmap J6, requirements FR-09 livrée), note `knowledge/` si fait nouveau (genui : recréation de surface), `specs/progress.md`, `publish.sh`
