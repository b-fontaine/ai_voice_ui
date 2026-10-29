# 004 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : `backend/orchestrator/internal/{domain/message.go,port/port.go,port/agent.go,adapter/wire/wire.go,adapter/wire/wire_test.go,adapter/openailive/sideband.go,adapter/openailive/provider_test.go,app/voice/service_test.go,bootstrap/app_test.go}`, `plan.md`, `tasks.md`
- **Branche** : feat/004-j2-orchestrator-quality-agent
- **Backlog** : EP-03, EP-02
- **Mis à jour** : 2026-10-29 20:10

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés | — |
| 2026-10-29 | Gherkin | T01-T03 + B4 : scénarios B1-B4 écrits ; rouge attendu : orchestrateur `undefined: port.EventDelegationCreated`, `unknown field DelegationID in struct literal of type port.LiveEvent` ; agent `no required module provides package …/quality/internal/agent` ; testé contre des implémentations temporaires hors dépôt (B4 vert, harnais A2A validé) | `.omc/state/loop/gates/20261029-201544-unit-go.log` (vert) |
| 2026-10-29 | TDD T10 | domaine `a2ui`/`agent.activity`, ports `EventDelegationCreated`, `AppendCommentary`/`AppendThinking`, `RemoteAgent` ; rouge (`undefined: domain.A2UI`, `sb.AppendCommentary undefined`) puis vert ; `go vet -tags acceptance` compile désormais | `.omc/state/loop/gates/20261029-202100-unit-go.log` (vert) |
| 2026-10-29 | Revue du plan | architect-reviewer (mode PLAN) : CONFORME SOUS RÉSERVE, A1-A13 intégrés dans plan.md et tasks.md ; skill dev-loop mis à jour par le porteur (revue du plan, lots, étapes enchaînées, conversation neuve) | — |
| 2026-10-29 | Gherkin T04 | compléments B1 renforcé, B3bis, B5, B6, B7 écrits ; rouge attendu : `unknown field OffsetMs in struct literal of type port.LiveEvent` (symbole A9 absent) ; contre l'ajout temporaire hors dépôt du champ, B1-B3bis, B5-B7 échouent pour comportement absent (aucune enveloppe `agent.activity` reçue) et A1-A4 restent verts | `.omc/state/loop/gates/20261029-203756-unit-go.log` (vert) |
| 2026-10-29 | TDD T11 | `openailive` : `delegation.created` + `offset_ms`, `AppendCommentary` acquitté (A8), `AppendThinking` retiré ; rouge (`unknown field AppendAckTimeout`, `e.OffsetMs undefined`) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-204406-unit-go.log` (vert) |
| 2026-10-29 | TDD T12a | paquet `app/a2ui` : `Validator` sans état (A3) ; rouge (paquet sans fichier non-test, puis `declared and not used` corrigé) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-204658-unit-go.log` (vert) |
| 2026-10-29 | TDD T12b | `Registry` par session (A3 avec état), `Complete`, `Compensation`, `Forget` ; rouge (`undefined: a2ui.Registry`) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-204830-unit-go.log` (vert) |
| 2026-10-29 | TDD T13a | module agent : `internal/dataset` (lignes brutes embarquées, KPI pondéré 99,57 %, statut dérivé) et `internal/compose` (port `Composer`, `KpiComposer`, périmètre, mémoire bornée) ; rouge (`no non-test Go files in internal/dataset`, `…/compose`) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-205128-unit-go.log` (vert) |
| 2026-10-29 | TDD T13b | `internal/agent` (carte, exécuteur `submitted`→`working`→artefact→`completed`, `rejected` hors périmètre, annulation, 64 Kio, contrôle `Host`, `/healthz`, `SettingsFromEnv`, `Run`) et `cmd/agent-quality` ; rouge (`no non-test Go files in internal/agent`), puis un échec du message de refus (« supportée » au lieu de « supporté ») corrigé ; B4 vert, `-race -count=3` | `.omc/state/loop/gates/20261029-205435-unit-go.log` (vert) |
| 2026-10-29 | TDD T14 | port `RemoteAgent` en `iter.Seq2` (A10), `AgentError`, `AgentCard.Label` ; paquet `adapter/a2aclient` (carte relue, origine vérifiée, mapping des états, `CancelTask`, `Destroy`) ; rouge (`no non-test Go files in …/a2aclient`), puis un test « flux sans état final » corrigé (le serveur gardait le flux ouvert : fermeture propre simulée), vert `-race -count=3` | `.omc/state/loop/gates/20261029-210120-unit-go.log` (vert) |
| 2026-10-29 | TDD T15a | `orchestrate.RequestWindow` (A9) ; rouge (`undefined: NewRequestWindow`) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-210509-unit-go.log` (vert) |
| 2026-10-29 | TDD T15b | `port.Delegations`/`SessionDelegations`/`VoiceReply` et `orchestrate.Manager` (file, doublons, délai, fermeture bornée) ; rouge (`undefined: Phrases`, `Delegation`, …) puis vert, `-race -count=5` ; un test ajusté (attendre le démarrage du Runner avant de lire `running`) | `.omc/state/loop/gates/20261029-210718-unit-go.log` (vert) |
| 2026-10-29 | TDD T15c | `orchestrate.Pipeline` (relais validé, compensation, commentaire final borné), `RunnerFactory`, `Phrases` étendues, `Message.Agent/Task`, `AgentActivity.Label` ; rouge (`unknown field Label/Agent/Task`, `unknown field Failure in struct literal of type Phrases`, `undefined: Pipeline`) puis vert, `-race -count=3` ; un test d'ordre des résumés rendu déterministe (indice d'agent) | `.omc/state/loop/gates/20261029-211830-unit-go.log` (vert) |
| 2026-10-29 | TDD T15d | `voice.Options.Delegations` : `Open` à l'attache, routage non bloquant (file bornée) des transcripts d'entrée et des délégations, `Close` borné avant `closed` sur tous les chemins ; rouge (`opts.Delegations undefined`) puis vert, `-race -count=3` | `.omc/state/loop/gates/20261029-212212-unit-go.log` (vert) |
| 2026-10-29 | TDD T15e | `wsapp.Options.RetainedMax` : rétention `a2ui`/`agent.activity` séparée du backlog, `deleteSurface` oublie la surface, rejeu fusionné par ordre de publication (A4) ; rouge (`unknown field RetainedMax`, puis rejeu sans les `a2ui` après 200 transcripts) puis vert, `-race -count=3` ; `bootstrap` reçoit `hubRetained` (une ligne) | `.omc/state/loop/gates/20261029-212427-unit-go.log` (vert) |
| 2026-10-29 | TDD T16 | `bootstrap` : config (`AGENTS`, `A2UI_*`, `AGENT_TIMEOUT`, `VOICE_APPEND_ACK_TIMEOUT`, `VOICE_ACK_DELAY_MS`, phrases embarquées), câblage voix -> `Manager` -> `Pipeline`, `AcknowledgementDelayMs` ; rouge (`cfg.Agents undefined`, `AcknowledgementDelayMs undefined`, aucun commentaire sur délégation) puis vert ; acceptation A1-A4, B1-B3bis, B5-B7 verts, aucun correctif d'intégration | `.omc/state/loop/gates/20261029-213003-full.log` (vert) |

## Revue du plan (architect-reviewer, mode PLAN, 2026-10-29)
Verdict : **CONFORME SOUS RÉSERVE** — 4 points bloquants (A1 branchement voix→orchestrateur et cycle de vie ; A2 délégations qui se recouvrent ; A3 validateur A2UI faux sur le rendu progressif et sans liste blanche de composants ; A4 backlog du hub qui perd `createSurface`), A5-A12 importants, A13 mineur. Tous intégrés dans `plan.md` (§ Amendements A1-A13) et `tasks.md` (T04, T11-T17 redécoupées).
Conflits avec une décision, traités sans les trancher : (1) `backend.md` règle 2 et le diagramme de l'acte 1 de `agents-protocols.md` montrent l'orchestrateur qui émet `createSurface`, contre pdr-0036 → le plan suit pdr-0036, documentation à corriger à la clôture ; (2) RG-10 (état neutre) vs compensation `deleteSurface` (A5) → comportement provisoire = retirer, **Q-69** au porteur ; (3) pdr-0052 (une session par acte) vs FR-07 (acte 2 modifie en place l'acte 1) → portée par session en J2, **Q-70** au porteur avant J4.
Non vérifié par la revue : `offset_ms` sur la timeline des deltas en pratique ; `client_event_id` de l'événement `error` ; annulation du contexte de l'exécuteur par `a2asrv` ; `env_file required: false` ; défaut de `acknowledgement_delay_ms` en mode `client`.

## Revue d'architecte (code)

## Questions pour le porteur
Aucune.
