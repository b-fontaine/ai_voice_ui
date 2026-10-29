---
id: p-ar-backend
title: Architecture du backend orchestrateur
area: architecture
status: draft
updated: 2026-10-29
sources: [specs/004-j2-orchestrator-quality-agent/plan.md, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, knowledge:adr-0003-backend-go, knowledge:ma-backend-stack-recommendation, product/roadmap/backend-production-plan.md, knowledge:ma-backend-sdk-go, knowledge:rt-gpt-live-sideband, knowledge:rt-gpt-live-delegation]
links: [p-ar-app-channel-contract, p-fn-risks-acceptance, p-fn-business-rules, p-ar-overview, p-ar-agents-protocols, p-ar-security, p-ar-replay, p-ar-quality, p-ar-stack, p-ar-stage-runtime, p-fn-requirements, p-fn-nfr, p-fn-dataset, p-rm-open-questions, pdr-0005-frozen-fictional-dataset, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, adr-0002-orchestrator-backend, adr-0003-backend-go, ma-backend-stack-recommendation, p-rm-backend-production-plan, ma-backend-sdk-go, proj-sk-backend, rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-gpt-live-session-config, rt-transcription, rt-ephemeral-keys, ma-filler-acknowledgements, ma-real-tool-results, genui-a2ui-security, genui-a2ui-messages, proto-a2a-overview, proto-a2a-task-lifecycle, proto-a2a-agent-card, ma-otel-genai-spans, genui-a2ui-overview, ma-target-architecture, rt-graceful-close, rt-latency, proto-mcp-dart-sdks, ma-where-to-run-agents, rt-gpt-live-overview, pdr-0013-orchestrator-visible-agent-selection, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0023-example-guided-composition, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0037-voice-brise-delegated-instructions, pdr-0041-backend-in-this-repo-local-no-auth, pdr-0045-app-backend-channel-wss-recommended, pdr-0048-session-log-only-no-otel-signoz, pdr-0047-go-and-tool-versions-pinned, pdr-0050-gpt-live-client-delegation-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended]
tags: [backend, go, hexagonal, orchestrateur, a2a, a2ui, gpt-live, sideband]
---
# Architecture du backend orchestrateur

**En bref.** Le backend est le module Go hexagonal `backend/orchestrator` (`github.com/b-fontaine/ai_voice_ui/backend/orchestrator`) décidé dans [adr-0003-backend-go] (appliqué au produit par [pdr-0011](../decisions/pdr-0011-adopt-knowledge-adrs.md) ; le nom `agent_orchestrator` de l'ADR est celui du kit d'origine, le code de ce dépôt a retenu `orchestrator`). Il crée la session voix, s'attache au sideband, planifie les tâches, interroge les agents spécialisés en A2A, valide l'A2UI contre le catalogue (liste blanche de composants) et relaie l'A2UI produit par les agents ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) et pousse le tout à l'app sur un canal unique (WSS maison, [pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md), Q-39 ; `genui_a2a` hors stack de l'app). Les noms de messages A2UI de cette page sont ceux de v0.9 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)).

> Statut : **draft**. Fonctionnalité 003 (2026-10-29) : `voice-session`, `sideband-supervisor`, `app-channel` et `session-recorder` sont **implémentés** et vérifiés en réel ; contrat dans [p-ar-app-channel-contract](app-channel-contract.md). Fonctionnalité 004 (2026-10-29, vérifiée en réel) : `orchestrator`, `a2a-client`, `a2ui` et l'agent Qualité sont **implémentés** (première surface « Sessions sans crash 99,57 % ») ; agents Voix du client et Livraison en J3. Le socle vient de [ma-backend-stack-recommendation] et [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) (plan de construction pensé pour un socle de production, non appliqué à la démo) ; le **profil de déploiement pour la démo** est décidé : local, `docker compose` ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)).

## Modules (adapters + application)

| Module | Rôle | Exigences | Source |
|---|---|---|---|
| `voice-session` | `POST /voice/sessions` : reçoit l'offre SDP, appelle `client.Live.New` (`gpt-live-1`, délégation `client` retenue ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md), Q-47 tranchée ; trois modes établis et deux mesurés en SP-02), injectée par `voice.delegation_type` ; voix FR, instructions), renvoie l'answer SDP. **Implémenté (003)** : `application/sdp`, 415/429/502, `DELETE` de fermeture, plafond `VOICE_MAX_SESSION` | NFR-09, FR-13 | [rt-gpt-live-webrtc-session], [ma-backend-sdk-go] |
| `sideband-supervisor` | `Sideband.Connect` par session ; transcripts ; `delegation.created` ; `commentary/thinking.append` ; `close → closed`. **Implémenté (003)** : transcripts, usage, niveau RMS 5 Hz, attache en arrière-plan, raccrochage sur coupure ; `delegation.created` ignoré, renvoyé à 004 | FR-02, FR-08, FR-13, FR-16 | [rt-gpt-live-sideband], [rt-gpt-live-lifecycle] |
| `orchestrator` | **Implémenté (004)** : reconstruit la demande depuis les transcripts (≤ 1 000 runes), file par session (profondeur 2), appels aux agents en parallèle, commentaire vocal générique puis fondé sur le résumé réel ; plan = tous les agents configurés (un seul en J2) ; reste : sélection par skills (J3), révision (J4), annulation « Stop » (J7) | FR-03, FR-07, FR-14, FR-16, FR-17 | [ma-target-architecture], [ma-real-tool-results] |
| `a2a-client` | **Implémenté (004)** : client `a2a-go/v2` natif v1.0 ; carte lue à chaque délégation, `SendStreamingMessage` en `iter.Seq2`, `CancelTask`, délai `AGENT_TIMEOUT` | FR-03, NFR-03 | [proto-a2a-task-lifecycle], `a2a-go/v2` |
| `a2ui` | **Implémenté (004)** : validateur v0.9 sans état + registre de surfaces par session, relais sans recomposition ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) ; liste blanche `A2UI_COMPONENTS` (catalogue « basic » `Column,Text` en J2, `genesis` en J3, Q-44) ; régénération demandée à l'agent : non implémentée (échec + compensation) | FR-04, FR-07, NFR-02 | [genui-a2ui-security], [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 7 |
| `app-channel` | WSS vers l'app : A2UI, événements d'agents, transcript, état orbe ; reçoit les actions typées. **Implémenté (003)** : `GET /app` (transcript, `orb.level`, `session.state`, `usage`, backlog) ; **Implémenté (004)** : `a2ui`, `agent.activity`, `delegation`, rétention de 512 messages ; actions typées : J5 | FR-03, FR-05, FR-08 | [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 8 |
| `session-recorder` | journal serveur horodaté (copie de ce qui part sur l'app-channel). **Implémenté (003)** : un JSONL par session | FR-09, NFR-02, NFR-03 | [p-ar-replay](replay.md) |
| `agents/*` | **Implémenté (004)** pour l'agent **Qualité** seul (`backend/agents/quality`, module Go séparé, jeu figé embarqué, composition déterministe derrière un port `Composer`) ; Voix du client et Livraison : J3. Agents spécialisés : serveurs A2A distincts (un processus chacun ; un conteneur chacun : choix de conception), lisent le jeu figé et produisent l'A2UI de leurs surfaces ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) | NFR-08 | [proto-a2a-agent-card] |

## Ports (hexagonal)

| Port | Implémentation MVP (proposée) | Pourquoi un port |
|---|---|---|
| `out.LiveProvider` | `openai-go/v3` ≥ v3.86, package `live` (implémenté par 003 : `port.LiveProvider`, adaptateur `openailive`, double `fakelive` pour les tests) | package jeune, tests de contrat sur fixtures ([ma-backend-stack-recommendation] risque 2) |
| `out.AgentRuntime` | dans chaque agent : production A2UI guidée par exemples ([pdr-0023](../decisions/pdr-0023-example-guided-composition.md), [pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) | repli possible vers un sidecar Python `a2ui-agent-sdk` en A2A ([adr-0003-backend-go]) |
| `out.RemoteAgent` | client `a2a-go/v2` (implémenté par 004 : `port.RemoteAgent`, adaptateur `a2aclient`, doubles de test) | agents internes aujourd'hui, agent tiers demain (écart E6) |
| `out.LlmText` | LLM texte de composition A2UI | fournisseur non choisi (voir Points ouverts) |
| `out.DatasetStore` | fichiers JSON figés, versionnés (004 : JSON embarqué dans l'agent Qualité, `internal/dataset`) | NFR-08, [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) |
| `out.SessionJournal` | fichiers JSONL locaux (implémenté par 003 : `jsonljournal`) | rejeu et mesure des NFR |
| `out.Observability` | journal de session ; pas d'adaptateur OTel `gen_ai.*` au MVP ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md)) | [ma-otel-genai-spans] (référence) |

## Orchestrateur : règles de comportement

1. **Une délégation = un plan** de tâches (Qualité, Voix du client, Livraison… ; l'orchestrateur ne sollicite que les agents utiles à la demande, [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)), lancées **en parallèle** pour tenir NFR-03.
2. Publier l'activité des agents (rail) dès la réception de `submitted`, puis **relayer message par message** l'A2UI que chaque agent produit, **squelette compris** (`createSurface` + composants squelette, noms v0.9) : le squelette vient de l'agent, jamais de l'orchestrateur ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)), qui valide sans recomposer et n'émet lui-même que des `deleteSurface` de compensation (échec d'une tâche). **Conséquence** : NFR-02 (< 1,5 s) dépend de la latence du premier message de l'agent, donc de Q-17 (LLM de composition) dès J3 ; en J2 l'agent est déterministe et le délai mesuré en réel est de 3 ms ([rt-latency] §5).
3. La voix reçoit (RG-04) un **commentaire générique** de progression puis le **vrai résumé** une fois les résultats reçus ; jamais d'hypothèse ([ma-filler-acknowledgements], [ma-real-tool-results]).
4. **Modifier sur place** (FR-07, FR-17, RG-06) : `updateComponents` / `updateDataModel` émis par l'agent propriétaire sur les `surfaceId` existants (noms v0.9, relayés) ; un éventuel `deleteSurface` + `createSurface` dépend de Q-21 (E8) ([genui-a2ui-messages]).
5. **Révision de tâche** : chaque consigne en vigueur porte un numéro de révision ; les résultats d'une révision périmée sont jetés (FR-14, [ma-real-tool-results]).
6. **Stop / annule** (FR-16) : `CancelTask` sur les tâches A2A en vol, `deleteSurface` des surfaces inachevées (opération de cycle de vie émise par l'orchestrateur, comme la compensation d'échec de 004, Q-69), puis seulement confirmation vocale ([rt-gpt-live-delegation] pièges). Annulation « Stop » : J7.
7. **Action utilisateur** (FR-08) : l'action typée « Bloquer la release » est routée vers l'agent Livraison ; le vrai résultat met à jour la checklist et produit le commentary vocal.
8. Demande hors catalogue : refus vocal avec une alternative (fiche §7, RG-07, RG-08).

## Session voix GPT-Live

- Délégation **`client`** (retenue par [pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md), Q-47 tranchée ; mesurée en SP-02 : `session.delegation.created` 1,0 s après la fin de la parole, sans texte de l'utilisateur ; paramètre injecté `voice.delegation_type`, fixé à la création de session) : l'orchestrateur reconstruit la demande depuis `session.input_transcript.delta` ([rt-gpt-live-delegation], [rt-transcription]).
- Voix **`brise`** (féminine, française, [rt-gpt-live-session-config]) injectée par configuration ; instructions vocales rédigées par l'assistant, optimisées pour la démo ([pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)).
- `acknowledgement_delay_ms` et consigne de **répliques courtes** (parade « l'IA ne s'arrête pas », fiche §8, RG-27).
- Un seul propriétaire par `delegation.id` : le supervisor qui tient la WS sideband.
- Fermeture : `session.close`, attente de `session.closed`, timeout de garde ([rt-graceful-close]).

## Agents spécialisés en A2A

- Chaque agent publie une Agent Card (`/.well-known/agent-card.json`, skills, `capabilities.streaming`) ([proto-a2a-agent-card]).
- Résultats en **Artifacts** ; état suivi par `TaskState` ; annulation par `CancelTask` ([proto-a2a-task-lifecycle]).
- Ils lisent le **jeu de données fictif figé** ([p-fn-dataset](../functional/dataset.md)) : aucune connexion à Crashlytics ni aux stores (hors périmètre, fiche §3).
- Implémentation : `a2a-go/v2` (v2.7.0 au 2026-10-27, [ma-backend-sdk-go]) ; **un processus par agent** ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) ; un conteneur par agent dans le compose (choix de conception de l'assistant, [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)).
- Chaque agent produit les messages A2UI v0.9 de ses surfaces, avec le catalogue fermé partagé et les exemples d'écrans attendus ([pdr-0023](../decisions/pdr-0023-example-guided-composition.md)).

## Configuration injectée

Variables d'environnement lues par `bootstrap.ConfigFromEnv` (fonctionnalités 003 et 004, aucune valeur en dur, AGENTS.md § 2). Défauts surchargeables fixés par `docker-compose.yaml`.

| Variable | Rôle | Défaut / règle |
|---|---|---|
| `OPENAI_API_KEY` | clé du relais SDP, uniquement côté backend | `.env` non commité, jamais loguée ni journalisée ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)) ; NFR-09 |
| `VOICE_MODEL`, `VOICE_VOICE` | modèle et voix | compose : `gpt-live-1`, `brise` ([pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)) |
| `VOICE_DELEGATION_TYPE` | mode de délégation, fixé à la création | `client` seul accepté ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md)) |
| `VOICE_INSTRUCTIONS_FILE` | consignes vocales (fichier monté en lecture seule) | compose : `/etc/genesis/voice-instructions.fr.md` (provisoire, [pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)) |
| `VOICE_MAX_SESSION` | plafond de durée d'une session (`0`/absent = aucun) | compose : `30m`, **provisoire** → Q-68 ; NFR-11, [pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md) |
| `VOICE_CLOSE_GUARD` | attente de `session.closed` avant raccrochage | 5 s ([rt-graceful-close]) |
| `VOICE_ATTACH_ATTEMPTS`, `VOICE_ATTACH_DELAY` | essais d'attache du sideband et attente entre deux | 5 et 500 ms (mesure SP-02) |
| `SESSION_RATE_BURST`, `SESSION_RATE_WINDOW` | limiteur de créations de session | 5 jetons, 1 jeton par 10 s |
| `WS_WRITE_TIMEOUT` | délai d'écriture vers un client de l'app-channel | 5 s |
| `ALLOWED_HOSTS` | hôtes `Host` acceptés en plus de `127.0.0.1`, `localhost`, `[::1]` (avec port) | facultative, liste séparée par des virgules |
| `LISTEN_HOST`, `LISTEN_PORT`, `LISTEN_ALLOW_NON_LOOPBACK` | écoute | `127.0.0.1` par défaut ; `0.0.0.0` refusé sans `LISTEN_ALLOW_NON_LOOPBACK=1` (conteneur seulement, hôte publié en `127.0.0.1`, [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)) |
| `JOURNAL_DIR` | dossier des journaux JSONL | compose : volume nommé `/var/lib/genesis/journal` |
| `AGENTS` (004) | URL des cartes d'agent A2A, séparées par des virgules (`http(s)` seulement) | compose : `http://agent-quality:8090/.well-known/agent-card.json` ; vide : l'orchestrateur démarre, la délégation reçoit un commentaire « aucun agent disponible » ; nombre libre ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)) |
| `A2UI_CATALOG_ID` (004) | `catalogId` exigé dans `createSurface` ; paramètre, jamais constante | obligatoire si `AGENTS` non vide ; compose : URI du catalogue « basic » v0.9 en J2, valeur unique partagée avec l'agent (ancre YAML) ; catalogue `genesis` en J3 (Q-44, [pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) |
| `A2UI_COMPONENTS` (004) | liste blanche des composants A2UI acceptés (virgules) | obligatoire si `AGENTS` non vide ; compose : `Column,Text` ([genui-a2ui-security]) |
| `AGENT_TIMEOUT` (004) | borne toute la tâche (carte + flux) | > 0 obligatoire si `AGENTS` non vide ; compose : 8 s (NFR-03) |
| `VOICE_APPEND_ACK_TIMEOUT` (004) | attente de l'acquittement d'un `commentary.append`, jamais de nouvelle tentative | 2 s |
| `VOICE_ACK_DELAY_MS` (004) | `delegation.acknowledgement_delay_ms` (évite deux phrases de remplissage) | entier ≥ 0 ; absent : non envoyé ; à régler en répétition (NFR-01) |
| `VOICE_PHRASES_FILE` (004) | phrases dites par l'orchestrateur (JSON : `generic`, `failure`, `failure_rejected`, `queue_full`, `no_request`, `no_agent`, `no_summary`, `result_template`) | défaut français embarqué (`go:embed`), aucune phrase en dur ([pdr-0009](../decisions/pdr-0009-french-only.md)) ; chacune bornée à 1 000 runes |

**Côté agent Qualité** (004, `backend/agents/quality`, jamais la clé OpenAI) :

| Variable | Rôle | Défaut / règle |
|---|---|---|
| `AGENT_LISTEN_ADDR` | adresse d'écoute | `127.0.0.1:8090` ; compose : `0.0.0.0:8090` |
| `AGENT_PUBLIC_URL` | URL publique de la carte ; son hôte fonde le contrôle `Host` | compose : `http://agent-quality:8090` |
| `AGENT_LISTEN_ALLOW_NON_LOOPBACK` | autorise l'écoute hors boucle locale | `1` dans le conteneur seulement (réseau `internal`) |
| `A2UI_CATALOG_ID` | `catalogId` de ses `createSurface` | même valeur que l'orchestrateur |

| Clé (proposition) | Exemple | Règle |
|---|---|---|
| `a2ui.version` | `v0.9` exactement ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)) | constante du validateur, non configurable ; [genui-a2ui-overview] |
| `dataset.*` | jeu figé | **embarqué dans l'agent** (`go:embed`, lignes brutes de [p-fn-dataset](../functional/dataset.md)), **sans `DATASET_PATH`** ; NFR-08, [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) |

Les clés `voice.ack_delay_ms`, `a2ui.catalog_id` et `agents[]` de la proposition initiale sont implémentées sous les variables `VOICE_ACK_DELAY_MS`, `A2UI_CATALOG_ID` et `AGENTS` ci-dessus.

## Profil de déploiement pour la démo (décidé, [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md))

Le socle générique prévoit Keycloak, Kong, Postgres, Temporal et SigNoz ([ma-backend-stack-recommendation]) : **non retenu** pour la démo. Profil retenu : tout en local, un `docker-compose.yaml` (rédigé par l'assistant ; dépôt : ce dépôt, [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md), Q-27 tranchée) lance l'orchestrateur Go et un conteneur par agent A2A (choix de conception) ; ports publiés sur `127.0.0.1`, sans authentification ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md), Q-48 tranchée) ; sans Keycloak, Kong, Postgres ni Temporal ; journal en fichiers ; pas d'OTel ni de SigNoz ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55). L'app Flutter tourne en debug sur la machine, hors conteneur.

## Contexte repris de `knowledge/` (transféré le 2026-10-28)

Passages propres au projet retirés des notes génériques lors du nettoyage de `knowledge/` ; ils décrivent le contexte d'origine, sans trancher les points ouverts ci-dessous.

| Origine (knowledge) | Contenu |
|---|---|
| [adr-0003-backend-go] (contexte d'origine) | Backend = module `backend/agent_orchestrator` de `septeo_saaster_kit` (nom du kit d'origine ; ce dépôt : `backend/orchestrator`), hexagonal. Compétences confirmées par le porteur le 2026-10-27 : « L'équipe maîtrise tous les langages, y compris Rust, Go et Python ». `a2a-go/v2` prévu « en phase 2 » dans la stack d'origine (ce document l'utilise dès le MVP pour les agents, proposition). Risques hérités du kit à corriger dès le jour 0 : `ParseUnverified` et CORS `*` ([security.md](security.md)). Dépôt : ce dépôt, sous `backend/` ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md), Q-27 tranchée ; AGENTS.md § 2 mis à jour) |
| [ma-backend-stack-recommendation] (passages retirés) | Stack, score du panel et schéma de production d'origine : [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) § « Socle de production d'origine » |
| [proj-sk-backend] | Cadrage d'origine : le backend Go du kit vu comme « ce que le backend Go offre à l'orchestrateur ». Les SDK agents Go exigent Go ≥ 1.26 et OTel ≥ v1.47, d'où un module séparé pour `backend/agent_orchestrator` (nom du kit ; ici `backend/orchestrator`) |
| [rt-gpt-live-sideband] | L'orchestrateur backend attache le sideband et traite la délégation `client` ([rt-gpt-live-delegation]) ; outils, autorisations, règles métier et credentials restent côté serveur ; Flutter ne gère que l'audio et le rendu A2UI |
| [rt-gpt-live-delegation], [rt-gpt-live-overview] | En mode `client`, l'orchestrateur du produit joue l'agent délégué. La séparation « modèle voix = tour de parole / backend délégué = outils et logique métier » correspond au couple « agent vocal + orchestrateur » |
| [proto-mcp-dart-sdks] | Les clients MCP vivent dans l'orchestrateur backend ([ma-where-to-run-agents]) ; `mcp_dart` n'aurait de sens que pour un orchestrateur en Dart : non concerné (Go, [adr-0003-backend-go]) |
| [rt-ephemeral-keys] | Route `POST /voice/sessions` (`application/sdp` dans le produit) : [security.md](security.md) § « Contrat de la route de relais » |

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- ~~Profil de déploiement et hébergement~~ : tranchés, local + compose ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md), Q-15). Observabilité : journal seul ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55).
- ~~Topologie A2UI~~ : tranchée, chaque agent produit son A2UI ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md), Q-37).
- **Déterminisme de la composition** : tranché par [pdr-0023](../decisions/pdr-0023-example-guided-composition.md) (décision contrainte, Q-38) : LLM guidé par des exemples d'écrans attendus, sur le catalogue fermé ; ni LLM libre, ni plans A2UI pré-écrits par acte (NFR-08 : « seule la composition varie » ; parade R6 de la fiche § 8). Forme et emplacement des exemples (prompt, fixtures) : détail de conception ([p-fn-risks-acceptance](../functional/risks-acceptance.md)).
- **LLM texte** de composition → Q-17 ; budget total 20 € ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)).
- ~~Voix FR et instructions~~ : tranché ([pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md), Q-26).
- ~~Mode de délégation~~ : tranché, `client` ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md), Q-47) ; `responses` mesuré et écarté, `decisions` non essayé. ~~Niveau audio de l'orbe~~ : tranché, le `sideband-supervisor` calcule le RMS de la copie sideband de sortie (exploitable, mesuré en SP-02, [rt-gpt-live-sideband]) et le pousse à 5 Hz sur l'app-channel ([pdr-0051](../decisions/pdr-0051-orb-level-from-sideband-rms-recommended.md), Q-43). ~~Session~~ : une session GPT-Live par acte, `voice-session` rouvre une session sans intervention du speaker ([pdr-0052](../decisions/pdr-0052-one-gpt-live-session-per-act-recommended.md), Q-53).
