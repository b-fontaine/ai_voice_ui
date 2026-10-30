# 006 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Toutes les tâches sont Go (une seule à la fois, même pile).

## Gherkin (acceptation Go, build tag `acceptance`)
- [ ] T01 Go — G1 : « Prépare la release 3.4 » → trois agents en parallèle, quatre surfaces (`kpi`, `trend`, `reviews`, `checklist`), trois `agent.activity` `working` puis `completed`, ordre trois temps par surface, attribution `agent`/`task`, commentaire fondé sur les vrais résultats (« 99,57 % », « 24 % ») ; **G1bis** : « Montre-moi les avis » → une seule surface, aucun `failed`
- [ ] T02 Go — G2 : demande hors catalogue → aucun `createSurface`, refus de chaque agent, commentaire vocal avec alternative (RG-08)
- [ ] T03 Go — G3 : agent Livraison injoignable → trois surfaces conservées, `agent.activity failed` pour lui seul, pas de surface `checklist`, session ouverte
- [ ] T04 Go (module agents) — G4 : carte + flux + refus pour chacun des trois agents (lancés dans le test) · test d'abord : rouge pour symboles absents / comportement absent

## TDD
- [ ] T10 Go — **Déplacement pur** `backend/agents/quality` → `backend/agents` (`internal/kit` générique, `cmd/agent-quality`), Dockerfile paramétré, compose, CI et `check-compose.sh` mis à jour ; les tests de 004 (agent, mémoire, durcissement, B4) passent **sans changement d'assertion** · test d'abord : `go build ./...` et B4 rouges tant que les chemins ne sont pas migrés
- [ ] T11 Go — `internal/dataset` : avis, changelog, séries quotidiennes, statuts de critère, recommandation, formats ; G5 · test d'abord : `TestDatasetMatchesProductSheet` (99,57 % ; 99,80 % ; 99,43 % ; 1 164 ; 24 % ; 37 PR ; statuts ; À RISQUE), `TestReviewsFromRows`, `TestChecklistStatusMargins` (table)
- [ ] T12 Go — Qualité : `KeyIndicator` + `TrendChart` (deux surfaces, trois temps), portée en table · test d'abord : `TestQualityScopeTable`, `TestQualityMessagesThreeTimes`, `TestQualityDataModelShapes`
- [ ] T13 Go — Voix du client : `ReviewSentiment` (3 extraits), portée · test d'abord : `TestVoiceScopeTable`, `TestReviewSentimentShape`, `TestExcerptsAreThreeAndFromDataset`
- [ ] T14 Go — Livraison : `ReleaseChecklist` (3 critères, recommandation), portée · test d'abord : `TestDeliveryScopeTable`, `TestChecklistTwoAtRiskOneValidated`, `TestRecommendationAtRisk`
- [ ] T15 Go — orchestrateur : configuration compose (6 noms, trois cartes), `failure_rejected` avec alternative, refus partiel ≠ échec · test d'abord : `TestPartialRejectionIsNotFailure`, `TestAllRejectedSaysAlternative`, `TestValidatorRejectsColumnInGenesisCatalog`
- [ ] T16 Infra — compose (`agent-voice`, `agent-delivery`, réseau interne, durcissement), `check-compose.sh`, CI · test d'abord : script de contrôle du `docker compose config --format json` (échoue avant)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer (mode CODE) + refactorisations (par lots)
- [ ] T92 Vérification (journal : délais NFR-02/03 ; essai réel unique si budget), clôture (docs `product/`), fusion, `publish.sh`, `fresh_session`
