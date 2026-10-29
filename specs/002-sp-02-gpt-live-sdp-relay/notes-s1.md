# 002 — Notes S1 : lecture du code `openai-go/v3` (live, sideband)

Lecture faite le 2026-10-29 sur le code téléchargé (pas seulement les notes `knowledge/`).

## Versions résolues
| Élément | Version | Où |
|---|---|---|
| `github.com/openai/openai-go/v3` | **v3.90.0** (dernière sur le proxy) ; son `go.mod:3` demande `go 1.26.0` | `spikes/sp02-gpt-live/relay/go.mod` |
| `github.com/pion/webrtc/v4` | **v4.2.26** | `spikes/sp02-gpt-live/client/go.mod` |
| Go (toolchain locale) | go1.27.3 linux/amd64 (`go.mod` des modules : `go 1.27.3`) | |
| `github.com/coder/websocket` | v1.8.15 (tiré par le SDK pour le sideband) | `relay/go.mod` |

Les chemins ci-dessous sont relatifs à `$GOMODCACHE/github.com/openai/openai-go/v3@v3.90.0/live/`.

## 1. Création de session : le SDK suffit (pas de POST brut)
- `func (r *LiveService) New(ctx, body LiveNewParams, opts...) (*LiveNewResponse, error)` : `live.go:49`. Chemin `live/sessions` (`live.go:52`), méthode POST, authentification Bearer (`requestconfig.WithBearerAuthSecurity`). Accès : `client.Live.New` (`client.go:59,142`). `openai.NewClient()` lit `OPENAI_API_KEY` dans l'environnement (`client.go:78`).
- Corps (`live.go:8221-8228`) : `LiveNewParams{ Session MediaSessionConfigParam; Transport LiveNewParamsTransport }`. Forme JSON exacte :
  `{"session":{"model":"gpt-live-1", "instructions":…, "delegation":{…}, "audio":{"output":{"voice":"brise"}}, …}, "transport":{"type":"webrtc","sdp":"<offre>"}}`.
  - `Transport` : `Sdp` requis, `Type` constant `"webrtc"` (`live.go:8240-8248`).
  - `MediaSessionConfigParam` (`live.go:5093-5126`) : `Model` **requis** (seule constante : `gpt-live-1`, `live.go:5143`) ; `Instructions` (≤ 16 384 tokens), `Store`, `Delegation`, `Audio.Output.Voice` (chaîne libre ou `BuiltInVoice` ou voix personnalisée, `live.go:5183-5190` ; `brise`/`sillage` ne figurent pas dans les constantes `BuiltInVoice`, `live.go:358-370`, mais `OfString` les accepte), `Client.DataChannel` (permissions `allowed_client_events` / `allowed_server_events` du data channel du frontend, `live.go:374-410,1129-1141`), `Input` (historique), `Triggers` (Decisions).
  - Aucun champ `audio.format` pour WebRTC (« WebRTC and SIP negotiate their audio format on the media transport », `live.go:5110-5111`).
- Réponse (`live.go:8159-8219`) : `Session.ID` (« Opaque session identifier. Preserve the returned value unchanged, including its prefix », `live.go:8185`) et `Transport.Sdp` (`live.go:8204`) ; `Transport.Type` = `webrtc`. La doc du type dit d'attendre `session.started` sur le data channel avant toute commande (`live.go:8155-8158`).

## 2. Modes de délégation : trois, pas deux
`MediaSessionConfigDelegationUnionParam` (`live.go:5201`, discriminant `type`, enregistré en `live.go:5256`) :
| `type` | Struct | Champs |
|---|---|---|
| `client` (défaut si `delegation` omis ou null) | `ClientDelegationParam` (`live.go:464-477`) | `acknowledgement_delay_ms` (optionnel) |
| `responses` | `MediaSessionConfigDelegationResponsesParam` (`live.go:5267-5284`) | `responses` **requis**, `acknowledgement_delay_ms` |
| `decisions` (**nouveau, absent des notes**) | `MediaSessionConfigDelegationDecisionsParam` (`live.go:5294-5308`) | `decisions` requis (`DecisionsDelegationConfigParam`, `live.go:3207`), défaut `acknowledgement_delay_ms` 400 |

Mode `responses` : forme `{"delegation":{"type":"responses","responses":{"model":"<id>", …}}}`.
- Champs de `ResponsesDelegationConfigParam` (`live.go:5871-5900`) : `model` **seul champ requis** ; `instructions`, `max_output_tokens`, `parallel_tool_calls`, `reasoning`, `service_tier` (`auto`, `default`, `fast_tier_temp_pilot`, `flex`, `priority`, `ultrafast`), `text`, `tool_choice`, `tools` (union `function` | `web_search` uniquement, `live.go:6047-6051`).
- **Modèle utilisable : le code ne fixe aucune liste.** `Model` est un `string` libre (`live.go:5873`), sans énumération ni exemple dans le package `live` (les chaînes `gpt-5.6-*`/`gpt-6-*` de `live/aliases.go:160-190` ne sont que l'alias générique `ChatModel`, pas une liste propre à Live). Les notes se contredisent : `gpt-6-luna`/`gpt-6-sol` ([rt-gpt-live-delegation]) contre `gpt-5.6-terra` ([rt-gpt-live-webrtc-session]). **Fait établi le 2026-10-29** par `GET /v1/models` (gratuit, clé du porteur) : la clé voit `gpt-live-1`, `gpt-live-transcribe`, et notamment `gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-6-astra`, `gpt-6-luna`, `gpt-6-sol`, `gpt-6.1-sol` (liste tronquée à 80 lignes dans l'essai). Être listé ne prouve pas que le modèle est accepté comme backend `responses` : seul un essai le dira (première session `responses`). À éviter pour le test : modèles `*-pro`, `*-codex`, `*-sol` supposés coûteux (non vérifié) ; viser le plus petit candidat (`gpt-5.6-luna` ou `gpt-6-luna`, à confirmer par erreur 4xx éventuelle).
- Événement `session.delegation.created` (`live.go:3804-3860`) : `delegation.id`, `delegation.target` (`client` | `responses` | `decisions`), `delegation.response_id` (mode `responses` uniquement), `event_id`, `offset_ms`. **Pas de texte de l'utilisateur** (« contains metadata, not the task text », `live.go:3836-3837`). Le texte se reconstruit depuis les transcripts.

## 3. Sideband
- `client.Live.Sideband.Connect(ctx, sessionID, live.SidebandConnectionOptions{}, opts...)` : `live_sideband_websocket.go:28` ; GET `live/sessions/{id}/attach` (`live_sideband_websocket_binding.go:19`). Options = `websocket.Options` (limites facultatives ; `MaxMessageBytes` 0 = pas de limite, `SetReadLimit(-1)`, `packages/websocket/connection.go:204`).
- Méthodes (`live_sideband_websocket.go`) : `Send(ctx, ConnectClientEventUnionParam)` :76 ; `Recv` :81 (typé) ; `SendRaw` :92 ; `RecvRaw` :99 (JSON brut conservé, même file que `Recv`) ; `Close` :108 (poignée de main bornée) ; `Abort` :111 ; `Reconnect` :115 (ne rejoue rien).
- Événements client (union `live/sideband.go:165-180`, discriminants `sideband.go:321-336`) : `session.update`, `session.input_audio.mute|unmute`, `session.output_audio.fixture.play` (nouveau : injecte de l'audio de test), `session.instructions|thinking|commentary.append`, `decision.create`, `decision.item.create|delete`, `response.item.create`, `response.create`, `session.close`.
- `ConnectClientEventParamOfSessionCommentaryAppend(content, delegationID)` : `sideband.go:62`. `CommentaryAppendEventParam` (`live.go:1024`) : `delegation_id` (requis mais nullable), `content`, `event_id` optionnel. **L'`event_id` est optionnel dans le SDK** ; on le met toujours (accusé de réception `…appended` avec `client_event_id`).
- Événements serveur (`ConnectServerEventUnion`, `sideband.go:356`, aiguillage par `type` : `sideband.go:486-544`) — noms réels, tous confirmés :
  `session.started` (`live.go:7781` : `event_id`, `session` = `SessionResource` avec `id`, `expires_at`, `model`, `delegation`…), `session.updated`, `session.input_audio.muted|unmuted`, `session.output_audio.fixture.playing|played`, `session.instructions|thinking|commentary.appended`, `session.input_transcript.delta` (`delta`, `start_ms`, `end_ms`, `event_id`, `live.go:4982`), `session.output_transcript.delta` (`live.go:5490`), `session.delegation.created`, `decision.event`, `decision.item.created|deleted`, `response.event`, `session.usage.updated` (`usage.seconds` cumulé, `context_window`, `live.go:8038`), `session.closed` (`reason`, `usage`, `session`, `live.go:7167`), `error` (`error.{code,message,type,param,client_event_id}`, `live.go:3901`), `info` (nouveau, `live.go:4105`), `session.input_audio.append`, `session.output_audio.delta` (`delta` base64, `start_ms`, `end_ms` optionnels, `live.go:5373`), `transport.dtmf.*`, `transport.ringing|answered|failed` (SIP).
- **Q-53 :** `SessionResource.ExpiresAt` (secondes Unix, `live.go:7455`) donne l'expiration prévue dès `session.started` : le relais la journalise, donc la durée maximale se lira sans attendre `expired`.
- `session.closed.reason` est une chaîne libre (`live.go:7207`, pas d'énumération dans le code).

## 4. Décisions de conception du relais (spike)
- Création par `client.Live.New` (SDK) ; corps = `session.{model, instructions, audio.output.voice (défaut brise), delegation}` + `transport.{sdp}`. Aucun POST brut nécessaire.
- Relais : `POST /session` accepte aussi `voice`, `responses_model` (requis en mode `responses`) et `responses_instructions`.
- Les messages d'erreur du SDK ne contiennent pas d'en-têtes ; le relais redacte quand même la clé (`strings.ReplaceAll`) dans les erreurs et le journal.
- Le sideband est lu en `RecvRaw` pour garder les noms d'événements inconnus du SDK ; le base64 audio n'est jamais journalisé (taille et RMS PCM16 seulement).

## 5. Écarts avec la tâche
- Le client lit les pages Ogg avec un petit lecteur maison (`client/ogg.go`) au lieu d'`oggreader` : il reconstitue les paquets par la table de segments (robuste si une page contient plusieurs paquets) et déduit la durée du TOC Opus. Les fichiers TTS réels contiennent 178 à 281 paquets de 20 ms.
- Modèle TTS choisi d'après `GET /v1/models` filtré sur `tts` : `gpt-4o-mini-tts`, `gpt-4o-mini-tts-2025-03-20`, `gpt-4o-mini-tts-2025-12-15`, `tts-1`, `tts-1-1106`, `tts-1-hd`, `tts-1-hd-1106`. Retenu : `gpt-4o-mini-tts`, voix `alloy`, instruction « parle en français ».
