---
id: rt-gpt-live-delegation
title: GPT-Live — délégation (responses vs client) et tool calling
tags: [openai, gpt-live, tools, function-calling, delegation, orchestrator, multi-agent]
status: verified
updated: 2026-10-30
sources: [https://developers.openai.com/api/docs/guides/live-delegation.md, https://developers.openai.com/api/docs/guides/live, https://developers.openai.com/api/docs/guides/live-conversations]
links: [rt-gpt-live-delegation-latency, rt-gpt-live-lifecycle, rt-gpt-live-sideband, rt-gpt-live-session-config, rt-tool-calling-voice, ma-target-architecture, ma-filler-acknowledgements, ma-real-tool-results, ma-realtime-handoff-limits, proj-avw-risks, proj-avw-voice-runners]
---
# GPT-Live : délégation et outils (3 modes)

`gpt-live-1` gère la conversation parlée en full duplex mais n'appelle pas les outils lui-même : il **délègue** lookups, outils et tâches à un backend. Le mode (`delegation.type`) est fixé à la création ; en changer impose une nouvelle session. Il existe **trois modes** (vérifié dans le SDK openai-go v3.90.0 et par essais, 2026-10-29) : `client` (**défaut si omis**), `responses` et `decisions`. Toujours le fixer explicitement.

| | `"responses"` | `"client"` | `"decisions"` |
|---|---|---|---|
| Backend | Modèle Responses géré par OpenAI | Votre agent / orchestrateur | Non essayé |
| Événement entrant | `session.delegation.created` (`target: "responses"`, `response_id`) puis `response.event` | `session.delegation.created` (`delegation.id`, `target: "client"`, `offset_ms`) **sans les mots de l'utilisateur** | Événements `decision.*` côté client |

- **`decisions`** (nouveau, non essayé) : paramètres `{"type":"decisions","decisions":{…}}` ; défaut `acknowledgement_delay_ms` de 400.
- **Événements vus dans le SDK, non exploités** : `info`, `response.event`, `decision.*`, `session.output_audio.fixture.{playing,played}`.
- **Le modèle ne délègue que si les `instructions` le demandent** (essai en mode `client` : sans consigne il répond seul). Mesures : [[rt-gpt-live-delegation-latency]].
- **Frontend non fiable :** `session.client.data_channel` (`allowed_client_events` / `allowed_server_events`) restreint ce que le client envoie ou reçoit (existe dans le SDK, non testé). Sans cela, le client reçoit aussi sur `oai-events` les événements du sideband, dont `session.delegation.created`.

## Mode `responses`
`delegation.responses` : `model` (seul champ requis, chaîne libre sans énumération dans le SDK ; `gpt-6-luna` accepté et testé le 2026-10-29), `instructions`, `tools`, `tool_choice` (`auto` | `required` | `none` | fonction nommée), `parallel_tool_calls`, `max_output_tokens` (≥ 16), `service_tier` (`priority` = Fast mode), `reasoning`, `text`.
- Outils hébergés (web search, file search, code interpreter, hosted shell, image generation) et appels MCP : exécutés côté OpenAI.
- **function, custom, computer, shell local, apply_patch** : exécutés par l'app. MCP : seulement `mcp_approval_request` → `mcp_approval_response`.
- Modèles visibles par la clé testée (`GET /v1/models`, 2026-10-29) : `gpt-live-1`, `gpt-live-transcribe`, `gpt-5.6-luna|sol|terra`, `gpt-6-astra|luna|sol`, `gpt-6.1-sol`. La liste dépend du compte : la relire.
- Les événements arrivent dans une enveloppe `response.event` (`delegation_id` + `event` imbriqué : `response.created`, `output_item.added`, `output_text.delta|done`, `completed` avec `usage`) ; les appels terminés se lisent dans le `response.output_item.done` imbriqué.
```json
{"type":"response.item.create","item":{"type":"function_call_output","call_id":"call_123","output":"{...}"}}
{"type":"response.create"}
```
Sans `response.create`, le backend ne reprend pas. Résultat manquant → `tool_outputs_required` (ou `function_call_outputs_required` s'il ne manque que des fonctions). Doublons et types incohérents rejetés.

## Mode `client` (orchestrateur maison)
- Contexte de la demande à reconstruire depuis `session.input_transcript.delta` / `session.output_transcript.delta`.
- Retour, chaque `content` ≤ 500 tokens avec un `event_id` unique :
  - `session.commentary.append` : à dire (le modèle peut paraphraser) ;
  - `session.thinking.append` : contexte silencieux ;
  - `session.instructions.append` : consignes globales (`delegation_id: null`).
- **Vérifié le 2026-10-29 (essai réel, mode `client`) :** `session.delegation.created` porte bien `offset_ms` (7 000 pour une phrase terminée vers 7 s : même timeline de session que les `start_ms`/`end_ms` des transcripts) ; un `commentary.append` est dit presque mot pour mot, **guillemets compris** (« Voici ce que je constate : « … » ») ; un premier commentaire générique, puis le commentaire fondé sur le résultat, sont dits dans cet ordre.
- Chacun est acquitté par `…appended` : l'accusé confirme l'injection, pas la diction. Un refus du fournisseur arrive en événement `error` portant le `client_event_id` de la commande ; un délai sans accusé ne prouve pas que la commande n'a pas été reçue : ne pas la renvoyer.
- **`delegation_id` est nullable** pour `session.commentary.append` (SDK openai-go v3.90.0, `live/live.go` : « Required, nullable. Set null for general session context, or use the ID from session.delegation.created »). Un commentaire à `delegation_id` nul s'adresse à la session, hors de toute délégation ; un identifiant non nul est refusé en mode `responses`. La commande est aussi rejetée tant qu'une fixture audio est active. `session.instructions.append` est acquittée par `session.instructions.appended`.
- ⚠️ **Non observé** : qu'un commentaire à `delegation_id` nul fasse effectivement parler le modèle hors délégation (seul le SDK le documente ; l'essai réel du 2026-10-30 n'est pas allé jusque-là).
- **Observé (un essai, 2026-10-30)** : un second énoncé de l'utilisateur prononcé pendant que le modèle disait son accusé (« Je m'en occupe, je regarde ») a bien créé une seconde délégation, environ 0,4 s après la fin de l'énoncé ; chaque délégation reste ouverte tant que son commentaire n'est pas acquitté côté application.
- `delegation.acknowledgement_delay_ms` (ex. 800) règle l'accusé vocal automatique. Tout `thinking.append` ou `commentary.append` (même à `content` vide) annule **tous** les accusés en attente de la session ([[ma-filler-acknowledgements]]).

## ⚠️ Pièges
- **Interrompre la parole n'annule pas le travail backend.** L'app bloque ou annule, confirme l'annulation, puis seulement l'annonce.
- Une réponse backend terminée ne signifie pas que l'utilisateur l'a entendue.
- `model`, voix, `instructions`, `audio` et mode de délégation sont fixés au démarrage ; `session.update` ne modifie que les réglages Responses ([[rt-gpt-live-session-config]]).
- Protocole distinct de l'API Realtime (`/v1/live/sessions`, pas `/v1/realtime`) : le runner `gpt-realtime-1.5` de [[proj-avw-voice-runners]] n'est pas réutilisable tel quel.
- Ne pas renvoyer de faux résultats `{"status":"ok"}` ([[proj-avw-risks]], [[ma-real-tool-results]]).
