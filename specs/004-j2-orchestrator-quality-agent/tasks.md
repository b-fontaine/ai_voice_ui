# 004 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Toutes les tâches Go : une seule à la fois (même pile).

## Gherkin (acceptation Go, build tag `acceptance`)
- [x] T01 Go — B1 : une phrase → une surface
- [x] T02 Go — B2 : agent injoignable / en erreur → échec honnête, session ouverte
- [x] T03 Go — B3 : A2UI invalide de l'agent → rejeté, jamais relayé
- [x] B4 Go (module agent) — carte + flux KPI + hors périmètre refusé
- [x] T04 Go — compléments issus de la revue du plan : **B3bis** (`createSurface` valide puis `updateComponents` invalide → `a2ui createSurface`, `a2ui deleteSurface{quality}` émis par l'orchestrateur, `agent.activity failed`, commentaire d'échec sans « 99,57 »), **B5** (`DELETE` pendant la barrière de l'agent → 204, contexte de l'exécuteur annulé ou `CancelTask` reçu, aucun `a2ui` après `closed`, aucun `AppendCommentary` après `Close`), **B6** (agent bloqué au-delà de `AGENT_TIMEOUT=1s` → `failed` « délai dépassé », commentaire d'échec, annulation reçue ; `startDelegatingApp` accepte des surcharges d'environnement) ; B1 renforcé (attribution `agent`/`task` dans l'enveloppe `a2ui`, `working` publié à la réception de `submitted`, `label`) · test d'abord : rouge attendu pour les mêmes causes (symboles / comportement absents)

## TDD
- [x] T10 Go — domaine et ports (`a2ui`, `agent.activity`, `EventDelegationCreated`, `RemoteAgent` en canal, `Append*`) — à amender en T11/T14 (A8 : retirer `AppendThinking` ; A10 : `iter.Seq2`, `TaskID`, `UpdateSubmitted`)
- [x] T11 Go — `openailive` (A8) : `delegation.created` avec `offset_ms`, `AppendCommentary` avec acquittement, `event_id`, erreur sans retry, rejet > 1 000 runes, suppression de `AppendThinking` et de l'échafaudage · test d'abord : `TestTranslateDelegationCreated`, `TestAppendCommentaryWaitsAck`, `TestAppendCommentaryErrorEvent`, `TestAppendAfterClosedFails`
- [x] T12a Go — validateur A2UI sans état (A3) · test d'abord : `TestValidateRejects…` (table), `TestValidateAcceptsReplayAct1`, `TestValidateAcceptsProgressiveChildren`
- [x] T12b Go — registre de surfaces par session et contrôle de fin de tâche (A3) · test d'abord : `TestRegistry…`, `TestCompletionRequiresRootAndResolvedRefs`
- [x] T13a Go (module agent) — jeu de données brut embarqué + KPI pondéré + port `Composer` (A11) · test d'abord : `TestKpiComputedFromRows`, `TestDatasetMatchesProductSheet`, `TestScopeTable`
- [x] T13b Go (module agent) — serveur A2A natif, carte, mémoire par contexte, durcissement HTTP, `/agent healthcheck` (A11) · test d'abord : `TestSecondRequestSameContextUpdatesInPlace`, `TestOversizedBodyRejected`, `TestWrongHostRejected` + B4
- [x] T14 Go — adaptateur `a2aclient` et port `RemoteAgent` en `iter.Seq2` (A10) · test d'abord : `TestSendMapsStates`, `TestCancelOnContextSendsCancelTask`, `TestCardInterfaceOriginMismatchRejected`, `TestFileSchemeRejected`
- [x] T15a Go — fenêtre de transcript et reconstruction de la demande (A9) · test d'abord : `TestRequestRebuiltFromTranscript` (table)
- [x] T15b Go — file par session, doublons, annulation, délai, fermeture ordonnée (A1, A2, A6) · test d'abord : `TestSecondDelegationQueuedThenServed`, `TestQueueFullHonestCommentary`, `TestDuplicateDelegationIgnored`, `TestAgentTimeoutCancelsAndFails`, `TestCloseCancelsInflightDelegation`
- [ ] T15c Go — pipeline : générique, carte, `submitted`/`working`, validation et relais, compensation, commentaire final borné et nettoyé (A5, A7, A8) · test d'abord : `TestOrchestrateHappyPath`, `TestAgentFails`, `TestPartialStreamCompensated`, `TestGenericBeforeFinalEvenIfAgentFaster`, `TestFinalCommentaryBoundedAndSanitized`, `TestActivityPublishedOnSubmitted`
- [ ] T15d Go — branchement dans `voice.supervise` (port `Delegations`, `Close` avant `closed`, non bloquant) (A1) · test d'abord : `TestSuperviseForwardsDelegationWithoutBlocking`, `TestAppCloseWaitsDelegations`
- [ ] T15e Go — rétention séparée du hub pour `a2ui`/`agent.activity` (A4) et attribution `agent`/`task` de l'enveloppe (A7) · test d'abord : `TestLateSubscriberGetsSurfaceAfterManyTranscripts`, `TestWireA2UIAttribution`
- [ ] T16 Go — `bootstrap` : configuration (`AGENTS`, `A2UI_CATALOG_ID`, `A2UI_COMPONENTS`, `AGENT_TIMEOUT`, `VOICE_APPEND_ACK_TIMEOUT`, `VOICE_ACK_DELAY_MS`, fichier de phrases), ordre de `App.Close` · test d'abord : cas de config, `TestNewWiresOrchestrator`
- [ ] T17 Infra — Dockerfile de l'agent, compose (réseau interne, healthcheck, durcissement), CI en matrice, instructions vocales · test d'abord : script de contrôle du `docker compose config --format json` (échoue avant)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer (mode CODE) + refactorisations (par lots)
- [ ] T92 Vérification : essai réel unique (budget), clôture, fusion, `publish.sh`, `fresh_session`
