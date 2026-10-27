---
id: ma-backend-sdk-landscape
title: SDK backend par langage — matrice (vérifiée le 2026-10-27)
tags: [multi-agent, backend, sdk, versions, rust, gpt-live, mcp, a2a, a2ui]
status: verified
updated: 2026-10-27
sources: [https://github.com/openai/openai-go/tree/main/live, https://crates.io/crates/oai-rt-rs, https://pypi.org/pypi/openai/json, https://registry.npmjs.org/openai, https://pub.dev/packages/openai_dart, https://github.com/a2ui-project/a2ui, https://developers.openai.com/api/docs/guides/live-delegation]
links: [ma-backend-sdk-go, ma-backend-sdk-rust, ma-backend-sdk-python, ma-backend-sdk-typescript, ma-backend-sdk-dart, ma-backend-stack-options, rt-gpt-live-sideband, rt-ephemeral-keys]
---
# Matrice des SDK backend (versions au 2026-10-27, vérifiées dans le code publié)

| Brique | Go | Python | TypeScript | Dart | Rust |
|---|---|---|---|---|---|
| GPT-Live : création + sideband | openai-go v3.88.0 (officiel) | openai 3.39.0 (officiel) | openai 7.45.0 (officiel) | openai_dart 11.0.1 (communautaire) | **aucun officiel** ; oai-rt-rs 0.5.1 (communautaire) |
| Gemini : jetons éphémères | genai v1.76.0 (expérimental) | google-genai 2.33.0 (expérimental) | @google/genai 2.31.0 | googleai_dart 13.0.0 (communautaire) | **aucun** (REST à la main) |
| MCP 2026-07-28 | go-sdk v1.8.0 | mcp 2.3.0 | @modelcontextprotocol/client 2.4.0 | mcp_dart 2.4.3 (auto-déclaré) | rmcp 3.8.0 |
| A2A v1.0 | a2a-go/v2 v2.7.0 | a2a-sdk 1.2.3 | @a2a-js/sdk 1.3.0 | **aucun** (a2a 4.3.1 = v0.3) | a2a-lf 0.4.2 (officiel, 0.x) |
| A2UI côté agent | **aucun SDK** officiel | a2ui-agent-sdk 0.9.0 | @a2ui/agent 0.0.2 | a2ui_core 0.3.0 (validation) | **aucun SDK** |
| Framework d'agents | ADK Go v2.6.0 | google-adk 2.13.0 | @openai/agents 0.21.0 | aucun | rig-core 0.45.0 (communautaire) |
| Temporal | sdk-go v1.50.0 | temporalio 1.34.0 | @temporalio 1.24.0 | **aucun SDK** | temporalio-sdk 1.1.0 (GA) |

Détails, pièges et URLs : [[ma-backend-sdk-go]], [[ma-backend-sdk-python]], [[ma-backend-sdk-typescript]], [[ma-backend-sdk-dart]], [[ma-backend-sdk-rust]].

**Faits transverses (API, pas SDK) :**
- GPT-Live n'a pas de client secret : `resources/live` des SDK ne contient ni `client_secret` ni `ephemeral`. Le relais SDP serveur est obligatoire ([[rt-ephemeral-keys]]).
- `session.delegation.created` ne contient pas l'énoncé de l'utilisateur : il faut tamponner `input_transcript.delta` / `output_transcript.delta` ([[rt-gpt-live-sideband]]).
- `thinking.append` / `commentary.append` : 500 tokens maximum par envoi. Tout envoi annule **tous** les accusés automatiques en attente de la session, y compris ceux d'autres délégations.
- Interrompre la voix n'annule pas le travail backend : confirmer l'annulation avant de l'annoncer.
- Les SDK openai (Python, Go) exposent un **troisième mode de délégation `decisions`** (`target: client | responses | decisions`), absent de la base avant cette date.
- Aucun framework haut niveau ne gère la délégation `client` : `openai-agents` (Python 0.24, JS 0.21) cible l'ancienne API `/v1/realtime` ; Pydantic AI 2.62 refuse `client`.
- A2UI : v1.0 est un *release candidate* ; v0.9.1 est la version de production (a2ui.org). genui 0.10.4 dépend de `a2ui_core ^0.1.0` (alors que 0.3.0 existe).
- MCP 2026-07-28 en HTTP n'est négocié que si le **serveur** est sans état (go-sdk : `StreamableHTTPOptions.Stateless = true`) ; sinon repli en 2025-11-25.

⚠️ Pièges
- Ces SDK sortent plusieurs versions par semaine (openai-go : v3.83 → v3.88 en 6 jours). Épingler et re-vérifier avant tout usage.
