---
id: pdr-0037-voice-brise-delegated-instructions
title: "PDR-0037 — Voix « brise » (féminine, française) ; texte des instructions vocales délégué à l'assistant, optimisé pour la démo"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, knowledge:rt-gpt-live-session-config, product/sources/product-description.pdf#p11]
links: [pdr-0012-voice-provider-openai, pdr-0009-french-only, p-ar-backend, p-fn-business-rules, p-rm-backlog, p-rm-open-questions, rt-gpt-live-session-config, ma-filler-acknowledgements]
tags: [pdr, decision, voix, instructions, gpt-live]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0037 — Voix « brise », instructions par l'assistant

> **En bref.** L'IA parle avec la voix GPT-Live **`brise`** (féminine, française [rt-gpt-live-session-config]), injectée par configuration (`voice.voice`). Le **texte des instructions vocales** est délégué à l'assistant, optimisé pour la démo : réponses courtes, commentaire pendant la construction, en français. C'est un livrable du backlog, pas encore écrit. Tranche Q-26.

Part de l'assistant : consignation ; l'écriture des instructions lui est déléguée.

## Contexte
- Q-26 : quelle voix (`brise` ou `sillage` au 2026-10-26 [rt-gpt-live-session-config]) et quel texte d'instructions ?
- Fournisseur : `gpt-live-1` ([pdr-0012](pdr-0012-voice-provider-openai.md)).

## Hypothèses
- Aucune.

## Options
1. **`brise`** (retenue)
2. `sillage`

## Décision
- `voice.voice = brise`, valeur de configuration, jamais en dur (AGENTS.md § 2).
- L'assistant rédige les instructions vocales (`voice.instructions_ref`) selon ces règles : français uniquement ([pdr-0009](pdr-0009-french-only.md)) ; répliques courtes (RG-27) ; commentaire générique pendant la construction, sans hypothèse de résultat (RG-04, [ma-filler-acknowledgements]) ; refus avec alternative hors catalogue (RG-08).
- Livrable inscrit au backlog (EP-02, jalon J3 puis réglage J7).

## Raisons
- Parole du porteur (2026-10-29), Q-26 : « Brise, la voix féminine en fraçais. Pour le texte d'instructions vocales, je te laisse gérer. Optimise pour la démo ».

## Options écartées
- **`sillage`** : non retenue par le porteur.

## Conséquences
- [p-ar-backend](../architecture/backend.md) : voix fixée dans la configuration.
- [p-rm-backlog](../roadmap/backlog.md) : livrable « instructions vocales ».
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-26 tranchée.

## Réexaminer si
- La voix `brise` n'est plus proposée par GPT-Live, ou se comprend mal dans la sono.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Brise, la voix féminine en fraçais. Pour le texte d'instructions vocales, je te laisse gérer. Optimise pour la démo » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
