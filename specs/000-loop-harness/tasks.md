# 000 — Tâches

Format : `- [ ] Txx <pile> — <tâche> · test d'abord : <test qui doit échouer>`.

## Gherkin
- [ ] T01 Flutter — `test/acceptance/loop_harness.feature` (H-01 à H-03) + génération bdd_widget_test · test d'abord : les trois scénarios échouent (app absente)

## TDD
- [ ] T10 Flutter — workspace pub racine, `apps/genesis_canvas` (Linux), versions exactes · test d'abord : test de widget « l'app démarre et affiche l'orbe » (H-01)
- [ ] T11 Flutter — `A2uiReplaySource` (lecture JSONL, délais, messages v0.9) · test d'abord : test unitaire sur une fixture de 3 lignes
- [ ] T12 Flutter — `CanvasBloc` + `CanvasBoard` (messages → `SurfaceController` → surface affichée) · test d'abord : bloc_test + test de widget (H-02)
- [ ] T13 Flutter — `SnapshotService` + configuration `GENESIS_SCENARIO` / `GENESIS_SNAPSHOT` injectée · test d'abord : test de widget qui vérifie qu'un PNG non vide est produit (H-03)
- [ ] T14 Flutter — fixture `act1-replay.jsonl` alignée sur `product/functional/dataset.md` · test d'abord : H-02 avec les valeurs du jeu

## Clôture
- [ ] T90 `gate.sh --full` vert
- [ ] T91 `app-smoke.sh` : capture ouverte et conforme (ou UNAVAILABLE noté)
- [ ] T92 Revue architect-reviewer + refactorisations ; `gate.sh --full` vert ; publication
