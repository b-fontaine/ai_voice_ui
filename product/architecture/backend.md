---
id: p-ar-backend
title: Architecture du backend orchestrateur
area: architecture
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, knowledge:adr-0003-backend-go, knowledge:ma-backend-stack-recommendation, product/roadmap/backend-production-plan.md, knowledge:ma-backend-sdk-go, knowledge:rt-gpt-live-sideband, knowledge:rt-gpt-live-delegation]
links: [p-fn-risks-acceptance, p-fn-business-rules, p-ar-overview, p-ar-agents-protocols, p-ar-security, p-ar-replay, p-ar-quality, p-ar-stack, p-ar-stage-runtime, p-fn-requirements, p-fn-nfr, p-fn-dataset, p-rm-open-questions, pdr-0005-frozen-fictional-dataset, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, adr-0002-orchestrator-backend, adr-0003-backend-go, ma-backend-stack-recommendation, p-rm-backend-production-plan, ma-backend-sdk-go, proj-sk-backend, rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-gpt-live-session-config, rt-transcription, rt-ephemeral-keys, ma-filler-acknowledgements, ma-real-tool-results, genui-a2ui-security, genui-a2ui-messages, proto-a2a-overview, proto-a2a-task-lifecycle, proto-a2a-agent-card, ma-otel-genai-spans, genui-a2ui-overview, ma-target-architecture, rt-graceful-close, rt-latency, proto-mcp-dart-sdks, ma-where-to-run-agents, rt-gpt-live-overview]
tags: [backend, go, hexagonal, orchestrateur, a2a, a2ui, gpt-live, sideband]
---
# Architecture du backend orchestrateur

**En bref.** Le backend est le module Go hexagonal `backend/agent_orchestrator` décidé dans [adr-0003-backend-go] (appliqué au produit par [pdr-0011](../decisions/pdr-0011-adopt-knowledge-adrs.md)). Il crée la session voix, s'attache au sideband, planifie les tâches, interroge les agents spécialisés en A2A, valide l'A2UI contre le catalogue `genesis` et pousse le tout à l'app sur un canal unique (proposé : WSS maison ; ⚠️ Hypothèse non confirmée, alternative `genui_a2a` → Q-39). Les noms de messages A2UI de cette page sont ceux de v0.9, sous réserve de Q-03 (E3).

> Statut : **draft**. Le socle vient de [ma-backend-stack-recommendation] et [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) (plan de construction pensé pour un socle de production, écart suivi par Q-15 et Q-27) ; son **profil de déploiement pour la démo** est une proposition à valider.

## Modules (adapters + application)

| Module | Rôle | Exigences | Source |
|---|---|---|---|
| `voice-session` | `POST /voice/sessions` : reçoit l'offre SDP, appelle `client.Live.New` (`gpt-live-1`, délégation `client` proposée, à confirmer par SP-02 / Q-47, injectée par `voice.delegation_type` ; voix FR, instructions), renvoie l'answer SDP | NFR-09, FR-13 | [rt-gpt-live-webrtc-session], [ma-backend-sdk-go] |
| `sideband-supervisor` | `Sideband.Connect` par session ; transcripts ; `delegation.created` ; `commentary/thinking.append` ; `close → closed` | FR-02, FR-08, FR-13, FR-16 | [rt-gpt-live-sideband], [rt-gpt-live-lifecycle] |
| `orchestrator` | planifie la demande en tâches, route vers les agents, révision de tâche, annulation | FR-03, FR-07, FR-14, FR-16, FR-17 | [ma-target-architecture], [ma-real-tool-results] |
| `a2a-client` | appels A2A v1.0 vers les agents (`SendStreamingMessage`, `CancelTask`) | FR-03, NFR-03 | [proto-a2a-task-lifecycle], `a2a-go/v2` |
| `a2ui` | production ou assemblage A2UI, validation contre le catalogue `genesis`, ≤ N régénérations | FR-04, FR-07, NFR-02 | [genui-a2ui-security], [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 7 |
| `app-channel` | WSS vers l'app : A2UI, événements d'agents, transcript, état orbe ; reçoit les actions typées | FR-03, FR-05, FR-08 | [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 8 |
| `session-recorder` | journal serveur horodaté (copie de ce qui part sur l'app-channel) | FR-09, NFR-02, NFR-03 | [p-ar-replay](replay.md) |
| `agents/*` | agents spécialisés exposés en A2A, lisant le jeu de données figé | NFR-08 | [proto-a2a-agent-card] |

## Ports (hexagonal)

| Port | Implémentation MVP (proposée) | Pourquoi un port |
|---|---|---|
| `out.LiveProvider` | `openai-go/v3` ≥ v3.86, package `live` | package jeune, tests de contrat sur fixtures ([ma-backend-stack-recommendation] risque 2) |
| `out.AgentRuntime` | production A2UI en Go in-process | repli possible vers un sidecar Python `a2ui-agent-sdk` en A2A ([adr-0003-backend-go]) |
| `out.RemoteAgent` | client `a2a-go/v2` | agents internes aujourd'hui, agent tiers demain (écart E6) |
| `out.LlmText` | LLM texte de composition A2UI | fournisseur non choisi (voir Points ouverts) |
| `out.DatasetStore` | fichiers JSON figés, versionnés | NFR-08, [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) |
| `out.SessionJournal` | fichiers JSONL locaux | rejeu et mesure des NFR |
| `out.Observability` | OTel `gen_ai.*` | [ma-otel-genai-spans] |

## Orchestrateur : règles de comportement

1. **Une délégation = un plan** de tâches (Qualité, Voix du client, Livraison… cf. E1), lancées **en parallèle** pour tenir NFR-03.
2. Dès le plan connu, émettre l'activité des agents (rail) et un **squelette** de surface (`createSurface` + composants squelette, noms v0.9 selon Q-03) pour tenir NFR-02, sans attendre les données ([rt-latency] §5).
3. La voix reçoit (RG-04) un **commentaire générique** de progression puis le **vrai résumé** une fois les résultats reçus ; jamais d'hypothèse ([ma-filler-acknowledgements], [ma-real-tool-results]).
4. **Modifier sur place** (FR-07, FR-17, RG-06) : `updateComponents` / `updateDataModel` sur les `surfaceId` existants (noms v0.9 selon Q-03) ; un éventuel `deleteSurface` + `createSurface` dépend de Q-21 (E8) ([genui-a2ui-messages]).
5. **Révision de tâche** : chaque consigne en vigueur porte un numéro de révision ; les résultats d'une révision périmée sont jetés (FR-14, [ma-real-tool-results]).
6. **Stop / annule** (FR-16) : `CancelTask` sur les tâches A2A en vol, `deleteSurface` des surfaces inachevées, puis seulement confirmation vocale ([rt-gpt-live-delegation] pièges).
7. **Action utilisateur** (FR-08) : l'action typée « Bloquer la release » est routée vers l'agent Livraison ; le vrai résultat met à jour la checklist et produit le commentary vocal.
8. Demande hors catalogue : refus vocal avec une alternative (fiche §7, RG-07, RG-08).

## Session voix GPT-Live

- Délégation **`client`** (proposée, à confirmer par SP-02 / Q-47 ; paramètre injecté `voice.delegation_type`, fixé à la création de session) : l'orchestrateur reconstruit la demande depuis `session.input_transcript.delta` ([rt-gpt-live-delegation], [rt-transcription]).
- Voix FR (`brise` ou `sillage` au 2026-10-26, [rt-gpt-live-session-config]) : choix injecté par configuration ; voix à arbitrer (voir Points ouverts).
- `acknowledgement_delay_ms` et consigne de **répliques courtes** (parade « l'IA ne s'arrête pas », fiche §8, RG-27).
- Un seul propriétaire par `delegation.id` : le supervisor qui tient la WS sideband.
- Fermeture : `session.close`, attente de `session.closed`, timeout de garde ([rt-graceful-close]).

## Agents spécialisés en A2A

- Chaque agent publie une Agent Card (`/.well-known/agent-card.json`, skills, `capabilities.streaming`) ([proto-a2a-agent-card]).
- Résultats en **Artifacts** ; état suivi par `TaskState` ; annulation par `CancelTask` ([proto-a2a-task-lifecycle]).
- Ils lisent le **jeu de données fictif figé** ([p-fn-dataset](../functional/dataset.md)) : aucune connexion à Crashlytics ni aux stores (hors périmètre, fiche §3).
- Implémentation proposée : `a2a-go/v2` (v2.7.0 au 2026-10-27, [ma-backend-sdk-go]), un binaire ou une goroutine-serveur par agent.

## Configuration injectée

| Clé (proposition) | Exemple | Règle |
|---|---|---|
| `voice.model`, `voice.voice`, `voice.instructions_ref` | `gpt-live-1`, voix FR | jamais en dur (AGENTS.md §2) |
| `voice.delegation_type` | `client` (proposé, Q-47) | jamais en dur |
| `voice.ack_delay_ms` | à régler en répétition | NFR-01 |
| `a2ui.catalog_id`, `a2ui.version` | URI versionnée (Q-44) ; `v0.9` ⚠️ selon Q-03 / E3 | paramètre, jamais constante ; [genui-a2ui-overview] |
| `agents[]` | URL d'Agent Card par agent | E1 |
| `dataset.path`, `dataset.version` | jeu figé | NFR-08 |
| `limits.max_session_s`, `limits.budget` | plafond de coût | NFR-11 |
| `auth.*`, `cors.allowed_origins` | voir [p-ar-security](security.md) | AGENTS.md §2 |

## Profil de déploiement pour la démo (proposition)

Le socle générique prévoit Keycloak, Kong, Postgres, Temporal et SigNoz ([ma-backend-stack-recommendation]). Pour une démo de scène, l'assistant propose un **profil minimal** : orchestrateur + agents dans un même `docker compose` ou binaire, sans Temporal (pas de tâche longue), journal en fichiers, OTel optionnel. ⚠️ Hypothèse non confirmée : à arbitrer par le porteur ([Q-15](../roadmap/open-questions.md)).

## Contexte repris de `knowledge/` (transféré le 2026-10-28)

Passages propres au projet retirés des notes génériques lors du nettoyage de `knowledge/` ; ils décrivent le contexte d'origine, sans trancher les points ouverts ci-dessous.

| Origine (knowledge) | Contenu |
|---|---|
| [adr-0003-backend-go] (contexte d'origine) | Backend = module `backend/agent_orchestrator` de `septeo_saaster_kit`, hexagonal. Compétences confirmées par le porteur le 2026-10-27 : « L'équipe maîtrise tous les langages, y compris Rust, Go et Python ». `a2a-go/v2` prévu « en phase 2 » dans la stack d'origine (ce document l'utilise dès le MVP pour les agents, proposition). Risques hérités du kit à corriger dès le jour 0 : `ParseUnverified` et CORS `*` ([security.md](security.md)). Dépôt : Q-27 |
| [ma-backend-stack-recommendation] (passages retirés) | Stack, score du panel et schéma de production d'origine : [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) § « Socle de production d'origine » |
| [proj-sk-backend] | Cadrage d'origine : le backend Go du kit vu comme « ce que le backend Go offre à l'orchestrateur ». Les SDK agents Go exigent Go ≥ 1.26 et OTel ≥ v1.47, d'où un module séparé pour `backend/agent_orchestrator` |
| [rt-gpt-live-sideband] | L'orchestrateur backend attache le sideband et traite la délégation `client` ([rt-gpt-live-delegation]) ; outils, autorisations, règles métier et credentials restent côté serveur ; Flutter ne gère que l'audio et le rendu A2UI |
| [rt-gpt-live-delegation], [rt-gpt-live-overview] | En mode `client`, l'orchestrateur du produit joue l'agent délégué. La séparation « modèle voix = tour de parole / backend délégué = outils et logique métier » correspond au couple « agent vocal + orchestrateur » |
| [proto-mcp-dart-sdks] | Les clients MCP vivent dans l'orchestrateur backend ([ma-where-to-run-agents]) ; `mcp_dart` n'aurait de sens que pour un orchestrateur en Dart : non concerné (Go, [adr-0003-backend-go]) |
| [rt-ephemeral-keys] | Contrat `POST /voice/sessions {provider, agentProfile}` : [security.md](security.md) § « Contrat de la route de relais » |

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Profil de déploiement** démo vs socle `septeo_saaster_kit` complet (Keycloak, Kong, Postgres, Temporal) → Q-15, Q-55.
- **Hébergement** du backend pendant le talk : local (machine de démo) ou cloud → Q-15.
- **Topologie A2UI** : agents qui renvoient de l'A2UI (fiche §1) ou agents qui renvoient des données et un composeur central qui produit l'A2UI ([ma-target-architecture]) → Q-37.
- **Déterminisme de la composition** : LLM libre, LLM contraint par exemples, ou plans A2UI pré-écrits par acte (NFR-08 dit « seule la composition varie ») → Q-38. La parade R6 de la fiche § 8 (« exemples d'écrans attendus fournis à l'IA ») en dépend : forme et emplacement des exemples (prompt, fixtures, catalogue) à fixer avec Q-38 ([p-fn-risks-acceptance](../functional/risks-acceptance.md)).
- **LLM texte** de composition et son coût (NFR-11) → Q-17, Q-13.
- **Voix FR** (`brise` / `sillage`) et texte des instructions vocales → Q-26.
- **Mode de délégation** `client` vs `decisions` : non prouvé, à établir par SP-02 ([ma-backend-stack-recommendation]) → Q-47.
