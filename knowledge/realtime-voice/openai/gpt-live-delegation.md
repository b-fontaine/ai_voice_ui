---
id: rt-gpt-live-delegation
title: GPT-Live — délégation (responses vs client) et tool calling
tags: [openai, gpt-live, tools, function-calling, delegation, orchestrator, multi-agent]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-delegation.md, https://developers.openai.com/api/docs/guides/live, https://developers.openai.com/api/docs/guides/live-conversations]
links: [rt-gpt-live-lifecycle, rt-gpt-live-sideband, rt-gpt-live-session-config, rt-tool-calling-voice, ma-target-architecture, ma-filler-acknowledgements, ma-real-tool-results, ma-realtime-handoff-limits, proj-avw-risks, proj-avw-voice-runners]
---
# GPT-Live : délégation et outils

`gpt-live-1` (doc consultée le 2026-10-26) gère la conversation parlée en full duplex mais n'appelle pas les outils lui-même : il **délègue** lookups, outils et tâches à un backend. Le mode (`delegation.type`) est fixé à la création ; en changer impose une nouvelle session. La doc n'indique **aucun mode par défaut** : toujours le fixer explicitement.

| | `"responses"` | `"client"` |
|---|---|---|
| Backend | Modèle Responses géré par OpenAI | Notre agent / orchestrateur |
| Événement entrant | `session.delegation.created` (`target: "responses"`, `response_id`) puis `response.event` | `session.delegation.created` (`delegation.id`, `target: "client"`) **sans les mots de l'utilisateur** |

## Mode `responses`
`delegation.responses` : `model` (ex. `gpt-6-luna`, `gpt-6-sol`), `instructions`, `tools`, `tool_choice` (`auto` | `required` | `none` | fonction nommée), `parallel_tool_calls`, `max_output_tokens` (≥ 16), `service_tier` (`priority` = Fast mode), `reasoning`, `text`.
- Outils hébergés (web search, file search, code interpreter, hosted shell, image generation) et appels MCP : exécutés côté OpenAI.
- **function, custom, computer, shell local, apply_patch** : exécutés par l'app. MCP : seulement `mcp_approval_request` → `mcp_approval_response`.
- Les événements arrivent dans une enveloppe `response.event` (`delegation_id` + `event` imbriqué) ; les appels terminés se lisent dans le `response.output_item.done` imbriqué.
```json
{"type":"response.item.create","item":{"type":"function_call_output","call_id":"call_123","output":"{...}"}}
{"type":"response.create"}
```
Sans `response.create`, le backend ne reprend pas. Résultat manquant → `tool_outputs_required` (ou `function_call_outputs_required` s'il ne manque que des fonctions). Doublons et types incohérents rejetés.

## Mode `client` (notre orchestrateur)
- Contexte de la demande à reconstruire depuis `session.input_transcript.delta` / `session.output_transcript.delta`.
- Retour, chaque `content` ≤ 500 tokens avec un `event_id` unique :
  - `session.commentary.append` : à dire (le modèle peut paraphraser) ;
  - `session.thinking.append` : contexte silencieux ;
  - `session.instructions.append` : consignes globales (`delegation_id: null`).
- Chacun est acquitté par `…appended` : l'accusé confirme l'injection, pas la diction.
- `delegation.acknowledgement_delay_ms` (ex. 800) règle l'accusé vocal automatique. Tout `thinking.append` ou `commentary.append` (même à `content` vide) annule **tous** les accusés en attente de la session ([[ma-filler-acknowledgements]]).

## ⚠️ Pièges
- **Interrompre la parole n'annule pas le travail backend.** L'app bloque ou annule, confirme l'annulation, puis seulement l'annonce.
- Une réponse backend terminée ne signifie pas que l'utilisateur l'a entendue.
- `model`, voix, `instructions`, `audio` et mode de délégation sont fixés au démarrage ; `session.update` ne modifie que les réglages Responses ([[rt-gpt-live-session-config]]).
- Protocole distinct de l'API Realtime (`/v1/live/sessions`, pas `/v1/realtime`) : le runner `gpt-realtime-1.5` de [[proj-avw-voice-runners]] n'est pas réutilisable tel quel.
- Ne pas renvoyer de faux résultats `{"status":"ok"}` ([[proj-avw-risks]], [[ma-real-tool-results]]).
