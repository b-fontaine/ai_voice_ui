# 003 — État

- **Étape** : Refactorisation
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (T17) : backend/orchestrator/{Dockerfile,.dockerignore,config/voice-instructions.fr.md,cmd/orchestrator/main.go,internal/bootstrap/{healthcheck.go,healthcheck_test.go}}, docker-compose.yaml, .github/workflows/ci.yaml, plan.md, tasks.md, status.md
- **Branche** : feat/003-j2-voice-relay-backend
- **Backlog** : EP-01, EP-02
- **Mis à jour** : 2026-10-29 18:20

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés (J2 découpé en 003 backend, 004 orchestrateur + agent A2A + surface, 005 app voix + orbe) | — |
| 2026-10-29 | Gherkin | T01-T03 : tests d'acceptation A1-A3 (build tag `acceptance`) ; rouge attendu : `no required module provides package .../internal/bootstrap` ; compilent contre une implémentation vide (vérifié hors dépôt) ; `doc.go` ajouté pour que go vet/test trouvent un paquet | .omc/state/loop/gates/20261029-180339-unit-go.log |
| 2026-10-29 | TDD | T10 : `bootstrap.ConfigFromEnv` + `Config` (clé privée, `String`/`GoString` masqués) ; rouge `undefined: Config`, vert ensuite ; `doc.go` supprimé (le paquet `bootstrap` suffit) | .omc/state/loop/gates/20261029-180700-unit-go.log |
| 2026-10-29 | TDD | T11 : `level.RMS` + `level.Meter` (5 niveaux/s, blocs 7 o à 300 ms identiques) ; rouge `undefined: RMS`, vert ensuite | .omc/state/loop/gates/20261029-181002-unit-go.log |
| 2026-10-29 | TDD | T12 : ports (`LiveProvider`, `Sideband`, `Sink`, `Clock`), `domain.Message`, service `voice` (Open, Close avec délai de garde, Shutdown) ; rouge `no required module provides package .../internal/domain`, vert ensuite sous `-race` | .omc/state/loop/gates/20261029-181338-unit-go.log |
| 2026-10-29 | TDD | T13 : adaptateur `openailive` (`New`, `CreateSession`, `Sideband` + traduction des événements, `Close` = `session.close`) ; rouge `no non-test Go files` (paquet absent), vert sous `-race` ; httptest HTTP + WebSocket, aucun réseau réel (comportement face à la vraie API non vérifié ici) | .omc/state/loop/gates/20261029-181932-unit-go.log |
| 2026-10-29 | TDD | T14 : hub WSS `wsapp` (`NewHub`, `Publish`, `Forget`, `Close`, `ServeHTTP`) ; rouge `undefined: Hub` (paquet absent), vert sous `-race -count=3` ; backlog sans `orb.level`, abonné lent fermé 1008, oubli des sessions closes | .omc/state/loop/gates/20261029-182423-unit-go.log |
| 2026-10-29 | TDD | T15 : journal `jsonljournal` (`New`, `Publish`, `Close`) ; `domain.WireData`/`DataJSON` extraits de `wsapp` (noms de champs communs) ; rouge `undefined: Recorder`/`domain.DataJSON`, vert sous `-race -count=3` ; id de session validé, permissions 0600/0700 | .omc/state/loop/gates/20261029-182732-unit-go.log |
| 2026-10-29 | TDD | T16 : `httpapi` (routes, 415/413/429/502, DELETE, `/healthz`, journal d'accès), `fanout`, `bootstrap.New`/`App.Close`, `cmd/orchestrator` ; `JOURNAL_DIR` rendu facultatif dans `ConfigFromEnv` ; correctif d'ordre de fermeture `done`/`events` dans `openailive` (test T13 intermittent) ; A1-A3 verts, `-race -count=3` vert | .omc/state/loop/gates/20261029-183319-full.log |
| 2026-10-29 | TDD | T17 : Dockerfile distroless non-root, `docker-compose.yaml` (127.0.0.1, read_only, cap_drop), CI minimale, sous-commande `healthcheck` (`bootstrap.HealthcheckURL`) ; rouge `docker compose config` sans fichier + `undefined: HealthcheckURL`, vert ; image construite, refuse de démarrer sans `VOICE_MODEL` ; YAML de la CI non validé par actionlint (absent) | .omc/state/loop/gates/20261029-183809-unit-go.log |
| 2026-10-29 | TDD terminé | T10-T17 faites ; `gate.sh --full` vert sur arbre propre (18 contrôles, acceptation A1-A3 comprise) ; aucune clé dans les fichiers du dépôt (comptage) | `.omc/state/loop/gates/20261029-183838-full.log` |
| 2026-10-29 | Revue | architect-reviewer : BLOQUANT (R1), 10 refactorisations + R11 ajoutée par le chef de boucle (rapport collé ci-dessous) | — |

## Revue d'architecte
Verdict (architect-reviewer, 2026-10-29) : **BLOQUANT** (R1) ; conforme sous réserve de R2 à R5 une fois R1 corrigé. Conforme : dépendances hexagonales, injection par constructeur, aucune fuite de clé, journal sans traversée de chemin, origine WebSocket par défaut, compose durci, `Publish` non bloquant, niveau RMS 5 Hz, aucun skip/TODO.

- [ ] **R1 bloquant** — `voice/service.go:137-156` : le délai de garde ne s'applique pas à `sideband.Close` (contexte de l'appelant sans échéance) → `DELETE` bloqué, `ErrCloseTimeout` jamais renvoyé. Corriger : `context.WithTimeout(ctx, GuardTimeout)` passé à `Close` puis attente de `done` sur le même contexte ; `Shutdown` en parallèle ; `main.go:81` contexte borné ; documenter `port.Sideband.Close`. Tests : `TestCloseGuardTimeoutWithBlockingSideband`, `TestShutdownParallelGuard`.
- [ ] **R2 importante** — sessions OpenAI laissées ouvertes (coût, NFR-11) : `Hangup(ctx, id)` dans `port.LiveProvider` + `openailive` (`client.Live.Sessions.Hangup`), appelé si `Sideband` échoue après `CreateSession` et sur coupure sans `session.closed` ; `LiveEvent.Reason` ; `NewMeter` validé dans `NewService` ; `Options.MaxSession` (`VOICE_MAX_SESSION`) ; `delete(s.sessions, id)` en fin de supervision. Tests : `TestOpenSidebandFailsHangsUp`, `TestUnexpectedDisconnectHangsUp`, `TestMaxSessionClosesSession`, `TestSessionForgottenAfterRemoteClose`.
- [ ] **R11 importante (ajoutée par le chef de boucle, risque non vérifié du revue)** — attache du sideband : le spike SP-02 attachait **en arrière-plan avec 5 tentatives espacées de 500 ms** ; `Open` attache aujourd'hui de façon synchrone avant de renvoyer l'answer, ce qui peut échouer (ou bloquer) tant que le WebRTC n'est pas établi. Corriger : `Open` publie `session.state{connecting}`, renvoie l'answer, puis attache en arrière-plan (tentatives et délai injectés, bornés) et publie `active` ; échec final → `Hangup` + `session.state{closed, reason:"attach_failed"}`. Tests : double dont `Sideband` échoue N fois puis réussit ; échec définitif.
- [ ] **R3 importante** — `Dockerfile:10-12`, `docker-compose.yaml:40,44-45` : le volume du journal n'est pas inscriptible par l'utilisateur 65532 (`/var/lib/genesis/journal` absent de l'image) → créer le dossier avec `--chown=65532:65532` ; `jsonljournal.New` sonde l'écriture. Tests : `TestNewFailsOnUnwritableDir` ; en Vérification : un `.jsonl` apparaît dans le volume.
- [ ] **R4 importante** — contrat v1 de l'app-channel : (a) retirer `transcript.final` (toujours faux), ajouter `start_ms`/`end_ms` ; (b) `session.state` porte un `reason` ; (c) décision de conception du chef de boucle : `GET /app` **sans `session` obligatoire** = un canal par instance d'app qui reçoit les messages de toutes les sessions (champ `session` dans l'enveloppe), `?session=<id>` reste un filtre facultatif (les tests A2 restent valides). Écrire le contrat dans `product/architecture/agents-protocols.md`. Tests : `TestEnvelopeShape`, acceptation « deux sessions successives » (`fakeLive` à identifiant variable).
- [ ] **R5 importante** — `wsapp/hub.go` : `Options.WriteTimeout` ; identifiant de session validé par `domain.ValidSessionID` (partagé avec `jsonljournal`) → 400 ; identifiant inconnu → 404 sans entrée créée (si le filtre `?session=` est fourni). Tests : `TestHubStalledWriterTimesOut`, `TestHubUnknownSession404`, `TestHubInvalidSessionID400`.
- [ ] **R6 mineure** — réglages de répétition lus dans l'environnement (`VOICE_CLOSE_GUARD`, `SESSION_RATE_BURST`, `SESSION_RATE_WINDOW`, `VOICE_MAX_SESSION`) avec défauts dans le compose ; `openailive.OutputSampleRate` exporté. Tests de config.
- [ ] **R7 mineure** — la délégation est validée par `openailive` seul, qui construit le paramètre par `switch` sur la valeur configurée.
- [ ] **R8 mineure** — supprimer `Forget` et `Reset` (sans appelant) ; `parseListenPort` partagé avec le healthcheck ; retirer le commentaire HTML de `voice-instructions.fr.md`.
- [ ] **R9 mineure** — `domain.Payload` (interface fermée) pour `Message.Data` ; sérialisation filaire déplacée dans `internal/adapter/wire`.
- [ ] **R10 mineure** — (a) contrôle de l'en-tête `Host` (`AllowedHosts`, 421) ; (b) A1 vérifie aussi les logs slog ; (c) images `golang` et `distroless` figées par digest.

Conflits avec une décision : aucun bloquant. (1) Nom du module : `backend/orchestrator` dans le code, `backend/agent_orchestrator` dans backend.md/adr-0003 → écart documentaire, aligné par product-curate à la clôture. (2) AGENTS.md § 2 dit « n'écoutent que sur 127.0.0.1 » ; le conteneur écoute sur 0.0.0.0 et l'hôte publie sur 127.0.0.1 (conforme à pdr-0041) → formulation d'AGENTS.md à clarifier par le porteur (la boucle n'y touche pas). (3) Plafond de durée par session : mécanisme en R2, valeur par défaut = proposition de l'assistant → Q-68 pour le porteur, valeur provisoire dans le compose.

Non vérifié par la revue : attache du sideband avant WebRTC (couvert par R11 et l'essai réel), permissions du volume, API réelle, YAML de la CI, DNS rebinding.

## Questions pour le porteur
Aucune.
