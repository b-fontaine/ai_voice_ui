---
id: ma-backend-sdk-go
title: SDK Go pour l'orchestrateur — faits vérifiés (2026-10-27)
tags: [backend, go, sdk, gpt-live, gemini, mcp, a2a, a2ui, temporal]
status: verified
updated: 2026-10-29
sources: [https://github.com/openai/openai-go/blob/main/live/api.md, https://github.com/openai/openai-go/blob/main/live/live_sideband_websocket.go, https://github.com/openai/openai-go/releases, https://github.com/googleapis/go-genai/blob/main/tokens.go, https://github.com/modelcontextprotocol/go-sdk/releases, https://github.com/a2aproject/a2a-go, https://github.com/google/adk-go/blob/main/go.mod, https://github.com/temporalio/ai-integrations/tree/main/go/googleadk, https://github.com/temporalio/sdk-go/releases, https://github.com/firebase/genkit/tree/main/go/plugins/a2ui/exp, https://github.com/google/jsonschema-go]
links: [ma-openai-responses-structured-request, proto-a2a-go-v03-compat, ma-backend-sdk-landscape, ma-backend-stack-recommendation, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-webrtc-session, rt-gemini-ephemeral-tokens, proto-mcp-overview, proto-a2a-overview]
---
# Écosystème Go (vérifié dans le code le 2026-10-27)

**GPT-Live — `github.com/openai/openai-go/v3` (v3.88.0 le 2026-10-26 ; essais réels avec v3.90.0 le 2026-10-29, `go 1.26.0`)**
- `client.Live.New(ctx, live.LiveNewParams{Session, Transport})` : POST `live/sessions`, Bearer ; la réponse porte `Session.ID` et `Transport.Sdp`. Vérifié en vrai : le SDK suffit pour un relais SDP, sans POST brut ([[rt-gpt-live-webrtc-session]]).
- `client.Live.Sessions` : `Accept`, `Fork`, `Hangup`, `Refer`, `Reject`, `DownloadRecording`.
- `live.SidebandService.Connect(ctx, sessionID, opts)` : GET `live/sessions/{id}/attach` ; `Send`, `Recv`, `SendRaw`, `RecvRaw`, `Close`, `Reconnect`, `Abort`.
- Événements typés : `session.delegation.created`, `commentary.append(ed)`, `thinking.append(ed)`, `instructions.append`, `input/output_transcript.delta`, `input_audio.mute`, `close/closed`. `ClientDelegation.AcknowledgementDelayMs` existe. Trois modes de délégation (`client`, `responses`, `decisions`) et événements `decision.*`, `info`, `response.event` ([[rt-gpt-live-delegation]]).
- Commit « add delegation controls » : 2026-10-23 (v3.86, changement cassant sur les champs `Instructions` des Decisions).

**Gemini — `google.golang.org/genai` v1.76.0 (2026-10-22, `go 1.24`)** : `client.AuthTokens.Create(ctx, *CreateAuthTokenConfig)` (`Uses`, `LiveConnectConstraints`), qui journalise « ephemeral tokens implementation is experimental ». Exemple `examples/live_with_ephemeral_token/`.

**MCP — `modelcontextprotocol/go-sdk` v1.8.0** : 2026-07-28 complet depuis v1.7.0 (`server/discover`, `input_required`, repli `initialize`). `ClientCredentialsHandler` depuis v1.6.0 ; OAuth client marqué expérimental.

**A2A — `github.com/a2aproject/a2a-go/v2` v2.7.0 (2026-10-21, `go 1.26.0`)** : spec v1.0, bindings gRPC / REST / JSON-RPC, compat v0.3 via `a2acompat/a2av0` (vérifié le 2026-10-29 face à `genui_a2a` : [[proto-a2a-go-v03-compat]]).

**ADK Go — `google.golang.org/adk/v2` v2.6.0 (2026-10-13, `go 1.26.10`)** : `openaimodel`, `RunLive`, mcptoolset, `server/adka2a/v2`. Le go.mod tire openai-go **v3.82.0**, otel **v1.47.0**, a2a-go v0.3.15 **et** v2.6.0. Ligne v1.9.0 maintenue en parallèle.

**Temporal** : sdk-go v1.50.0 (2026-10-15). `go.temporal.io/googleadk` (`go 1.26.6`, otel v1.45) : chaque tour LLM devient une Activity, `NewMCPToolset` ; remplace `sdk/contrib/googleadk`.

**A2UI** : pas de SDK Go dans `a2ui-project/a2ui`, mais les JSON Schemas `specification/v0_9`, `v0_9_1`, `v1_0` et `conformance/` sont publiés. Genkit Go `plugins/a2ui/exp` : preview, `ValidateStrict|Warn|Off` = contrôle de structure, pas d'assainissement (les URL d'`Image` passent), versions v0.9 et v0.9.1 seulement. `google/jsonschema-go` v0.4.3 valide du JSON contre un schéma.

⚠️ Pièges
- Planchers réels : **Go ≥ 1.26.10** et **OTel ≥ v1.47** dès qu'on importe adk/v2.
- MVS : si ADK tire openai-go v3.82, épingler explicitement ≥ v3.86 pour les contrôles de délégation.
- **Sideband : un seul envoi à la fois.** `SidebandConnection.Send*` renvoie `pending send limit exceeded` si deux envois se chevauchent : sérialiser les envois par un mutex (vérifié le 2026-10-29, `v3.90.0`) ; l'acquittement `…appended` se lit dans la boucle de réception.
- Dates divergentes entre fact-checks sur l'arrivée du sideband typé (2026-09-10 #912 ou 2026-10-17 #1088) : traiter le package `live` comme jeune.
