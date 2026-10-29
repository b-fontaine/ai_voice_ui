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
- `GET /app?session=<id>` (WSS) : enveloppe `{v:1, type, t_ms, data}` ; types : `orb.level` (`{level}` 0..1, 5 Hz), `transcript` (`{role: user|ai, text, final}`), `session.state` (`{state}`), `usage` (`{seconds, context_ratio}`).
- Configuration (variables d'environnement, aucune valeur en dur) : `OPENAI_API_KEY`, `VOICE_MODEL`, `VOICE_VOICE`, `VOICE_DELEGATION_TYPE`, `VOICE_INSTRUCTIONS_FILE`, `LISTEN_HOST` (défaut `127.0.0.1`), `LISTEN_PORT`, `JOURNAL_DIR`.

### Contrats imposés par les tests d'acceptation (A1-A3)
- `port.LiveProvider` : `CreateSession(ctx, offerSDP string) (port.LiveSession{ID, AnswerSDP}, error)` et `Sideband(ctx, sessionID string) (port.Sideband, error)`.
- `port.Sideband` : `Events() <-chan port.LiveEvent` (fermé après `EventClosed`) et `Close(ctx) error`. `port.Clock` : `Now() time.Time`.
- `port.LiveEvent{Type EventType; Text string; Final bool; PCM []byte; Seconds, ContextRatio float64}` ; `EventType` : `EventInputTranscriptDelta`, `EventOutputTranscriptDelta`, `EventOutputAudio`, `EventUsageUpdated`, `EventClosed`.
- `bootstrap.Config{Model, Voice, DelegationType, ListenHost string; ListenPort int; JournalDir string}` (+ `String()` sans clé) ; `Deps{Live, Clock, JournalDir}` ; `New`, `App.Handler()`, `App.Close(ctx)`, `ConfigFromEnv(getenv)` ; `LISTEN_ALLOW_NON_LOOPBACK=1` lève le refus.
- Un `orb.level` par bloc `EventOutputAudio` de 200 ms (= 5 Hz de signal) ; l'horloge ne sert qu'à `t_ms` et au journal.
- `domain.Message{Type string; TMs int64; Data any}` : contenu logique de l'enveloppe v1 (sans `v`) ; données typées `OrbLevel`, `Transcript`, `SessionState`, `Usage` ; constantes `TypeOrbLevel`, `TypeTranscript`, `TypeSessionState`, `TypeUsage`.
- `port.Sink` : `Publish(sessionID string, m domain.Message)` ; le hub WSS (T14) l'implémente.
- `voice.Options{SampleRate, WindowMs int; GuardTimeout time.Duration}` : injectées, toutes > 0 (sinon `NewService` échoue) ; `Service.Open/Close/Shutdown` ; `Close` renvoie `ErrCloseTimeout` si la fermeture n'est pas confirmée à temps.
- `openailive.Options{APIKey, BaseURL, Model, Voice, DelegationType, Instructions string}` : `BaseURL` vide = défaut du SDK ; seule la délégation `client` est acceptée (`responses`/`decisions` : erreur à `New`, pdr-0050) ; `String()` masque la clé.
- `openailive` ignore sans erreur tout événement sideband hors transcripts, audio, usage et `session.closed` (dont `session.delegation.created`, fonctionnalité 004) ; une coupure inattendue produit `EventClosed` puis ferme le canal.
- `wsapp.Options{Backlog, SendBuffer int}` : injectées, toutes > 0 (sinon `NewHub` échoue) ; `Hub` = `port.Sink` + `http.Handler` ; `Forget(id)` et `Close(ctx)` (1001).
- Backlog : à la connexion, rejeu des `Backlog` derniers messages publiés, `orb.level` exclu, sans doublon ni perte avant le direct.
- Journal : une ligne JSON par message dans `<JOURNAL_DIR>/<session>.jsonl` : `{"unix_ms","t_ms","type","data"}` ; `data` est sérialisé par `domain.DataJSON` (mêmes noms de champs que l'enveloppe de l'app-channel, partagé avec `wsapp`).
- `jsonljournal.Options{Dir string; Clock port.Clock; OnError func(error)}` : toutes obligatoires (sinon `New` échoue) ; dossier 0700, fichiers 0600 ; `*Recorder` = `port.Sink` + `Close() error` ; erreurs d'écriture transmises à `OnError`, jamais de panique.
- Identifiant de session du journal : `[A-Za-z0-9_-]{1,128}`, sinon enregistrement refusé (`OnError`), aucune traversée de chemin.
- Abonné lent : file bornée par `SendBuffer` ; en cas de débordement la connexion est fermée en 1008 (« trop lent ») sans bloquer `Publish`.

## Références
- `product/architecture/backend.md` (modules `voice-session`, `sideband-supervisor`, `app-channel`, `session-recorder`), `security.md` § contrat de relais, `agents-protocols.md`.
- Notes : [rt-gpt-live-webrtc-session], [rt-gpt-live-sideband], [rt-gpt-live-output-level], [rt-gpt-live-lifecycle], [rt-graceful-close], [ma-backend-sdk-go], [rt-ephemeral-keys].
- Code jetable de référence : `spikes/sp02-gpt-live/relay/` (à relire, pas à copier tel quel).

## Risques
- API `openai-go` `live` jeune → tests de contrat sur un `httptest` qui rejoue des trames relevées en SP-02.
- Fuite de clé → test A1 sur toutes les sorties, absence de la clé dans `Config.String()`.
- Fermeture sale de session (coût) → `Close` distinct, attente de `session.closed`, délai de garde, testé avec le fournisseur simulé.
