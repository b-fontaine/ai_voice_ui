# 003 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`.

## Gherkin (acceptation Go, build tag `acceptance`)
- [x] T01 Go — A1 : `POST /voice/sessions` avec fournisseur simulé, aucune clé dans les sorties · test d'abord : le serveur n'existe pas (échec de compilation du test)
- [x] T02 Go — A2 : le WSS `/app` reçoit `orb.level` (~5 Hz) et les transcripts d'un sideband simulé · test d'abord : idem
- [x] T03 Go — A3 : configuration injectée, refus d'une adresse non loopback · test d'abord : idem

## TDD
- [x] T10 Go — `go.mod` (Go 1.27.3) + `Config` depuis l'environnement, `String()` sans secret · test d'abord : `TestConfigFromEnv`
- [x] T11 Go — niveau : RMS PCM16 24 kHz par bloc, agrégation 5 Hz, bornes 0..1 · test d'abord : `TestRMS`, `TestFiveHz`
- [x] T12 Go — ports + service `voice.Open` (offre → answer, sideband attaché, `Close` propre avec délai de garde) · test d'abord : `TestOpenAttachesSideband`, `TestCloseWaitsClosed`
- [x] T13 Go — adaptateur `openailive` (httptest rejouant des trames de SP-02) · test d'abord : `TestCreateSessionContract`, `TestSidebandEvents`
- [x] T14 Go — hub WSS `wsapp` (enveloppe v1, diffusion par session) · test d'abord : `TestHubBroadcast`
- [x] T15 Go — journal JSONL horodaté `jsonljournal` · test d'abord : `TestJournalLine`
- [x] T16 Go — `httpapi` (routes, limite de débit, `/healthz`) et `cmd/orchestrator` · test d'abord : `TestRateLimit`, `TestHealthz`
- [x] T17 Infra — `backend/Dockerfile`, `docker-compose.yaml`, `.github/workflows/ci.yaml` minimal · test d'abord : `docker compose config` en échec (fichier absent)

## Clôture
- [x] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Vérification : essai réel unique (budget), `docker compose config` ; clôture, fusion, `publish.sh`
