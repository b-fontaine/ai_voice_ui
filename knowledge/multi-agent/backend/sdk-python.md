---
id: ma-backend-sdk-python
title: SDK Python pour l'orchestrateur — faits vérifiés (2026-10-27)
tags: [backend, python, sdk, gpt-live, gemini, mcp, a2a, a2ui, adk]
status: verified
updated: 2026-10-27
sources: [https://pypi.org/pypi/openai/json, https://pypi.org/pypi/openai-agents/json, https://pypi.org/pypi/pydantic-ai-slim/json, https://pypi.org/pypi/google-adk/json, https://pypi.org/pypi/a2a-sdk/json, https://pypi.org/pypi/mcp/json, https://pypi.org/pypi/a2ui-agent-sdk/json, https://pypi.org/pypi/a2ui-adk/json, https://pypi.org/pypi/temporalio/json, https://pypi.org/pypi/google-genai/json, https://adk.dev/integrations/a2ui/]
links: [ma-backend-sdk-landscape, ma-adk-collaboration-modes, genui-a2ui-security, rt-gemini-ephemeral-tokens]
---
# Écosystème Python (wheels inspectées le 2026-10-27)

**GPT-Live — `openai` 3.39.0 (2026-10-26)** : `client.live.create` (POST `/live/sessions`, transport webrtc + sdp), `live.sideband.connect(session_id=…)` (reconnexion, `max_retries=5`, file d'envoi), `live.sessions.accept|fork|hangup|refer|reject`. Événements sideband typés depuis v3.35.0 (2026-10-17). Mode `decisions` présent (`DecisionsDelegationConfig`).
- `openai-agents` 0.24.0 : **pas de GPT-Live** (`/v1/realtime` uniquement).
- `pydantic-ai` 2.62.0 : gpt-live-1 en délégation `responses` seulement ; `client` → erreur.

**Gemini — `google-genai` 2.33.0** : `client.auth_tokens.create` marqué « [Experimental] », docstring « Support in v1alpha only » (`HttpOptions(api_version='v1alpha')`), alors que la doc web dit v1beta.

**Agents — `google-adk` 2.13.0 (2026-10-23, Python ≥ 3.11)** : modules a2a, live, telemetry, workflow, mcp_tool ; `AgentMode.SINGLE_TURN`, `AgentTool`. Contraintes : OTel `>=1.39,<=1.44`, `a2a-sdk <2`, `mcp <3` ; extras `[openai]`, `[extensions]`, `[all]` → `openai <3`.

**A2UI** : `a2ui-agent-sdk` 0.9.0 (`A2uiGenerator`, `CatalogConfig`, `validate_payload`, `ComponentPruningTransformer`) sur `a2ui-core` 0.4 (V0_8, V0_9, V0_9_1, V1_0). `a2ui-adk` 0.1.0 (`SendA2uiToClientToolset`). DataPart A2A `application/json+a2ui`.

**Protocoles** : `a2a-sdk` 1.2.3 (A2A 1.0 ; en-tête absent = 0.3). `mcp` 2.3.0 : 2026-07-28 dans le code (SEP-2575 `subscriptions/listen`, sampling déprécié SEP-2577). AG-UI : `ag-ui-protocol` 1.0.0, `ag-ui-adk` 0.11.0.

**Temporal — `temporalio` 1.34.0 (2026-09-30)** : contribs `google_adk_agents`, `openai_agents`, `google_genai`, `opentelemetry`.

⚠️ Pièges
- **Conflits bloquants** : `temporalio[google-adk]` et `[openai-agents]` imposent `mcp<2` ; les extras openai d'ADK imposent `openai<3` alors que GPT-Live exige openai 3.x. N'installer ADK qu'avec `[a2a]`/`[mcp]`.
- Fenêtre OTel réelle 1.43–1.44 (instrumentation google-genai 1.3b0 exige `~=1.43`).
- a2ui-adk 0.1, a2ui-agent-sdk 0.9 : pré-1.0, épingler.
