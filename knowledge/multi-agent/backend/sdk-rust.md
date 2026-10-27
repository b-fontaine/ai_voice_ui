---
id: ma-backend-sdk-rust
title: SDK Rust pour l'orchestrateur — faits vérifiés (2026-10-27)
tags: [backend, rust, sdk, gpt-live, gemini, mcp, a2a, a2ui, temporal]
status: verified
updated: 2026-10-27
sources: [https://developers.openai.com/api/docs/libraries, https://github.com/64bit/async-openai/blob/main/async-openai/src/realtime.rs, https://crates.io/crates/oai-rt-rs, https://github.com/openai/openai-openapi/blob/main/openapi.yaml, https://ai.google.dev/gemini-api/docs/ephemeral-tokens, https://crates.io/crates/google-cloud-aiplatform-v1, https://github.com/modelcontextprotocol/rust-sdk, https://github.com/modelcontextprotocol/rust-sdk/blob/main/docs/OAUTH_SUPPORT.md, https://github.com/a2aproject/a2a-rs, https://github.com/a2ui-project/a2ui, https://github.com/zavora-ai/adk-rust, https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0, https://github.com/open-telemetry/opentelemetry-rust, https://crates.io/crates/tokio-tungstenite, https://crates.io/crates/jsonwebtoken, https://github.com/0xPlaygrounds/rig, https://crates.io/crates/jsonschema]
links: [ma-backend-sdk-landscape, ma-backend-stack-options, ma-backend-sdk-go, rt-gpt-live-sideband, rt-gemini-ephemeral-tokens, proto-mcp-overview, proto-a2a-overview]
---
# Écosystème Rust (vérifié par deux fact-checks le 2026-10-27)

Rust couvre bien les **protocoles** (MCP, A2A, Temporal) avec des SDK officiels, mais **pas le chemin voix** : aucun SDK officiel OpenAI ni Gemini.

**GPT-Live — le trou principal**
- Aucun SDK OpenAI officiel en Rust. La page Libraries ne cite `async-openai` (64bit) que dans « Community libraries » (« OpenAI does not verify… »).
- `async-openai` 0.42.2 (2026-10-10) : `realtime.rs` ne couvre que `/realtime/calls` (accept, hangup, refer, reject) et `/realtime/client_secrets`. Rien sur `/live/sessions` ni sur la délégation.
- `oai-rt-rs` 0.5.1 (2026-09-14, communautaire, MIT, **un seul publieur**) a un module `live` : `LiveClient::create_webrtc` (SDP), `attach(session_id)`, fork, hangup, événements `session.delegation.created`, `thinking.append`, `commentary.append`, `response.item.create`. Calé sur la spec OpenAPI du 2026-09-11 : ne suit ni le changement cassant de la v3.86 d'openai-go (`Instructions` en union typée) ni le mode `decisions`. Trouvé par un seul des deux vérificateurs.
- `openapi.yaml` officiel : chemins `/live/sessions` (+ accept, fork, hangup, refer, reject, content) et 188 schémas `Live*` (`LiveSidebandClientEvent`, `LiveSidebandServerEvent`, `LiveDelegationCreated`…). **`/attach` n'est pas un chemin** (cité seulement dans une description) : typify génère les types, pas le transport WSS.
- Ordre de grandeur à reproduire : package `live` d'openai-go ≈ 560 Ko hors tests, avec tests de contrat (`decisions_contract_test`, `transport_contract_test`, `sideband_unknown_event_test`).

**Gemini** : pas de SDK Developer API officiel. `google-cloud-aiplatform-v1` 1.18.0 (Vertex) n'a pas `auth_tokens` ; `gemini-rust` 2.1.0, `gemini-live` 0.1.9, `genai` 0.7.1 sont communautaires, sans `auth_tokens`. Jetons éphémères = appel REST `POST v1beta/auth_tokens` à écrire.

**MCP — `rmcp` 3.8.0 (2026-10-26, officiel)** : spec 2026-07-28, compatible 2025-11-25. OAuth client complet (OAuth 2.1, PKCE, RFC 8707, RFC 9728, RFC 8414 + OIDC, DCR, CIMD, montée de scope sur 403, refresh).

**A2A — `a2aproject/a2a-rs` (officiel, A2A v1)** : JSON-RPC, REST, gRPC (tonic), SLIMRPC, serveur axum, MSRV 1.85. Crates `a2a-lf` 0.4.2, `a2a-client-lf` 0.2.9, `a2a-server-lf` 0.5.3 (2026-10-16), **toutes en 0.x** ; 98 étoiles (a2a-go est en v2.7.0).

**A2UI** : pas de Rust dans `a2ui-project/a2ui` ; schémas `specification/v0_9`, `v0_9_1`, `v1_0` et `conformance/` utilisables avec `jsonschema` 0.60.2 (2026-10-26).

**Agents** : tous communautaires. `rig-core` 0.45.0 (0.46.0-rc.1 le 2026-10-23, ≈ 9 000 étoiles). `adk-rust` 2.3.0 (zavora-ai, pas Google) : rmcp 3.1, profil A2UI « draft-compatible v0.9 », `adk-realtime` = ancienne `/v1/realtime` + Gemini Live, pas `/live` ; main déjà en 3.0.0 (rupture imminente).

**Temporal** : `temporalio-sdk` GA 1.0.0 (2026-09-04), 1.1.0 (2026-10-06).

**Socle** : axum 0.8.9 (547 M téléchargements), tokio-tungstenite 0.30.0 (329 M), reqwest 0.13.5 (842 M). OTel `opentelemetry` 0.33.1 : Logs/Metrics Stable, **Traces et Context Beta** ; `GEN_AI_OPERATION_NAME` présent. Auth : `jsonwebtoken` 11.1.0 (2026-09-16), `openidconnect` 4.0.1 (2025-07-06, sans release depuis 15 mois).

⚠️ Pièges
- Non prouvé : module `jwk` de jsonwebtoken, support JSON Schema 2020-12 de `jsonschema`, SSE dans a2a-rs (les deux vérificateurs divergent), crates `googleapis-tonic-*` exposant `auth_tokens`, BDD `cucumber-rs` + `testcontainers-rs`, SDK AG-UI Rust.
- Absence de crate `/live` démontrée seulement sur les crates examinées, pas sur tout crates.io.
