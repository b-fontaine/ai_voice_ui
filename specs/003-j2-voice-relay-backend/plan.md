# 003 — Plan technique

## Où
| Pile | Module | Couche | Contenu |
|---|---|---|---|
| Go | `backend/orchestrator` (`go.mod`, Go 1.27.3, `go.sum`) | domaine | `internal/domain` : `SessionID`, événements (`TranscriptDelta`, `OutputLevel`, `Usage`), `Config` |
| Go | idem | application | `internal/app/voice` : service `Open(offer) → answer`, supervision du sideband ; `internal/app/level` : RMS PCM16 24 kHz par blocs de 200 ms, agrégation 5 Hz |
| Go | idem | ports | `internal/port` : `LiveProvider` (création de session + sideband), `Journal`, `Clock` |
| Go | idem | adaptateurs | `internal/adapter/openailive` (openai-go/v3 `client.Live`), `adapter/wsapp` (hub WSS), `adapter/httpapi` (`/voice/sessions`, `/healthz`), `adapter/jsonljournal`, `adapter/fakelive` (tests) |
| Go | idem | main | `cmd/orchestrator` : câblage, `listen.host` loopback |
| Infra | racine | — | `backend/Dockerfile`, `docker-compose.yaml` (`env_file: .env`, ports `127.0.0.1`), `.github/workflows/ci.yaml` minimal |

## Contrats
- `POST /voice/sessions` : corps `application/sdp` (offre) ; réponse 200 `application/sdp` + en-tête `X-Session-Id` ; erreurs JSON `{error}`. Limité en débit, journalisé.
- `GET /app?session=<id>` (WSS) : enveloppe `{v:1, type, t_ms, data}` ; types : `orb.level` (`{level}` 0..1, 5 Hz), `transcript` (`{role: user|ai, text, final}`), `session.state` (`{state, reason?}` : `connecting` à l'ouverture, `active` dès l'attache du sideband, `closed` avec `reason` éventuelle dont `max_session` et `attach_failed`), `usage` (`{seconds, context_ratio}`).
- Configuration (variables d'environnement, aucune valeur en dur) : `OPENAI_API_KEY`, `VOICE_MODEL`, `VOICE_VOICE`, `VOICE_DELEGATION_TYPE`, `VOICE_INSTRUCTIONS_FILE`, `LISTEN_HOST` (défaut `127.0.0.1`), `LISTEN_PORT`, `JOURNAL_DIR`, `VOICE_MAX_SESSION` (facultative, durée Go ≥ 0, absente = pas de plafond ; défaut du compose `30m`, valeur provisoire, Q-68).
- Compose (racine) : service `orchestrator`, `env_file: .env`, défauts surchargeables `VOICE_MODEL=gpt-live-1`, `VOICE_VOICE=brise`, `VOICE_DELEGATION_TYPE=client` ; écoute `0.0.0.0` + `LISTEN_ALLOW_NON_LOOPBACK=1` dans le conteneur seulement ; journal sur volume nommé ; consignes vocales provisoires montées en lecture seule.
- Ports : publication `127.0.0.1:8080:8080` uniquement (pdr-0041) ; conteneur `read_only`, `cap_drop: ALL`, `no-new-privileges` ; healthcheck = sous-commande `orchestrator healthcheck` (sonde `/healthz`, image distroless sans shell).
- CI (`.github/workflows/ci.yaml`) : jobs `backend` (gofmt, vet, tests `-race` avec et sans `acceptance`, `docker build`) et `app` (Flutter 3.47.8, build_runner si présent, analyze, test) ; `contents: read`, aucun secret.

### Contrats imposés par les tests d'acceptation (A1-A3)
- `port.LiveProvider` : `CreateSession(ctx, offerSDP string) (port.LiveSession{ID, AnswerSDP}, error)`, `Sideband(ctx, sessionID string) (port.Sideband, error)` et `Hangup(ctx, sessionID string) error` (termine la session chez le fournisseur ; appelé si `Sideband` échoue après `CreateSession` et sur coupure sans `session.closed`, borné par `GuardTimeout`, jamais sur une fermeture déjà terminale : `close_requested`, `expired`, `remote_hangup`, `content`, ni sur une fermeture confirmée par `session.closed` ; **un seul `Hangup` par session**, y compris après dépassement du délai de garde ou échec de `Sideband.Close` : `ErrCloseTimeout` reste détectable et l'erreur de `Hangup` lui est jointe).
- `port.Sideband` : `Events() <-chan port.LiveEvent` (fermé après `EventClosed`) et `Close(ctx) error`. `port.Clock` : `Now() time.Time`.
- `port.LiveEvent{Type EventType; Text string; Final bool; PCM []byte; Seconds, ContextRatio float64; Reason string}` (`Reason` : raison de `session.closed`, ou `connection_lost` sur coupure du flux) ; `EventType` : `EventInputTranscriptDelta`, `EventOutputTranscriptDelta`, `EventOutputAudio`, `EventUsageUpdated`, `EventClosed`.
- `bootstrap.Config{Model, Voice, DelegationType, ListenHost string; ListenPort int; JournalDir string}` (+ `String()` sans clé) ; `Deps{Live, Clock, JournalDir}` ; `New`, `App.Handler()`, `App.Close(ctx)`, `ConfigFromEnv(getenv)` ; `LISTEN_ALLOW_NON_LOOPBACK=1` lève le refus.
- Un `orb.level` par bloc `EventOutputAudio` de 200 ms (= 5 Hz de signal) ; l'horloge ne sert qu'à `t_ms` et au journal.
- `domain.Message{Type string; TMs int64; Data any}` : contenu logique de l'enveloppe v1 (sans `v`) ; données typées `OrbLevel`, `Transcript`, `SessionState{State, Reason string}` (JSON `{state, reason?}`, `reason` omis si vide ; `max_session` quand le plafond de durée est atteint), `Usage` ; constantes `TypeOrbLevel`, `TypeTranscript`, `TypeSessionState`, `TypeUsage`.
- `port.Sink` : `Publish(sessionID string, m domain.Message)` ; le hub WSS (T14) l'implémente.
- `voice.Options{SampleRate, WindowMs, AttachAttempts int; GuardTimeout, MaxSession, AttachDelay time.Duration; After func(time.Duration) <-chan time.Time; Logger *slog.Logger}` : injectées ; `Open` renvoie l'answer sans attendre le sideband, attaché en arrière-plan (`AttachAttempts` > 0 tentatives, `AttachDelay` > 0 entre deux, via `After` ; échec final : `Hangup` + `session.state{closed, reason:"attach_failed"}` ; `Close`/`Shutdown` pendant `connecting` raccrochent) ; variables `VOICE_ATTACH_ATTEMPTS`/`VOICE_ATTACH_DELAY` facultatives (repli 5 et 500ms dans `Config`, compose `5` / `500ms`) ; `SampleRate`/`WindowMs`/`GuardTimeout` > 0 et paramètres du compteur de niveau valides (sinon `NewService` échoue) ; `MaxSession` ≥ 0 (0 = pas de plafond ; au-delà, fermeture propre et `session.state{closed, reason:"max_session"}`), `After` nil = `time.After` ; une session terminée côté fournisseur est oubliée (`Close` renvoie alors `ErrUnknownSession`) ; `Service.Open/Close/Shutdown` ; `Close` renvoie `ErrCloseTimeout` si la fermeture n'est pas confirmée à temps.
- `openailive.Options{APIKey, BaseURL, Model, Voice, DelegationType, Instructions string}` : `BaseURL` vide = défaut du SDK ; seule la délégation `client` est acceptée (`responses`/`decisions` : erreur à `New`, pdr-0050) ; `String()` masque la clé.
- `openailive` ignore sans erreur tout événement sideband hors transcripts, audio, usage et `session.closed` (dont `session.delegation.created`, fonctionnalité 004) ; une coupure inattendue produit `EventClosed` puis ferme le canal.
- `wsapp.Options{Backlog, SendBuffer int}` : injectées, toutes > 0 (sinon `NewHub` échoue) ; `Hub` = `port.Sink` + `http.Handler` ; `Forget(id)` et `Close(ctx)` (1001).
- Backlog : à la connexion, rejeu des `Backlog` derniers messages publiés, `orb.level` exclu, sans doublon ni perte avant le direct.
- Journal : une ligne JSON par message dans `<JOURNAL_DIR>/<session>.jsonl` : `{"unix_ms","t_ms","type","data"}` ; `data` est sérialisé par `domain.DataJSON` (mêmes noms de champs que l'enveloppe de l'app-channel, partagé avec `wsapp`).
- `jsonljournal.Options{Dir string; Clock port.Clock; OnError func(error)}` : toutes obligatoires (sinon `New` échoue) ; dossier 0700, fichiers 0600 ; `*Recorder` = `port.Sink` + `Close() error` ; erreurs d'écriture transmises à `OnError`, jamais de panique.
- Identifiant de session du journal : `[A-Za-z0-9_-]{1,128}`, sinon enregistrement refusé (`OnError`), aucune traversée de chemin.
- Abonné lent : file bornée par `SendBuffer` ; en cas de débordement la connexion est fermée en 1008 (« trop lent ») sans bloquer `Publish`.
- Routes HTTP (`httpapi.NewHandler`) : `POST /voice/sessions` (415 si pas `application/sdp`, 400 corps vide, 413 corps trop gros, 429 + `Retry-After`, 502 JSON `{error}` opaque), `GET /healthz` (200 `ok`), `GET /app` (hub WSS) ; journal d'accès slog (méthode, route, statut, durée, session), jamais de corps.
- `DELETE /voice/sessions/{id}` : fermeture propre via `Sessions.Close` ; 204, 404 (id inconnu), 504 (`ErrCloseTimeout`), 502 sinon.
- Limite de débit : seau à jetons sur la création de session, `Options{RateBurst, RateWindow, MaxBodyBytes}` injectées et > 0, horloge injectée ; un jeton rendu par fenêtre.
- `bootstrap.New` : `Deps.Live == nil` construit `openailive` depuis `Config` (clé, modèle, voix, délégation, instructions lues dans `InstructionsFile`) ; `JOURNAL_DIR` facultatif dans `ConfigFromEnv`, `Deps.JournalDir` prime sur `Config.JournalDir`, l'un des deux est requis ; `App.Close` : sessions, hub, journal (idempotent).

## Références
- `product/architecture/backend.md` (modules `voice-session`, `sideband-supervisor`, `app-channel`, `session-recorder`), `security.md` § contrat de relais, `agents-protocols.md`.
- Notes : [rt-gpt-live-webrtc-session], [rt-gpt-live-sideband], [rt-gpt-live-output-level], [rt-gpt-live-lifecycle], [rt-graceful-close], [ma-backend-sdk-go], [rt-ephemeral-keys].
- Code jetable de référence : `spikes/sp02-gpt-live/relay/` (à relire, pas à copier tel quel).

## Risques
- API `openai-go` `live` jeune → tests de contrat sur un `httptest` qui rejoue des trames relevées en SP-02.
- Fuite de clé → test A1 sur toutes les sorties, absence de la clé dans `Config.String()`.
- Fermeture sale de session (coût) → `Close` distinct, attente de `session.closed`, délai de garde, testé avec le fournisseur simulé.
