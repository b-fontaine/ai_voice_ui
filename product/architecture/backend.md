---
id: p-ar-backend
title: Architecture du backend orchestrateur
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/006-j3-act1-backend/plan.md, specs/006-j3-act1-backend/status.md, contracts/a2ui/genesis/v1/README.md, specs/004-j2-orchestrator-quality-agent/plan.md, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, knowledge:adr-0003-backend-go, knowledge:ma-backend-stack-recommendation, product/roadmap/backend-production-plan.md, knowledge:ma-backend-sdk-go, knowledge:rt-gpt-live-sideband, knowledge:rt-gpt-live-delegation]
links: [p-ar-app-channel-contract, p-fn-catalog, pdr-0014-six-component-catalog, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0020-act1-four-surfaces, p-fn-risks-acceptance, p-fn-business-rules, p-ar-overview, p-ar-agents-protocols, p-ar-security, p-ar-replay, p-ar-quality, p-ar-stack, p-ar-stage-runtime, p-fn-requirements, p-fn-nfr, p-fn-dataset, p-rm-open-questions, pdr-0005-frozen-fictional-dataset, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, adr-0002-orchestrator-backend, adr-0003-backend-go, ma-backend-stack-recommendation, p-rm-backend-production-plan, ma-backend-sdk-go, proj-sk-backend, rt-gpt-live-webrtc-session, rt-gpt-live-sideband, rt-gpt-live-delegation, rt-gpt-live-lifecycle, rt-gpt-live-session-config, rt-transcription, rt-ephemeral-keys, ma-filler-acknowledgements, ma-real-tool-results, genui-a2ui-security, genui-a2ui-messages, proto-a2a-overview, proto-a2a-task-lifecycle, proto-a2a-agent-card, ma-otel-genai-spans, genui-a2ui-overview, ma-target-architecture, rt-graceful-close, rt-latency, proto-mcp-dart-sdks, ma-where-to-run-agents, rt-gpt-live-overview, pdr-0013-orchestrator-visible-agent-selection, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0023-example-guided-composition, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0037-voice-brise-delegated-instructions, pdr-0041-backend-in-this-repo-local-no-auth, pdr-0045-app-backend-channel-wss-recommended, pdr-0048-session-log-only-no-otel-signoz, pdr-0047-go-and-tool-versions-pinned, pdr-0050-gpt-live-client-delegation-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended]
tags: [backend, go, hexagonal, orchestrateur, a2a, a2ui, gpt-live, sideband]
---
# Architecture du backend orchestrateur

**En bref.** Le backend est le module Go hexagonal `backend/orchestrator` (`github.com/b-fontaine/ai_voice_ui/backend/orchestrator`) décidé dans [adr-0003-backend-go] (appliqué au produit par [pdr-0011](../decisions/pdr-0011-adopt-knowledge-adrs.md) ; le nom `agent_orchestrator` de l'ADR est celui du kit d'origine, le code de ce dépôt a retenu `orchestrator`). Il crée la session voix, s'attache au sideband, planifie les tâches, interroge les agents spécialisés en A2A, valide l'A2UI contre le catalogue (liste blanche de composants) et relaie l'A2UI produit par les agents ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) et pousse le tout à l'app sur un canal unique (WSS maison, [pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md), Q-39 ; `genui_a2a` hors stack de l'app). Les noms de messages A2UI de cette page sont ceux de v0.9 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)).

> Statut : **draft**. Fonctionnalité 003 (2026-10-29) : `voice-session`, `sideband-supervisor`, `app-channel` et `session-recorder` sont **implémentés** et vérifiés en réel ; contrat dans [p-ar-app-channel-contract](app-channel-contract.md). Fonctionnalité 004 (2026-10-29, vérifiée en réel) : `orchestrator`, `a2a-client`, `a2ui` et l'agent Qualité sont **implémentés** (première surface « Sessions sans crash 99,57 % »). Fonctionnalité 006 (J3-A, 2026-10-30, `gate --full` vert, essai réel unique OK) : agents Voix du client et Livraison, sélection des agents par l'orchestrateur, catalogue fermé `genesis` côté contrat, jeu de données recalculé ; la moitié Flutter de J3 est 007. Le socle vient de [ma-backend-stack-recommendation] et [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) (plan de construction pensé pour un socle de production, non appliqué à la démo) ; le **profil de déploiement pour la démo** est décidé : local, `docker compose` ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)).

## Modules (adapters + application)

| Module | Rôle | Exigences | Source |
|---|---|---|---|
| `voice-session` | `POST /voice/sessions` : reçoit l'offre SDP, appelle `client.Live.New` (`gpt-live-1`, délégation `client` retenue ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md), Q-47 tranchée ; trois modes établis et deux mesurés en SP-02), injectée par `voice.delegation_type` ; voix FR, instructions), renvoie l'answer SDP. **Implémenté (003)** : `application/sdp`, 415/429/502, `DELETE` de fermeture, plafond `VOICE_MAX_SESSION` | NFR-09, FR-13 | [rt-gpt-live-webrtc-session], [ma-backend-sdk-go] |
| `sideband-supervisor` | `Sideband.Connect` par session ; transcripts ; `delegation.created` ; `commentary/thinking.append` ; `close → closed`. **Implémenté (003)** : transcripts, usage, niveau RMS 5 Hz, attache en arrière-plan, raccrochage sur coupure ; `delegation.created` ignoré, renvoyé à 004 | FR-02, FR-08, FR-13, FR-16 | [rt-gpt-live-sideband], [rt-gpt-live-lifecycle] |
| `orchestrator` | **Implémenté (004)** : reconstruit la demande depuis les transcripts (≤ 1 000 runes), file par session (profondeur 2), appels aux agents en parallèle, commentaire vocal générique puis fondé sur le résumé réel ; **006** : le plan est choisi par un `Planner` (`TagPlanner`, mots entiers sur les `skills[].tags` des cartes ; règle des tags génériques ; virgule décimale « 3,4 » = « 3.4 »), message `plan` publié avant toute activité ; reste : révision (J4), annulation « Stop » (J7). Fichiers : `plan_step.go` (cartes, sélection, `plan`), `task.go` (suivi, relais, échec), `commentary.go` (phrases), `pipeline.go` | FR-03, FR-07, FR-14, FR-16, FR-17 | [ma-target-architecture], [ma-real-tool-results] |
| `a2a-client` | **Implémenté (004)** : client `a2a-go/v2` natif v1.0 ; carte lue à chaque délégation, `SendStreamingMessage` en `iter.Seq2`, `CancelTask`, délai `AGENT_TIMEOUT` | FR-03, NFR-03 | [proto-a2a-task-lifecycle], `a2a-go/v2` |
| `a2ui` | **Implémenté (004)** : validateur v0.9 sans état + registre de surfaces par session, relais sans recomposition ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) ; liste blanche `A2UI_COMPONENTS` (catalogue « basic » `Column,Text` en J2 ; **006** : les 4 composants `genesis`, Q-44), propriétés admises `A2UI_ALLOWED_PROPS` / `A2UI_BINDING_PROPS`, code `bad_property` ; régénération demandée à l'agent : non implémentée (échec + compensation) | FR-04, FR-07, NFR-02 | [genui-a2ui-security], [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 7 |
| `app-channel` | WSS vers l'app : A2UI, événements d'agents, transcript, état orbe ; reçoit les actions typées. **Implémenté (003)** : `GET /app` (transcript, `orb.level`, `session.state`, `usage`, backlog) ; **Implémenté (004)** : `a2ui`, `agent.activity`, `delegation`, rétention de 512 messages ; actions typées : J5 | FR-03, FR-05, FR-08 | [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 8 |
| `session-recorder` | journal serveur horodaté (copie de ce qui part sur l'app-channel). **Implémenté (003)** : un JSONL par session | FR-09, NFR-02, NFR-03 | [p-ar-replay](replay.md) |
| `agents/*` | **Implémenté (004, 006)** : les trois agents Qualité, Voix du client et Livraison dans le module Go unique `backend/agents` (§ Agents spécialisés en A2A). Serveurs A2A distincts (un processus chacun ; un conteneur chacun : choix de conception), ils lisent le jeu figé et produisent l'A2UI de leurs surfaces ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) | NFR-08 | [proto-a2a-agent-card] |

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

1. **Une délégation = un plan** de tâches (Qualité, Voix du client, Livraison… ; l'orchestrateur ne sollicite que les agents utiles à la demande, [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md), RG-29), lancées **en parallèle** pour tenir NFR-03. **Implémenté (006)** : carte lue **une fois** par délégation (`AgentCard.Tags`, réutilisée par l'envoi), `Planner` remplaçable (Q-17), `plan {delegation, selected[], idle[]}` publié avant toute activité ; carte injoignable : l'agent est retenu et passe en `failed` « injoignable », sauf si ses derniers tags connus (`RemoteAgent.LastTags`) montrent qu'il est hors sujet ; refus d'un agent retenu = `rejected`, pas un échec ([contrat](app-channel-contract.md)) ; échec partiel dit honnêtement (`partial_failure`, résumés ≤ 200 runes, chiffres en tête).
2. Publier l'activité des agents (rail) dès la réception de `submitted`, puis **relayer message par message** l'A2UI que chaque agent produit, **squelette compris** (`createSurface` + composants squelette, noms v0.9) : le squelette vient de l'agent, jamais de l'orchestrateur ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)), qui valide sans recomposer et n'émet lui-même que des `deleteSurface` de compensation (échec d'une tâche). **Conséquence** : NFR-02 (< 1,5 s) dépend de la latence du premier message de l'agent, donc de Q-17 (LLM de composition) dès J3 ; en J2 l'agent est déterministe et le délai mesuré en réel est de 3 ms ([rt-latency] §5).
3. La voix reçoit (RG-04) un **commentaire générique** de progression puis le **vrai résumé** une fois les résultats reçus ; jamais d'hypothèse ([ma-filler-acknowledgements], [ma-real-tool-results]).
4. **Modifier sur place** (FR-07, FR-17, RG-06) : `updateComponents` / `updateDataModel` émis par l'agent propriétaire sur les `surfaceId` existants (noms v0.9, relayés) ; un éventuel `deleteSurface` + `createSurface` dépend de Q-21 (E8) ([genui-a2ui-messages]).
5. **Révision de tâche** : chaque consigne en vigueur porte un numéro de révision ; les résultats d'une révision périmée sont jetés (FR-14, [ma-real-tool-results]).
6. **Stop / annule** (FR-16) : `CancelTask` sur les tâches A2A en vol, `deleteSurface` des surfaces inachevées (opération de cycle de vie émise par l'orchestrateur, comme la compensation d'échec de 004, Q-69), puis seulement confirmation vocale ([rt-gpt-live-delegation] pièges). Annulation « Stop » : J7.
7. **Action utilisateur** (FR-08) : l'action typée « Bloquer la release » est routée vers l'agent Livraison ; le vrai résultat met à jour la checklist et produit le commentary vocal.
8. Demande hors catalogue : refus vocal avec une alternative (fiche §7, RG-07, RG-08). **Implémenté (006)** : aucun agent retenu → aucun appel, phrase `out_of_catalog` ; tous les agents retenus refusent → `failure_rejected` (avec alternative).

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
- **Module unique `backend/agents` (006)** : un binaire par agent (`cmd/agent-quality` 8090, `cmd/agent-voice` 8091, `cmd/agent-delivery` 8092 ; surfaces `kpi` + `trend`, `reviews`, `checklist`). Noyau `internal/kit` : `Profile` JSON embarqué (nom, port, `skill.tags` et `examples` qui alimentent la carte, textes de refus), `Composer`, `SurfaceMessages` (messages des trois temps), `Main` (`getenv` et `stderr` injectés : le noyau n'importe pas `os`), `InScope` partagé. `internal/dataset` : jeu brut et calculs (valeurs de [p-fn-dataset](../functional/dataset.md) recalculées ; cas hors fiche : changelog vide = « bloquant », avis 3.3 refusés avant J4 ; `decisionStatus` lu dans `dataset.json`, Q-35). **Aucun agent n'importe un autre** (`arch_test.go`). Dockerfile unique `ARG AGENT` sans défaut, binaire `/agent`.
- **Portée** : les mots déclencheurs vivent dans le **profil** (tags de la carte), lus par l'orchestrateur, jamais en dur dans lui ni dans l'agent. L'agent ne garde qu'un **refus défensif** (autre version que la 3.4, comparaison, plateforme précise : acte 2 = J4), distinct du choix de l'orchestrateur.
- **Composition déterministe** (provisoire, Q-17) : les messages émis sont exactement les fixtures de `contracts/a2ui/genesis/v1/`, valeurs tirées du jeu de données ([p-fn-dataset](../functional/dataset.md)). Conflit connu avec [pdr-0023](../decisions/pdr-0023-example-guided-composition.md) (« aucune séquence pré-écrite rejouée comme générée »), à dire au porteur avant la démo ; le `Composer` et le `Planner` sont remplaçables.
- **Compose** : ancre `x-agent` (réseau `agents` interne, `read_only`, `cap_drop`, `no-new-privileges`, healthcheck `/agent healthcheck`), `depends_on` en `service_healthy`, `build.args.AGENT` ; `backend/check-compose.sh` boucle sur tous les `agent-*` et contrôle `AGENTS`, `A2UI_COMPONENTS`, `A2UI_ALLOWED_PROPS`, `A2UI_BINDING_PROPS` contre `catalog.json`.

## Configuration injectée

Variables d'environnement lues par `bootstrap.ConfigFromEnv` (fonctionnalités 003, 004 et 006, aucune valeur en dur, AGENTS.md § 2). Défauts surchargeables fixés par `docker-compose.yaml`.

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
| `AGENTS` (004, 006) | entrées séparées par des virgules : `Nom=URL de la carte` (`http(s)` seulement) ; le **nom d'affichage est facultatif** et prioritaire sur le nom de la carte (repli : nom de carte, puis hôte) ; doublons refusés | compose : `Qualité`, `Voix du client` et `Livraison` (ports 8090, 8091, 8092) ; vide : l'orchestrateur démarre, la délégation reçoit un commentaire « aucun agent disponible » ; nombre libre ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)) |
| `A2UI_CATALOG_ID` (004) | `catalogId` exigé dans `createSurface` ; paramètre, jamais constante | obligatoire si `AGENTS` non vide ; compose (006) : défaut **provisoire** `https://genesis-canvas.example/a2ui/catalogs/genesis/v1`, valeur unique partagée avec les agents (ancre YAML) ; **Q-44 ouverte** : la changer ne touche aucun code ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)) |
| `A2UI_COMPONENTS` (004) | liste blanche des composants A2UI acceptés (virgules) | obligatoire si `AGENTS` non vide ; compose (006) : `KeyIndicator,TrendChart,ReviewSentiment,ReleaseChecklist` (les 4 de `catalog.json`, `Column,Text` retirés) ; `check-compose.sh` compare à `components` ([genui-a2ui-security]) |
| `A2UI_ALLOWED_PROPS`, `A2UI_BINDING_PROPS` (006) | propriétés admises d'un composant ; propriétés qui doivent être une liaison `{path}` | vides : aucun contrôle ; compose : `id,component,data` et `data` ; `check-compose.sh` compare aux ensembles de `catalog.json` ; refus : code `bad_property` |
| `AGENT_TIMEOUT` (004) | borne toute la tâche (carte + flux) | > 0 obligatoire si `AGENTS` non vide ; compose : 8 s (NFR-03) |
| `VOICE_APPEND_ACK_TIMEOUT` (004) | attente de l'acquittement d'un `commentary.append`, jamais de nouvelle tentative | 2 s |
| `VOICE_ACK_DELAY_MS` (004) | `delegation.acknowledgement_delay_ms` (évite deux phrases de remplissage) | entier ≥ 0 ; absent : non envoyé ; à régler en répétition (NFR-01) |
| `VOICE_PHRASES_FILE` (004) | phrases dites par l'orchestrateur (JSON : `generic`, `failure`, `failure_rejected`, `queue_full`, `no_request`, `no_agent`, `no_summary`, `result_template`, et depuis 006 `out_of_catalog`, `partial_failure`) | défaut français embarqué (`go:embed`), aucune phrase en dur ([pdr-0009](../decisions/pdr-0009-french-only.md)) ; chacune bornée à 1 000 runes |

**Côté agent** (004, 006 ; `backend/agents`, jamais la clé OpenAI ; un binaire par agent) :

| Variable | Rôle | Défaut / règle |
|---|---|---|
| `AGENT_LISTEN_ADDR` | adresse d'écoute | `127.0.0.1` + port du profil (8090, 8091 ou 8092) ; compose : `0.0.0.0:<port>` |
| `AGENT_PUBLIC_URL` | URL publique de la carte ; son hôte fonde le contrôle `Host` | compose : `http://agent-quality:8090`, `agent-voice:8091`, `agent-delivery:8092` |
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
