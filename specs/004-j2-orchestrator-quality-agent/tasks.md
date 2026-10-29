# 004 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`.

## Gherkin (acceptation Go, build tag `acceptance`)
- [x] T01 Go — B1 : une phrase → une surface, avec un serveur A2A de test, Live simulé (`delegation.created`) · test d'abord : le paquet d'orchestration n'existe pas (échec de compilation)
- [x] T02 Go — B2 : agent injoignable / en erreur → échec honnête, session ouverte · test d'abord : idem
- [x] T03 Go — B3 : A2UI invalide de l'agent → rejeté, jamais relayé · test d'abord : idem
- [x] B4 Go — l'agent Qualité (module `backend/agents/quality`) : carte, flux A2UI + résumé, requête hors périmètre refusée · test d'abord : le paquet `internal/agent` n'existe pas (échec de compilation)

## TDD
- [ ] T10 Go — domaine et ports : `a2ui`, `agent.activity`, `EventDelegationCreated`, `AppendCommentary` / `AppendThinking`, `RemoteAgent` · test d'abord : `TestWireA2UIAndActivity`
- [ ] T11 Go — `openailive` : `delegation.created`, `commentary.append` / `thinking.append` (`event_id` unique, ≤ 500 tokens) · test d'abord : `TestTranslateDelegationCreated`, `TestAppendCommentary`
- [ ] T12 Go — validateur A2UI v0.9 · test d'abord : `TestValidateRejects…` (table), `TestValidateAcceptsReplayAct1`
- [ ] T13 Go — module `backend/agents/quality` : jeu figé, exécuteur déterministe, serveur A2A natif + carte · test d'abord : `TestExecutorProducesKpiSurface`, `TestAgentCard`, test de bout en bout contre un client `a2a-go`
- [ ] T14 Go — adaptateur `a2aclient` (carte, flux, parts `data` → messages A2UI, résumé texte, délai d'attente, erreurs) · test d'abord : contre un serveur A2A de test
- [ ] T15 Go — service `orchestrate` (reconstruction de la demande, plan, parallélisme, validation, diffusion, commentaire générique puis vrai résumé, échec honnête, révision) · test d'abord : `TestOrchestrateHappyPath`, `TestAgentFails`, `TestInvalidA2UIRejected`, `TestRequestRebuiltFromTranscript`
- [ ] T16 Go — câblage `bootstrap` + configuration (`AGENTS`, `A2UI_CATALOG_ID`, `AGENT_TIMEOUT`) · test d'abord : cas de config, `TestNewWiresOrchestrator`
- [ ] T17 Infra — Dockerfile de l'agent, service dans le compose, CI étendue, instructions vocales qui demandent la délégation · test d'abord : `docker compose config -q` en échec avant

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Vérification : essai réel unique (budget), clôture, fusion, `publish.sh`
