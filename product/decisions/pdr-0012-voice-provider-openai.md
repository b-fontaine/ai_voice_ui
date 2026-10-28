---
id: pdr-0012-voice-provider-openai
title: "PDR-0012 — Fournisseur voix de la démo : OpenAI gpt-live-1 (proposée)"
area: decisions
status: proposed
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p7, knowledge:rt-gpt-live-overview, knowledge:rt-provider-abstraction, knowledge:rt-ephemeral-keys, knowledge:rt-gemini-live-models, knowledge:rt-gemini-firebase-ai-dart, knowledge:adr-0003-backend-go]
links: [p-fn-nfr, p-ar-frontend, p-ar-backend, p-ar-security, p-ar-stack, p-rm-spikes, p-rm-open-questions, pdr-0002-desktop-platform, pdr-0009-french-only, pdr-0011-adopt-knowledge-adrs, rt-gpt-live-overview, rt-gpt-live-delegation, rt-gpt-live-sideband, rt-provider-abstraction, rt-ephemeral-keys, rt-gemini-live-models, rt-gemini-firebase-ai-dart, rt-gemini-ephemeral-tokens, rt-barge-in, adr-0002-orchestrator-backend, adr-0003-backend-go]
tags: [pdr, decision, voice, openai, gpt-live, gemini, proposed]
decision_status: proposée
decided_on: 2026-10-28
decided_by: "En attente — Benoît FONTAINE (porteur) ; proposée par l'assistant"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0012 — Fournisseur voix : OpenAI `gpt-live-1` (proposée)

> **En bref.** La fiche ne nomme pas le fournisseur voix, mais NFR-09 et NFR-11 parlent d'OpenAI. L'assistant propose de retenir `gpt-live-1` pour la démo, en gardant le port `VoiceSession` pour pouvoir basculer vers Gemini Live. **Décision attendue du porteur.** `decided_on` est la date de proposition.

Part de l'assistant : proposition et argumentaire ; aucune décision prise.

## Contexte
- Fiche § 5 (p. 7) : NFR-09 « Aucune clé **OpenAI** dans l'app ; jeton éphémère fourni par le backend » ; NFR-11 « Coût […] connu et plafonné », mesuré par le « Tableau de bord d'usage **OpenAI** ». Le choix d'OpenAI y est implicite.
- AGENTS.md : l'agent vocal est « OpenAI `gpt-live-1` en WebRTC, ou Gemini Live via Firebase AI Logic ».
- [adr-0003-backend-go] retient `openai-go/v3` (Live et sideband) **et** `genai` côté backend.

## Hypothèses
- ⚠️ Hypothèse non confirmée : le porteur veut OpenAI pour la démo (implicite dans NFR-09/NFR-11) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-11).
- ⚠️ Hypothèse non confirmée : qualité du français et tenue du barge-in de `gpt-live-1` en salle bruyante ([pdr-0009-french-only](pdr-0009-french-only.md), FR-13…FR-18) → [p-rm-spikes](../roadmap/spikes.md).
- ⚠️ Écart de vocabulaire : NFR-09 parle de « jeton éphémère » ; pour `gpt-live-1`, la base knowledge ne documente **aucun** client secret, seulement un relais SDP par le backend [rt-ephemeral-keys]. L'exigence de sécurité reste tenue, le mécanisme diffère.

## Options
1. **OpenAI `gpt-live-1` en WebRTC, relais SDP par le backend** (proposée).
2. Gemini Live direct (`gemini-3.8-live`, WebSocket + jeton éphémère) [rt-gemini-live-models], [rt-gemini-ephemeral-tokens].
3. Gemini Live via Firebase AI Logic (`firebase_ai`) [rt-gemini-firebase-ai-dart].

## Décision
**Proposée, non décidée** : `gpt-live-1` comme fournisseur voix de la démo, derrière le port `VoiceSession` [rt-provider-abstraction] ; adaptateur `GptLiveWebRtcSession`. La configuration (modèle, voix, langue) est injectée.

## Raisons
- **Fiche** : NFR-09 et NFR-11 sont écrits pour OpenAI.
- **Modèle** : `gpt-live-1` est full-duplex et délègue raisonnement et outils à un backend ; cette séparation correspond au couple agent vocal + orchestrateur backend [rt-gpt-live-overview], [rt-gpt-live-delegation], [adr-0002-orchestrator-backend].
- **Coût** : 0,05 $/min facturé à la seconde (relevé du 2026-10-26), backend facturé à part [rt-gpt-live-overview] ; utile pour NFR-11.
- **Sécurité** : la clé reste côté backend (relais SDP), le backend peut s'attacher en sideband [rt-ephemeral-keys], [rt-gpt-live-sideband].
- **Desktop** : la voie Firebase n'a ni Windows ni Linux [rt-provider-abstraction], ce qui fragilise le secours Windows ([pdr-0002-desktop-platform](pdr-0002-desktop-platform.md)).

## Options écartées
Aucune option n'est écartée tant que le porteur n'a pas décidé. Points faibles relevés par l'assistant :
- **Gemini via Firebase** : pas de Windows ni de Linux ; `gemini-3.8-live` absent de Firebase AI Logic au 2026-10-20 [rt-gemini-live-models].
- **Gemini direct** : viable sur desktop avec jeton éphémère ; reste l'alternative si le spike `gpt-live-1` échoue.

## Conséquences
- **Architecture** : port `VoiceSession` côté app (`start`, `stop` distinct de `dispose`, une seule source micro) [rt-provider-abstraction] ; endpoint backend de création de session ; adaptateur Live derrière un port côté Go [adr-0003-backend-go] → [p-ar-frontend](../architecture/frontend.md), [p-ar-backend](../architecture/backend.md).
- **Barge-in** : FR-13 à FR-20 dépendent des signaux d'interruption du fournisseur [rt-barge-in].
- **Coût** : tableau de bord d'usage OpenAI et plafond (NFR-11) → [p-ar-stage-runtime](../architecture/stage-runtime.md).
- **Roadmap** : spike voix FR sur la machine de démo avant de figer → [p-rm-spikes](../roadmap/spikes.md).

## Réexaminer si
- Le porteur choisit Gemini Live : ce PDR passe à « abandonnée » et un nouveau PDR consigne le choix.
- Le spike montre un barge-in ou une compréhension du français insuffisants.
- OpenAI publie des jetons éphémères pour Live, ou change ses tarifs.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Proposée, d'après NFR-09/NFR-11 et la base knowledge | Assistant |
| — | Décision attendue | Benoît FONTAINE (porteur) |

Pas d'archive brute.
