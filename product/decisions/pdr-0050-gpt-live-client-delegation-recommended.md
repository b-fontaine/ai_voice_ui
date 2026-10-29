---
id: pdr-0050-gpt-live-client-delegation-recommended
title: "PDR-0050 — Mode de délégation GPT-Live : `client`"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/002-sp-02-gpt-live-sdp-relay/notes-s1.md, knowledge:rt-gpt-live-delegation, knowledge:rt-gpt-live-lifecycle]
links: [p-rm-open-questions, p-rm-spikes, p-ar-backend, p-ar-agents-protocols, pdr-0012-voice-provider-openai, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0037-voice-brise-delegated-instructions, adr-0002-orchestrator-backend, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-gpt-live-webrtc-session, rt-gpt-live-sideband]
tags: [pdr, decision, voix, gpt-live, delegation]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0050 — Mode de délégation GPT-Live : `client`

> **En bref.** Tranche Q-47. Le spike SP-02 (2026-10-29) a établi **trois** modes de délégation (`client`, `responses`, `decisions`), mesuré `client` et `responses`. Retenu : `client` : l'orchestrateur du backend reçoit la demande et renvoie les vrais résultats des agents A2A.

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- Q-47 ([p-rm-open-questions](../roadmap/open-questions.md)) : quel mode de délégation GPT-Live ? Son libellé d'origine (« `client` ou `decisions` ») était incomplet : la doc du SDK `openai-go/v3` définit trois modes (`client` par défaut, `responses`, `decisions`) ([rt-gpt-live-delegation], `notes-s1.md` § 2).
- Contraintes : agents A2A réels, chacun producteur de son A2UI ([pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md)) ; orchestrateur côté backend ([adr-0002-orchestrator-backend]) ; résultats d'outils renvoyés au modèle = vrais résultats (AGENTS.md § 2).
- Mesures SP-02 (essais réels `gpt-live-1`, 2026-10-29) :

| Mode | Observé |
|---|---|
| `client` | le modèle ne délègue que si les instructions l'exigent ; `session.delegation.created` arrive 1,0 s après la fin de la parole, **sans texte de l'utilisateur** (à reconstruire depuis les transcripts) ; `session.commentary.append` du backend acquitté en 0,7 s, dit par l'IA 0,6 s après la délégation, paraphrasé |
| `responses` | `gpt-6-luna` accepté ; premier token 2,3 s après la délégation ; la voix dit « OK, je regarde. » puis la réponse ; raisonnement **hébergé chez OpenAI** ; outils `function` exécutés par l'app ou le backend |
| `decisions` | nouveau, **non essayé** |

Détails : [rt-gpt-live-delegation], [rt-gpt-live-lifecycle], [rt-gpt-live-sideband].

## Hypothèses
- ✅ Les modes `client` et `responses` fonctionnent avec `gpt-live-1` (SP-02).
- ⚠️ Hypothèse non confirmée : le mode `decisions` n'a pas été essayé ; rien n'établit qu'il ne conviendrait pas (non bloquant : Q-47 tranchée ; à vérifier si le besoin apparaît, voir « Réexaminer si »).
- ⚠️ Hypothèse non confirmée : des instructions vocales ([pdr-0037](pdr-0037-voice-brise-delegated-instructions.md)) suffisent à faire déléguer le modèle à chaque demande utile en mode `client` (observé sur les essais de SP-02 seulement) ; à vérifier en J2 sur la chaîne réelle (Q-47 tranchée, voir « Réexaminer si »).

## Options
1. **`client`** (retenue) : le backend reçoit `delegation.created` en sideband, reconstruit la demande depuis les transcripts, délègue à l'orchestrateur, renvoie le commentary.
2. **`responses`** : un modèle de la famille Responses raisonne chez OpenAI ; seuls des outils `function`/`web_search` y sont déclarés.
3. **`decisions`** : mode nouveau du SDK, non essayé.

## Décision
**Décision** : `voice.delegation_type = client`, injecté par configuration (jamais en dur, AGENTS.md § 2) et fixé à la création de session.

## Raisons
- L'orchestrateur maison planifie, route vers les agents A2A et renvoie des résultats réels ([pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md)) ; seul `client` y mène directement.
- `responses` fonctionne, mais le raisonnement part chez OpenAI et ne passe par nos agents que via des outils `function` à écrire.
- `decisions` n'est pas prouvé ; l'essayer coûterait du temps sur un J1 de 2 jours.

## Options écartées
- `responses` : voir ci-dessus ; reste un repli si le texte de la demande doit être garanti.
- `decisions` : non essayé (⚠️ ci-dessus).

## Conséquences
- [p-ar-backend](../architecture/backend.md) : la délégation `client` reste le paramètre par défaut ; le texte de la demande se reconstruit depuis `session.input_transcript.delta`.
- [p-ar-agents-protocols](../architecture/agents-protocols.md) : séquence de délégation inchangée.
- Décision acquise le 2026-10-29 : elle débloque J2 (Q-47 tranchée).

## Réexaminer si
- les outils `function` en `responses` suffisent à appeler nos agents sans perte de contrôle ;
- `decisions` s'avère adapté à l'orchestration ;
- le modèle ne délègue pas de façon fiable en `client` malgré les instructions.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Proposée, après SP-02 (aucune parole du porteur) | Assistant |
| 2026-10-29 | Acceptée. Le porteur a répondu « Tes recommandations me conviennent. » (conversation du 2026-10-29), après que l'assistant lui a présenté un tableau récapitulant ses trois recommandations (Q-47 → pdr-0050, Q-43 → pdr-0051, Q-53 → pdr-0052). Tranche Q-47. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
