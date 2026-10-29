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

## Références
- `product/architecture/backend.md` (modules `voice-session`, `sideband-supervisor`, `app-channel`, `session-recorder`), `security.md` § contrat de relais, `agents-protocols.md`.
- Notes : [rt-gpt-live-webrtc-session], [rt-gpt-live-sideband], [rt-gpt-live-output-level], [rt-gpt-live-lifecycle], [rt-graceful-close], [ma-backend-sdk-go], [rt-ephemeral-keys].
- Code jetable de référence : `spikes/sp02-gpt-live/relay/` (à relire, pas à copier tel quel).

## Risques
- API `openai-go` `live` jeune → tests de contrat sur un `httptest` qui rejoue des trames relevées en SP-02.
- Fuite de clé → test A1 sur toutes les sorties, absence de la clé dans `Config.String()`.
- Fermeture sale de session (coût) → `Close` distinct, attente de `session.closed`, délai de garde, testé avec le fournisseur simulé.
