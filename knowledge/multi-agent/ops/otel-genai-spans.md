---
id: ma-otel-genai-spans
title: Observabilité — conventions sémantiques OpenTelemetry GenAI
tags: [multi-agent, observability, opentelemetry, tracing]
status: verified
updated: 2026-10-28
sources: [https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-agent-spans.md, https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/, https://pub.dev/packages/opentelemetry]
links: [ma-voice-agent-evals, ma-mcp-security, ma-target-architecture]
---
# Tracer chaque saut avec les spans `gen_ai.*`

Les conventions GenAI ont **déménagé** dans le dépôt `open-telemetry/semantic-conventions-genai` (l'ancienne page opentelemetry.io n'est plus qu'un avis « Moved »). Tout y est encore au statut **Development** (2026-10-26) : les noms peuvent changer.

**Valeurs de `gen_ai.operation.name` utiles :**
- `invoke_agent`, `invoke_workflow`, `create_agent`, `plan`, `execute_tool`
- `chat`, `generate_content`, `retrieval`
- `*_memory`

| Span | Nom | Attributs clés |
|---|---|---|
| Invoke agent (client/internal) | `invoke_agent {gen_ai.agent.name}` | `gen_ai.agent.name`, `gen_ai.agent.id`, `gen_ai.agent.version`, `gen_ai.conversation.id` |
| Invoke workflow (internal) | `invoke_workflow {gen_ai.workflow.name}` | `gen_ai.workflow.name`, `gen_ai.conversation.id` |
| Execute tool | `execute_tool {gen_ai.tool.name}` | `gen_ai.tool.name`, `error.type` |
| Agent as a tool | `execute_tool {gen_ai.tool.name}`, kind `INTERNAL` | Pour un transfert d'agent fait **via un appel d'outil** (ADK `AgentTool`, OpenAI agents-as-tools) |

`gen_ai.tool.definitions` est en *opt-in*. Un modèle de spans MCP existe aussi dans le dépôt (`model/mcp/spans.yaml`).

**Mapping recommandé pour un orchestrateur voix (opinion) :**
- Une trace par session vocale : `gen_ai.conversation.id` = id de session GPT-Live ou Gemini.
- Une délégation = `invoke_agent orchestrator`, qui contient :
  - `execute_tool` pour chaque appel MCP ou A2A ;
  - `invoke_agent genui` pour l'agent GenUI.
- Attributs maison en plus : `delegation.id`, `operation.id`, latence jusqu'au premier audio.
- Propager le contexte W3C `traceparent` du client vers l'orchestrateur.

⚠️ Pièges
- Ne pas enregistrer audio ni transcriptions par défaut (données personnelles). Les contenus de messages sont en opt-in.
- Sur pub.dev, le package Dart `opentelemetry` (0.18.11+1) est **déprécié** au profit de `opentelemetry_wk`. Évaluer avant de choisir. Côté backend, préférer un SDK officiel (Python, Go ou Node).
