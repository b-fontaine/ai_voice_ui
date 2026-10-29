---
id: rt-gpt-live-delegation-latency
title: GPT-Live — délégation mesurée (délais, paraphrase, modes client et responses)
tags: [openai, gpt-live, delegation, latency, measurement, tools]
status: verified
updated: 2026-10-29
sources: [https://developers.openai.com/api/docs/guides/live-delegation.md, https://github.com/openai/openai-go/tree/main/live]
links: [rt-gpt-live-delegation, rt-gpt-live-lifecycle, ma-filler-acknowledgements, rt-latency]
---
# GPT-Live : délégation, ce qui a été mesuré

Essais réels du 2026-10-29 sur `gpt-live-1` (openai-go/v3 v3.90.0, relais SDP Go, client pion puis navigateur). Un seul essai par cas : ordres de grandeur, pas des garanties. Mode d'emploi des modes : [[rt-gpt-live-delegation]].

## Mode `client`
- Le modèle **ne délègue que si les `instructions` le demandent**. Sans consigne, il a répondu seul (« Je n'ai pas accès à l'état de tes releases »).
- Avec consigne : `session.delegation.created` arrive **1,0 s après la fin de la parole** de l'utilisateur. Il ne contient que `delegation.id`, `target` et `offset_ms` : le texte de la demande est à reconstruire depuis `session.input_transcript.delta`.
- `session.commentary.append` envoyé par le backend est acquitté (`…appended`) en **0,7 s**. L'IA le dit **0,6 s** après la délégation, en le **paraphrasant** (envoyé « Je regarde, un instant. », dit « Je vérifie, un instant. »).

## Mode `responses` (backend `gpt-6-luna`)
- `session.delegation.created` porte en plus `delegation.response_id`.
- Flux `response.event` : `response.created`, `response.output_item.added`, `response.output_text.delta`, `response.output_text.done`, `response.completed` (avec `usage`).
- **Premier token texte 2,3 s** après `delegation.created`. Un appel : 761 tokens en entrée, 94 en sortie (dont 65 de raisonnement).
- La voix dit d'abord « OK, je regarde. » **0,4 s** après la délégation (accusé automatique), puis la réponse.

## Enseignements
- Entre la fin de parole et le premier son utile, compter environ 1 à 1,6 s avant tout accusé : prévoir un indicateur visuel dès `session.delegation.created` ([[ma-filler-acknowledgements]]).
- Une phrase passée en `commentary.append` n'est jamais garantie mot pour mot ; ne pas s'appuyer sur sa formulation exacte.

## ⚠️ Pièges
- Mesures non répétées, une langue (français), une machine, un réseau : à refaire avant de dimensionner un budget de latence ([[rt-latency]]).
- Le mode `decisions` n'a pas été essayé.
