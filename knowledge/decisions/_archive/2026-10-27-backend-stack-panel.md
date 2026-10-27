# Archive brute — panel stack backend (2026-10-27)

Sorties intégrales des agents du workflow backend-stack-panel (run wf_1ce557c5-ec5) : 5 propositions (Go, hybride Go+Python, Python, TypeScript, Dart), 5 vérifications adverses, 3 jugements, 1 synthèse. ⚠️ Contexte donné aux agents : « Équipe Flutter + Go » — hypothèse NON confirmée à l'époque (confirmée plus tard : l'équipe maîtrise tous les langages). Document d'archive, non relu : la référence est adr-0003-backend-go.

## 1. Propositions (5)

### Dart (avocat) : un service « voice_orchestrator » en Dart 3.12+ sur shelf (shelf_router + shelf_web_socket), conteneurisé à côté des services Go du saaster kit. Les packages clés sont openai_dart 11.x (sessions Live + sideband), googleai_dart 13.x (auth_tokens Gemini), mcp_dart 2.4.x (client MCP 2026-07-28, Streamable HTTP, OAuth), a2ui_core 0.3.0 (validation A2UI v0.9/v1.0 côté serveur), firebase_admin_sdk (App Check), dartastic_opentelemetry (OTLP vers SigNoz) et grpc 5.x pour appeler les services Go. Le Go reste en place pour le métier, Temporal et Postgres : je ne propose pas un backend 100 % Dart.

Le Dart est défendable côté backend, mais seulement pour le service d'orchestration voix/GenUI. Ce n'est pas un remplacement du backend Go du saaster kit. Son vrai atout est a2ui_core 0.3.0 : c'est du Dart pur, il valide l'A2UI v0.9/v1.0 contre le catalogue, et le même moteur peut tourner dans l'orchestrateur et dans l'app, ce qui donne une double validation identique. L'écosystème couvre désormais l'essentiel de la phase 1 : openai_dart 11 annonce les sessions Live et le sideband, googleai_dart les jetons éphémères Gemini, mcp_dart la spec MCP 2026-07-28. Ces trois SDK sont toutefois communautaires, et il n'y a ni SDK Temporal ni SDK A2A officiel en Dart (le package a2a cible v0.3, sans auth). Ma recommandation honnête : un orchestrateur Dart mince, branché en gRPC sur le Go existant (Temporal, Postgres, Keycloak). On le garde en Dart seulement si le spike de la semaine 1 (relais SDP + attach sideband + délégation client) passe avec openai_dart ou un WebSocket fait à la main. Sinon, on bascule en Go.

**Composants**
- Relais de session voix — POST /voice/sessions : vérifie le JWT Keycloak, applique les quotas, relaie l'offre SDP vers POST /v1/live/sessions (gpt-live-1, delegation.type=client) avec la clé projet, renvoie l'answer SDP et garde session.id. Pour Gemini, émet un jeton éphémère v1beta/auth_tokens avec liveConnectConstraints. (shelf + openai_dart (client.live.sessions) ou http brut ; googleai_dart (Auth Tokens))
- Gestionnaire sideband — Une connexion wss://api.openai.com/v1/live/sessions/{id}/attach par session. Reconstruit le contexte depuis les transcripts, reçoit session.delegation.created (target client), répond via session.thinking.append / commentary.append (au plus 500 tokens, event_id unique), puis session.close et attente de session.closed. (openai_dart (sideband WebSockets typés) ou dart:io WebSocket.connect(headers: Authorization) avec modèles d'événements faits maison)
- Routeur / orchestrateur — Outil vocal unique delegate : classification d'intention, appel de l'agent GenUI et/ou des outils MCP, annulation coopérative (l'interruption vocale n'annule pas le travail backend), un seul propriétaire par appel d'outil. (Dart pur (boucle d'agent maison, pas de framework type ADK/Agents SDK en Dart), LLM via openai_dart Responses ou googleai_dart)
- Agent GenUI + validateur A2UI — Génère les messages A2UI, les valide contre le catalogue métier (PayloadValidator / CatalogApi), rejette puis régénère si la validation échoue, filtre openUrl et les URLs d'images. (a2ui_core 0.3.0 (Dart pur) + package partagé ui_contract (catalogue JSON versionné par URI))
- Client MCP — Appels d'outils métier en Streamable HTTP avec OAuth, journal d'audit, protection SSRF (liste blanche de serveurs). (mcp_dart 2.4.x (StreamableHttpClientTransport + OAuthClientProvider))
- Canal app ↔ orchestrateur — Pousse les messages A2UI et les événements de délégation vers l'app ; reçoit les actions utilisateur typées et les résultats des outils locaux. (WebSocket (shelf_web_socket) avec enveloppe JSON partagée ; plus tard, éventuellement genui_a2a)
- Pont vers le Go — Accès aux données métier, lancement des workflows Temporal longs (tâches longues), identité. Le Dart n'héberge pas de worker Temporal. (package grpc Dart 5.x + stubs générés depuis les .proto du kit (customer.proto…))
- Observabilité — Spans gen_ai.* (invoke_agent orchestrator, execute_tool, invoke_agent genui), gen_ai.conversation.id = id de session, propagation traceparent depuis l'app, export OTLP vers SigNoz. (dartastic_opentelemetry 0.12 (OTLP gRPC/HTTP) ; attributs GenAI posés à la main)

**Affirmations SDK**
- a2ui_core 0.3.0 (labs.flutter.dev) n'a aucune dépendance Flutter (collection, intl, json_schema_builder, logging, meta, preact_signals), gère les enveloppes A2UI v0.9, v0.9.1 et v1.0 et fournit PayloadValidator (JSON Schema 2020-12). Il est donc utilisable côté serveur. — https://pub.dev/packages/a2ui_core
- a2ui_core 0.3.0 introduit le support du protocole v1.0 (RpcHandler, allowedCallers, openUrl soumis à une activation utilisateur) avec de nombreuses ruptures d'API par rapport à 0.2.x. En 0.2.x, seul v0.9 était accepté. — https://pub.dev/packages/a2ui_core/changelog
- genui 0.10.4 exige le SDK Flutter (plateformes Android, iOS, macOS, web) et dépend de a2ui_core ^0.1.0. Il ne peut donc pas tourner sur un serveur Dart, et il est désynchronisé de a2ui_core 0.3.0. — https://pub.dev/packages/genui
- genui_a2a 0.10.1 dépend aussi de a2ui_core ^0.1.0 et ne précise pas sa version de spec A2A. — https://pub.dev/packages/genui_a2a
- mcp_dart 2.4.3 (leehack.com, communautaire) préfère MCP 2026-07-28 avec repli sur les specs antérieures. Il offre client et serveur Streamable HTTP sur la VM Dart, OAuthClientProvider + PKCE côté client et un authenticator côté serveur. — https://pub.dev/packages/mcp_dart
- Le package a2a 4.3.1 cible la spec A2A v0.3, ne gère que JSON-RPC 2.0, traite les requêtes serveur toujours en mode bloquant et n'implémente pas l'authentification de la §4. — https://pub.dev/packages/a2a
- Les SDK A2A officiels existent en Python, Go, Java, JS, .NET et Rust. Il n'y en a pas en Dart. — https://a2a-protocol.org/latest/sdk/
- openai_dart 11.0.1 est communautaire (davidmiguel.com, non affilié à OpenAI). Il couvre l'API Responses (SSE, WebSockets persistants) et l'API Live via client.live. — https://pub.dev/packages/openai_dart
- Le changelog d'openai_dart 11.0.0 annonce « client.live.sessions adds HTTP signaling » et « Primary and sideband WebSockets expose typed events and role-safe commands ». gpt-live-1, la délégation et commentary.append n'y sont pas nommés explicitement : la couverture de la délégation client reste à vérifier. — https://pub.dev/packages/openai_dart/changelog
- googleai_dart 13.0.0 est communautaire (non affilié à Google). Il annonce le support complet du Live API (createLiveClient) et des Auth Tokens (jetons éphémères). — https://pub.dev/packages/googleai_dart
- dart:io WebSocket.connect accepte un paramètre headers (Map<String, dynamic>?). Le sideband avec Authorization: Bearer est donc faisable à la main sans SDK. — https://api.dart.dev/dart-io/WebSocket/connect.html
- firebase_admin_sdk 0.5.6 est publié par firebase.google.com et supporte appCheck().verifyToken. dart_firebase_admin (Invertase) est discontinué. — https://pub.dev/packages/firebase_admin_sdk
- dartastic_opentelemetry 0.12.0 fournit traces, métriques et logs avec des exporteurs OTLP gRPC et HTTP. Il n'est pas encore un projet CNCF officiel (donation en cours). — https://pub.dev/packages/dartastic_opentelemetry
- Le package Dart opentelemetry est déprécié au profit de opentelemetry_wk (constat déjà consigné dans la base de connaissances). — https://pub.dev/packages/opentelemetry
- Temporal n'a pas de SDK Dart : les SDK officiels sont Go, Java, Python, TypeScript, .NET, Ruby, PHP et Rust. — https://docs.temporal.io/encyclopedia/temporal-sdks
- dart_frog 1.2.6 a été publié il y a environ 11 mois, et dart_frog_web_socket 1.0.3 il y a environ 12 mois : la cadence de maintenance a ralenti. — https://pub.dev/packages/dart_frog
- serverpod 4.0.4 (serverpod.dev) apporte ORM, auth, sockets temps réel et future calls persistantes. La page ne mentionne pas OpenTelemetry. — https://pub.dev/packages/serverpod
- Le package grpc 5.2.0 (dart.dev) supporte la VM Dart. Un service Dart peut donc consommer les services gRPC Go existants. — https://pub.dev/packages/grpc

**Forces**
- Partage réel avec Flutter : a2ui_core est du Dart pur. L'orchestrateur et l'app peuvent valider l'A2UI avec le même moteur et le même catalogue JSON versionné, sans divergence de schéma entre deux langages.
- Un package de workspace ui_contract (catalogue, enveloppe du canal WebSocket, DTO de délégation, ids d'événements) est importé tel quel par l'app et le serveur, sans codegen inter-langages.
- L'équipe Flutter peut contribuer à l'orchestrateur et à l'agent GenUI, là où se trouve la logique produit, sans changer de langage. Le bus factor est meilleur que pour un service Go porté par les seuls développeurs backend.
- La couverture SDK est meilleure qu'attendu au 2026-10-27 : openai_dart 11 annonce les sessions Live et le sideband, googleai_dart 13 les auth_tokens, mcp_dart 2.4.3 la spec 2026-07-28 avec Streamable HTTP et OAuth.
- Le plan B est simple : le sideband n'est qu'un WebSocket JSON. dart:io WebSocket.connect gère l'en-tête Authorization, donc on peut se passer d'openai_dart.
- Dart AOT produit un binaire natif léger avec démarrage rapide, adapté à un conteneur par instance. Le modèle async/Stream convient à un orchestrateur I/O-bound (WS sortants, SSE LLM, WS vers l'app).
- Le Go existant n'est pas touché : métier, Postgres, Temporal, Keycloak et Kong restent là où ils marchent.

**Faiblesses**
- Aucun SDK officiel OpenAI ou Gemini en Dart serveur : openai_dart et googleai_dart sont maintenus par un seul éditeur communautaire. Le support de gpt-live-1 n'est pas nommé explicitement, et les nouveautés de l'API Live risquent d'arriver avec du retard.
- Pas de SDK Temporal Dart : les tâches longues passent forcément par le Go, ce qui ajoute un saut réseau et un contrat de plus. Les future calls de Serverpod ne remplacent pas Temporal.
- A2A : le seul package Dart (a2a 4.3.1) cible v0.3, sans auth, avec des serveurs bloquants. Il est inutilisable pour la phase 2 A2A v1.0 sans couche maison, alors que a2a-go est officiel.
- Partage de code moins net que promis : genui 0.10.4 et genui_a2a 0.10.1 épinglent a2ui_core ^0.1.0 alors que la v1.0 n'arrive qu'en 0.3.0, avec beaucoup de ruptures. L'app et le serveur ne peuvent pas partager les mêmes types a2ui_core tant que genui n'a pas suivi. On ne partage alors que les schémas JSON du catalogue.
- Pas de framework d'agents Dart comparable à ADK ou à l'Agents SDK : boucle d'agent, retries, garde-fous et handoff sont à écrire soi-même.
- L'OTel Dart est immature : dartastic n'est pas encore CNCF, le package opentelemetry historique est déprécié, et il n'existe pas d'instrumentation GenAI automatique. Tous les spans gen_ai.* sont manuels.
- Le pipeline BDD/testcontainers éprouvé en Go (Godog + testcontainers-go) n'a pas d'équivalent mûr vérifié en Dart.
- Les frameworks web Dart s'essoufflent : dart_frog et dart_frog_web_socket n'ont pas eu de release depuis environ un an. Serverpod est actif mais très intégré (ORM, auth) et ferait doublon avec le kit Go. shelf reste le choix sobre, mais il est minimal.
- Un deuxième langage backend à opérer (images, CVE, profiling, astreinte) dans une équipe où l'infra Go existe déjà.

**Risques**
- Spike sideband : si openai_dart ne type pas session.delegation.created ni les événements *.append, il faut écrire et tenir à jour soi-même les modèles d'événements GPT-Live. C'est faisable mais fragile tant que l'API évolue.
- Dépendance à un mainteneur unique (davidmiguel.com) pour OpenAI et Gemini. Mitigation : encapsuler derrière les ports VoiceProvider et LlmClient, pour pouvoir revenir au HTTP/WS brut.
- Écart de versions entre a2ui_core 0.3 et genui (^0.1) : le serveur produit du v1.0 que le client genui actuel ne sait pas rendre. Il faut figer l'A2UI v0.9 en phase 1 tant que genui n'a pas migré.
- mcp_dart affirme passer les suites de conformité 2025-11-25 et 2026-07-28, y compris l'autorisation. C'est une auto-déclaration à confirmer par nos propres tests OAuth contre les serveurs MCP cibles.
- Résilience des sessions longues : reconnexion du sideband, backpressure audio (copie PCM base64 sur le sideband) et fuite de connexions en cas de crash. Le scheduler Dart est mono-thread par isolate, il faut prévoir des isolates ou plusieurs instances.
- Doubles écritures sur les appels d'outils si l'app (outils locaux) et le sideband répondent tous les deux. Il faut un seul propriétaire par délégation, à faire respecter dans ui_contract.
- Gouvernance : si le spike échoue, on bascule en Go pour l'orchestrateur. Le package ui_contract garde alors sa valeur côté Flutter, mais le partage serveur est perdu.

**Plan phase 1**
- S0 : créer un workspace pub avec packages/ui_contract (Dart pur) : catalogue métier en JSON Schema versionné par URI, enveloppe WS app ↔ orchestrateur (sealed classes + json_serializable), ids de délégation. Figer l'A2UI en v0.9 tant que genui dépend de a2ui_core ^0.1.
- S1, spike go/no-go (5 jours) : service shelf avec POST /voice/sessions (relais SDP vers /v1/live/sessions, delegation.type=client), puis attach sideband. Tester d'abord openai_dart 11, et en repli dart:io WebSocket.connect(headers). Critères : délégation reçue, thinking.append et commentary.append acquittés, session.close propre, latence ajoutée inférieure à 50 ms.
- S1 : émission des jetons Gemini (googleai_dart Auth Tokens, liveConnectConstraints) et vérification App Check (firebase_admin_sdk), derrière un port VoiceProvider commun.
- S2 : auth Keycloak (vérification JWT sur JWKS en cache), quotas par utilisateur et origine, route Kong HTTP/WS vers voice_orchestrator dans infra/kong/kong.yml.
- S2 : routeur delegate et agent GenUI (LLM via openai_dart Responses) avec validation a2ui_core avant envoi, rejet puis régénération (2 essais au maximum), filtrage openUrl/Image, envoi sur le WebSocket vers l'app (genui côté client).
- S3 : client MCP mcp_dart (Streamable HTTP + OAuth) vers un premier serveur MCP métier, liste blanche des serveurs et journal d'audit.
- S3 : pont gRPC Dart vers les services Go (protoc --dart_out sur les .proto du kit). Les tâches longues sont déclenchées via un RPC Go qui démarre un workflow Temporal, et le résultat revient par push sur le canal WS.
- S3 : observabilité avec dartastic_opentelemetry : spans invoke_agent/execute_tool à la main, gen_ai.conversation.id = session.id, traceparent propagé depuis l'app, export OTLP vers le collecteur SigNoz du docker-compose.
- S4 : tests. Unitaires Dart sur le routeur et le validateur. Scénarios Gherkin Godog en boîte noire contre le conteneur Dart, avec un faux serveur Live (WS) et Postgres et Keycloak en testcontainers. Image AOT et stage Azure Pipelines.
- Fin de phase 1 : réévaluer la décision Dart sur trois points. La couverture GPT-Live de openai_dart a-t-elle tenu ? genui est-il passé à a2ui_core 0.3 ? Existe-t-il une voie A2A v1.0 ? Sinon, on porte l'orchestrateur en Go en gardant ui_contract.

**Intégration saaster kit** : Je ne propose pas de réécrire le saaster kit : le Dart s'ajoute comme un service de plus. Voici ce qui se réutilise concrètement.
(1) Contrats gRPC : les .proto de /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service/proto/customer.proto sont compilés aussi en Dart (protoc-gen-dart, package grpc 5.2). L'orchestrateur appelle les services Go comme un client de plus. Le Makefile du service (cible proto) gagne une sortie --dart_out.
(2) Temporal : les tâches longues restent des workflows Go (customer_service/internal/workflows/*.go, internal/adapters/temporal/client.go). Le Dart les déclenche par un RPC Go dédié, car il n'existe pas de SDK Temporal Dart.
(3) Architecture hexagonale : on reproduit le découpage internal/{domain,application,ports/in,ports/out,adapters} en lib/src/{domain,application,ports,adapters}. Les ports sortants sont VoiceProvider, LlmClient, McpGateway, A2uiValidator et Telemetry, sur le modèle de ports/out/observability.go.
(4) Observabilité : on aligne le service Dart sur adapters/observability/otel_facade.go (mêmes noms de ressources, même collecteur SigNoz que dans /home/bfontaine/septeo/septeo_saaster_kit/docker-compose.yml) et on exporte en OTLP gRPC.
(5) Auth : Keycloak (service keycloak du docker-compose) émet les JWT. Le Dart les vérifie via JWKS : openid_client (à valider) ou une vérification JWT maison sur JWKS en cache. Pour Gemini, il faut en plus firebase_admin_sdk pour App Check.
(6) Kong (/home/bfontaine/septeo/septeo_saaster_kit/infra/kong/kong.yml) gagne une route HTTP/WebSocket simple vers voice_orchestrator. Le service n'a pas besoin de la transcodification gRPC→REST.
(7) Tests : Godog et testcontainers-go (customer_service/tests/testcontainers.go, tests/features/*.feature) ne se transposent pas directement. Deux options : écrire les scénarios Gherkin de l'orchestrateur côté Go en boîte noire (Godog qui pilote le service Dart en conteneur via HTTP/WS, avec un faux serveur OpenAI Live), ou faire du Gherkin Dart, outillage à vérifier. Je recommande la première pour garder un seul runner BDD.
(8) CI : azure-pipelines.yml (stages Docker@2) ajoute une image Dart AOT (dart compile exe, image scratch/distroless) sur le même modèle que customer_service/docker/Dockerfile.

### Hybride Go + Python. Un service Go « voice-gateway », nouveau module hexagonal dans septeo_saaster_kit/backend, s'occupe de l'auth Keycloak, du relais SDP GPT-Live, des jetons Gemini, du sideband WebSocket, des quotas, du canal app WS/SSE, de Temporal et d'OTel. Il appelle en client A2A v1.0 (a2a-go/v2) un service Python « agents-runtime » (ADK 2.13 + a2a-sdk 1.2.x + a2ui-agent-sdk/a2ui-core + MCP), qui porte tous les appels LLM, l'agent GenUI et les clients MCP/A2A sortants. Le service Python ne s'expose qu'au gateway, jamais directement à l'app.

Je recommande de couper le backend en deux à une frontière nette. Go garde tout ce qui touche aux connexions, à la sécurité et à l'état de session : auth, relais SDP, jetons Gemini, sideband GPT-Live, quotas, canal app, Temporal. Python ne fait que du raisonnement LLM : routeur LLM, agent GenUI qui produit et valide l'A2UI, outils MCP, puis agents A2A tiers. Ce partage tient à un constat vérifié : la brique la plus spécifique du projet, l'outillage A2UI côté agent (a2ui-agent-sdk, a2ui-core, intégration ADK), n'existe qu'en Python. Le reste (sideband, SDP, quotas, WebSocket) relève de l'infra Go que l'équipe maîtrise déjà dans le saaster_kit. Le surcoût de latence est un saut réseau interne, de l'ordre de 2 à 15 ms par délégation selon mon estimation, négligeable face aux 300 à 1500 ms d'un premier token LLM et au délai d'accusé vocal d'environ 800 ms. Les vrais coûts sont ailleurs : deux langages, deux pipelines CI, et un saaster_kit qui doit d'abord corriger sa validation JWT et monter sa version de Go.

**Composants**
- voice-gateway (Go) – adaptateur entrant HTTP/WS — Expose POST /voice/sessions {provider, agentProfile} derrière une auth Keycloak avec JWT vérifié par JWKS. Pour GPT-Live, relaie l'offre SDP vers POST /v1/live/sessions avec delegation.type='client' et renvoie l'answer. Pour Gemini, émet un jeton v1beta/auth_tokens (uses=1, newSessionExpireTime 1 min, liveConnectConstraints qui verrouillent le modèle et l'instruction système). Contrôle l'origine, le débit et les quotas par utilisateur et par tenant. (Go 1.26, net/http, openai-go v3 (client.Live.New), google.golang.org/genai (Tokens.Create), golang-jwt/v5 avec JWKS Keycloak)
- voice-gateway – SidebandSupervisor — Ouvre une connexion WebSocket par session GPT-Live sur wss://api.openai.com/v1/live/sessions/{id}/attach. Accumule input_transcript.delta et output_transcript.delta pour reconstruire la demande, car session.delegation.created arrive sans les mots de l'utilisateur. Seul propriétaire de chaque delegation.id. Réinjecte session.thinking.append, commentary.append et instructions.append, avec un event_id unique et 500 tokens maximum par message. Gère mute, close et hangup, la reconnexion et l'idempotence. (Go, github.com/coder/websocket ou gorilla/websocket (pas de helper sideband dans openai-go : protocole écrit à la main), goroutine par session)
- voice-gateway – DelegationBroker (port out AgentRuntime) — Traduit chaque délégation (GPT-Live) ou appel de fonction delegate (Gemini, renvoyé par l'app) en tâche A2A SendStreamingMessage vers le service Python, avec contextId = id de session vocale et métadonnées utilisateur, tenant, catalogues supportés et traceparent. Répartit le flux reçu : parts texte « speakable » vers commentary.append, parts « silent » vers thinking.append, DataPart application/json+a2ui vers le canal app. Sur barge-in ou annulation : CancelTask, puis annonce une fois l'annulation confirmée. (a2a-go/v2 (a2aclient), binding JSON-RPC+SSE ou gRPC, interface hexagonale ports/out)
- voice-gateway – AppChannel — Une connexion WebSocket (ou SSE en repli) par session app, authentifiée par le JWT. Pousse les messages A2UI v0.9 après une seconde validation contre le schéma du catalogue client versionné. Remonte les actions utilisateur typées et les résultats d'outils locaux. Côté Flutter, adaptateur maison vers SurfaceController/Transport genui. (Go WebSocket, validation JSON Schema 2020-12 (ex. santhosh-tekuri/jsonschema), route Kong en protocole ws/wss)
- voice-gateway – LongTasks — Les tâches longues (> quelques secondes) deviennent des workflows Temporal. Les activités qui appellent des LLM s'exécutent dans un worker Python sur une task queue dédiée. Le résultat est poussé à l'app (canal ou FCM) et dans la session vocale si elle est encore active. (go.temporal.io/sdk v1.50 (déjà dans le kit), temporalio Python pour les activités agents)
- agents-runtime (Python) – Orchestrator agent — Serveur A2A v1.0 interne, non exposé à l'app. Un routeur déterministe (règles, sortie structurée) traite les cas fréquents, un LLM ne sert que de repli. Appelle l'agent GenUI et les outils MCP en agent-as-tool. Renvoie deux sorties distinctes : un résumé parlable réel (jamais de faux {status:ok}) et des parts A2UI. (google-adk 2.13 (LlmAgent, AgentTool, mode single_turn), a2a-sdk 1.2.x[http-server])
- agents-runtime – GenUI agent — Produit l'A2UI v0.9 à partir du catalogue métier négocié (supportedCatalogIds transmis par le gateway). Fait une première validation avec parse_response_to_parts : en cas de rejet, nouvelle génération, sinon repli texte. Emballe le résultat en DataPart application/json+a2ui. (a2ui-agent-sdk (A2uiSchemaManager), a2ui-core 0.4.0 (Pydantic + JSON Schema 2020-12))
- agents-runtime – MCP/A2A clients — Outils métier en MCP 2026-07-28 Streamable HTTP. Les identifiants utilisateur arrivent du gateway par requête (token exchange Keycloak, courte durée) et ne sont jamais stockés dans les prompts. Agents A2A tiers en phase 2. Allowlist d'URL contre le SSRF et journal d'audit. (ADK McpToolset / mcp (PyPI 2.3.0), a2a-sdk client)
- Observabilité transverse — Une trace par session vocale (gen_ai.conversation.id = id de session). Le gateway ouvre invoke_agent orchestrator ; Python ajoute execute_tool et invoke_agent genui. traceparent propagé dans les métadonnées A2A. Attributs delegation.id et latence jusqu'au premier audio. Contenus et transcripts en opt-in uniquement. (OTel Go 1.35+ (déjà câblé dans le kit vers SigNoz), opentelemetry-sdk Python, conventions gen_ai.* (statut Development))

**Affirmations SDK**
- a2a-go dernière release v2.7.0 (2026-10-21) ; v2.4.0 ajoute la compatibilité filaire REST v0.3 ; la ligne 0.3.x (v0.3.15) existe encore. — https://github.com/a2aproject/a2a-go/releases
- Le README d'a2a-go cible la spécification A2A v1.0 et s'installe avec go get github.com/a2aproject/a2a-go/v2. Il demande Go 1.26.0 ou plus et fournit les bindings gRPC, REST et JSON-RPC (a2asrv, a2aclient.NewFromCard). — https://github.com/a2aproject/a2a-go
- go.mod d'a2a-go/v2 : 'go 1.26.0'. go.mod du MCP go-sdk : 'go 1.25.0'. Le saaster_kit est en go 1.23.0 avec toolchain go1.24.3 : un passage à Go 1.26 est obligatoire. — https://raw.githubusercontent.com/a2aproject/a2a-go/main/go.mod
- a2a-sdk (Python) 1.2.3 (2026-10-19) implémente la spécification A2A v1.0 avec un mode de compatibilité 0.3 ; Python 3.10 ou plus. — https://pypi.org/project/a2a-sdk/
- google-adk (Python) 2.13.0 (2026-10-23) propose les extras optionnels a2a et mcp ; son pyproject contraint a2a-sdk>=0.3.4,<2 et mcp>=1.24,<3. — https://raw.githubusercontent.com/google/adk-python/main/pyproject.toml
- L'intégration A2UI d'ADK n'est documentée que pour Python (pip install a2ui-agent-sdk, A2uiSchemaManager, parse_response_to_parts). Elle cible A2UI v0.9 et transporte l'A2UI en DataPart A2A de type application/json+a2ui. — https://adk.dev/integrations/a2ui/
- a2ui-core 0.4.0 (2026-10-17), Python 3.10 ou plus : validation Pydantic + JSON Schema 2020-12 contre les catalogues, cible A2UI v0.9 et suivantes ; aucun équivalent Go mentionné. — https://pypi.org/project/a2ui-core/
- ADK Go existe et est actif : v2.6.0 (13 oct.), avec A2A, mcptoolset, Gemini Live (RunLive) et un modèle OpenAI. Son go.mod est en go 1.26.10 et dépend de a2a-go/v2 v2.6.0 et du MCP go-sdk v1.8.0. Une option tout-Go reste donc crédible pour l'orchestration, mais pas pour l'A2UI. — https://github.com/google/adk-go/releases
- MCP go-sdk v1.8.0 : spécification 2026-07-28 prise en charge depuis v1.7.0 (Streamable HTTP en mode Stateless) et repli sur 2025-11-25 ; gestionnaires OAuth client (ClientCredentialsHandler, AuthorizationCodeHandlerConfig). — https://github.com/modelcontextprotocol/go-sdk/releases
- openai-go expose client.Live.New (POST /live/sessions) avec MediaSessionConfigModelGPTLive1 et une transport SDP WebRTC ; la page ne documente aucune méthode Go d'attachement sideband. — https://developers.openai.com/api/reference/go/resources/live/methods/create
- openai-go v3.88.0 (2026-10-26) : changement cassant sur les champs Live (v3.86.0) et ajout de helpers WebSocket bruts (v3.83.0) ; aucune entrée sur le sideband. — https://github.com/openai/openai-go/releases
- Sideband GPT-Live : wss://api.openai.com/v1/live/sessions/{session_id}/attach, Bearer avec la clé du même projet. Le serveur envoie session.thinking.append, session.commentary.append, session.instructions.append, response.item.create/response.create, session.close. La page ne contient d'exemple d'attachement complet dans aucun langage. — https://developers.openai.com/api/docs/guides/voice-server-controls?api=live
- openai-python v3.35.0 (2026-10-17) ajoute des événements sideband Live typés ; dernière version v3.39.0 (2026-10-26). Le support du sideband est donc plus avancé en Python qu'en Go. — https://github.com/openai/openai-python/releases
- google.golang.org/genai v1.76.0 (2026-10-22) expose AuthToken, CreateAuthTokenConfig, Tokens.Create et l'API Live. — https://pkg.go.dev/google.golang.org/genai
- Le guide des jetons éphémères Gemini ne donne des exemples qu'en Python, JS et REST, sans exemple Go. Valeurs par défaut : expireTime 30 min, newSessionExpireTime 1 min, uses 1, liveConnectConstraints. — https://ai.google.dev/gemini-api/docs/ephemeral-tokens
- genui_a2a 0.10.1 (pub.dev) : A2uiAgentConnector vers un serveur A2A. La version A2A n'est pas indiquée et la description (WebSocket vs dépendance sse_channel) est ambiguë. — https://pub.dev/packages/genui_a2a
- go.temporal.io/sdk v1.50.0 publié le 2026-10-15 (le kit est en v1.34.0). — https://pkg.go.dev/go.temporal.io/sdk
- SDK Python mcp 2.3.0 (2026-10-02) ; la page PyPI ne précise pas la version de spec MCP prise en charge. — https://pypi.org/project/mcp/

**Forces**
- Frontière motivée par des faits : l'outillage A2UI côté agent (a2ui-agent-sdk, a2ui-core, intégration ADK) n'est documenté qu'en Python, alors que SDP, sideband, quotas et WebSocket sont de l'infra où Go et le saaster_kit excellent.
- La frontière est un contrat standard, A2A v1.0, avec des SDK officiels des deux côtés (a2a-go/v2, a2a-sdk 1.2.x). Le même contrat sert ensuite en phase 2 pour les agents tiers, et éventuellement pour genui_a2a côté app.
- Aucun secret LLM ni MCP dans l'app, aucune connexion publique vers Python : le gateway est le seul point d'entrée, avec l'auth, les quotas et l'audit en un seul endroit.
- Le sideband reste dans Go, ce qui donne un seul propriétaire par delegation.id, l'idempotence par event_id et la reconstruction du contexte depuis les transcripts, sans risque de double réponse.
- Latence ajoutée faible et bornée : un saut interne, gRPC ou HTTP/2 keep-alive dans le même cluster, d'environ 1 à 5 ms en gRPC et 5 à 15 ms en JSON-RPC+SSE (estimation, non mesurée). C'est inférieur à 2 % d'une délégation typique (premier token LLM de 300 à 1500 ms). Le streaming A2A permet d'envoyer le premier commentary.append avant la fin de la tâche.
- Réutilise directement l'existant Go : hexagonal, Temporal, OTel/SigNoz, Godog, Keycloak, Kong, Docker. L'équipe Go travaille sur un terrain connu.
- Le cycle de vie des agents (prompts, modèles, ADK) évolue vite. L'isoler dans un service Python déployable seul limite le rayon d'impact sur le gateway, qui reste stable.
- Temporal est polyglotte : le workflow peut vivre en Go et les activités LLM en Python sur une task queue dédiée, ce qui donne une vraie reprise sur erreur pour les tâches longues.

**Faiblesses**
- Deux langages, deux runtimes, deux CI et deux jeux de dépendances, pour une équipe Flutter + Go sans compétence Python établie. C'est la principale faiblesse.
- ADK Go existe et est actif (v2.6, A2A, MCP, OpenAI, Live). Une option tout-Go est donc viable pour l'orchestration. L'argument hybride repose surtout sur l'A2UI Python, qui pourrait perdre sa force si un SDK A2UI Go apparaît, ou si l'on valide l'A2UI simplement par JSON Schema en Go.
- Le sideband n'a pas de helper dans openai-go : protocole WebSocket écrit à la main en Go, alors qu'openai-python a des événements sideband typés depuis v3.35.0. Sur ce point, Python serait plus confortable.
- Le passage par A2A ajoute de la sérialisation (JSON/Protobuf), une conversion des Parts vers les événements GPT-Live et un second schéma de contrat à versionner. Si les deux équipes ne le testent pas ensemble, le contrat dérive.
- Il faut propager traceparent, l'identité utilisateur et les identifiants délégués à travers la frontière. Une erreur de propagation casse soit l'observabilité, soit l'autorisation MCP.
- ADK pin a2a-sdk <2 alors qu'a2a-sdk est en 1.2.x. C'est compatible aujourd'hui, mais à surveiller. A2UI v1.0 est encore en RC et l'intégration ADK cible v0.9.
- Deux saisies d'A2UI (validation Python, puis seconde validation Go) : il faut synchroniser le schéma du catalogue entre l'app Flutter, Python et Go, idéalement depuis une source unique versionnée par URI.

**Risques**
- Sécurité héritée : la validation JWT non vérifiée (ParseUnverified) et le CORS * du kit, recopiés dans le gateway, rendraient le relais SDP exploitable pour brûler le quota OpenAI ou Gemini.
- Montée de Go 1.23/1.24 vers 1.26 : elle touche aussi customer_service si l'on partage go.work, avec des risques de régression et des mises à jour transitives (grpc, otel, temporal v1.34 vers v1.50).
- API GPT-Live jeune : openai-go a déjà eu un changement cassant sur les champs Live le 2026-10-23. Le protocole sideband est écrit à la main, donc chaque évolution d'événement doit être suivie.
- Ordre de boucle : si la tâche Python dépasse le délai d'accusé (acknowledgement_delay_ms), il faut un commentary.append intermédiaire. Sinon, silence ou accusé générique.
- Barge-in : interrompre la voix n'annule pas la tâche Python. CancelTask doit être propagé et l'annulation confirmée avant de l'annoncer, sinon l'action est exécutée sans que l'utilisateur l'ait entendue.
- Gemini Live : il n'y a pas de sideband. L'appel delegate passe par l'app, puis le canal app, puis le gateway. C'est un chemin différent de GPT-Live, avec un saut de plus côté client, et NON_BLOCKING n'est pas disponible dans firebase_ai.
- Les conventions OTel gen_ai sont encore au statut Development : les noms d'attributs peuvent changer.
- genui_a2a : version A2A et transport ambigus. Ne pas en dépendre en phase 1 ; le canal WS maison vers genui est plus sûr.
- Dette d'équipe : sans responsable Python désigné, le service agents deviendra le maillon fragile (packaging, async, montée de versions ADK tous les quinze jours).

**Plan phase 1**
- 0. Prérequis du kit : remplacer ParseUnverified par une vérification JWKS Keycloak (iss, aud, exp), restreindre le CORS de Kong, passer à Go 1.26 dans un module dédié backend/voice_gateway (go.work séparé si besoin), et faire lancer go test et Godog par azure-pipelines.yml.
- 1. Contrat d'abord : écrire le contrat interne. Il comprend un profil A2A v1.0 (Agent Card interne, métadonnées userId, tenant, supportedCatalogIds, traceparent, transcript), les conventions de Parts (text/speakable, text/silent, application/json+a2ui) et le catalogue A2UI v0.9 métier versionné par URI, partagé entre Flutter, Python et Go. Puis les scénarios Gherkin : création de session, délégation, annulation, quota dépassé.
- 2. Gateway Go, partie session : POST /voice/sessions. Pour GPT-Live : openai-go client.Live.New avec delegation.type='client' et acknowledgement_delay_ms explicite. Pour Gemini : genai Tokens.Create avec uses=1 et liveConnectConstraints. Vérification d'origine, rate limit, table Postgres sessions/quotas, tests BDD avec testcontainers et un faux serveur OpenAI.
- 3. Gateway Go, sideband : SidebandSupervisor sur une WebSocket par session, avec tampon de transcripts, machine à états des délégations (propriétaire unique, event_id idempotents, limite de 500 tokens) et session.close/hangup. Tests contre un faux serveur WebSocket rejouant des traces enregistrées.
- 4. Service Python agents-runtime (uv, Python 3.12) : serveur A2A a2a-sdk 1.2.x, orchestrateur ADK avec routeur déterministe d'abord, et agent GenUI avec a2ui-agent-sdk qui valide puis génère à nouveau en cas de rejet. Un premier outil MCP 2026-07-28 Streamable HTTP. pytest avec un LLM simulé.
- 5. DelegationBroker Go : client a2a-go/v2 SendStreamingMessage vers commentary/thinking.append et vers AppChannel. CancelTask sur annulation. Seconde validation JSON Schema du catalogue avant envoi à l'app.
- 6. AppChannel : route Kong wss, WebSocket authentifiée, adaptateur Flutter vers le Transport/SurfaceController de genui. Les actions utilisateur et l'appel delegate Gemini remontent par le même canal.
- 7. Observabilité : une trace par session (gen_ai.conversation.id), invoke_agent et execute_tool des deux côtés, propagation de traceparent via les métadonnées A2A, tableaux de bord SigNoz avec le temps entre délégation et premier commentary, et le surcoût du saut Go vers Python mesuré pour valider l'estimation de 2 à 15 ms.
- 8. Tâches longues : workflow Temporal Go, activités Python sur la task queue agents, résultat poussé vers l'app et la session vocale si elle est encore ouverte.
- 9. Point de décision en fin de phase 1 : si le surcoût d'exploitation Python est jugé trop élevé et que l'A2UI peut être validée par JSON Schema seule, évaluer la migration de l'orchestrateur vers ADK Go sans toucher au gateway. La frontière A2A rend ce changement local.

**Intégration saaster kit** : Ce qui se réutilise tel quel, dans /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service :
- La structure hexagonale : internal/{domain/entities, ports/in, ports/out, adapters/{grpc,repositories,temporal,observability,logger}, application/services}, et le câblage DI dans cmd/main.go.
- La façade OTel (internal/adapters/observability/otel_facade.go) déjà branchée sur SigNoz, et le logger.
- Le client et les workflows Temporal (internal/adapters/temporal/client.go, internal/workflows/customer_workflows.go comme modèle).
- La chaîne BDD Godog + testcontainers (tests/testcontainers.go, tests/features/*.feature, tests/steps/*), à étendre avec des scénarios « session voix », « délégation » et « quota ».
- Le Makefile (build, test, proto, migrate-*) et les migrations Postgres, pour les quotas, l'audit et le registre des sessions.
- Les services keycloak, temporal, signoz et postgres du docker-compose.yml racine, et kong.yml pour ajouter des routes HTTP et ws/wss.

Je propose de créer un module frère backend/voice_gateway avec la même arborescence et de copier le moteur d'interceptors gRPC de server.go.

Prérequis bloquants constatés dans le code :
1. server.go valide le JWT avec jwt.Parser.ParseUnverified (ligne 137), et aucun plugin JWT/OIDC n'est configuré dans infra/kong/kong.yml. N'importe qui peut forger un token avec le rôle saaster-admin. Pour le relais voix, qui dépense de l'argent OpenAI ou Gemini, il faut une vérification de signature par JWKS Keycloak, ou un plugin OIDC dans Kong.
2. go.mod est en go 1.23.0 / toolchain go1.24.3, alors qu'a2a-go/v2 exige Go 1.26 et le MCP go-sdk Go 1.25.
3. CORS dans Kong : origins ["*"] avec credentials:true. Il faut l'allowlist d'origines exigée par le relais SDP.
4. azure-pipelines.yml ne fait que des builds Docker, sans aucun test, alors qu'il faudra ajouter un pipeline Python (uv, pytest, ruff).
5. Kong grpc-gateway ne transcode que les unaires : le canal app WebSocket/SSE et le relais SDP passent par des routes HTTP/ws simples, sans transcodage.

### Go 1.26 (monorepo hexagonal dans la continuité de septeo_saaster_kit) : openai-go/v3 (package live : création de session + sideband WebSocket), google.golang.org/genai (Live + AuthTokens), modelcontextprotocol/go-sdk v1.8 (MCP 2026-07-28), a2aproject/a2a-go/v2 (A2A v1.0, phase 2), google.golang.org/adk/v2 (agent GenUI + routeur LLM optionnel), A2UI : validation maison contre le JSON Schema du catalogue (google/jsonschema-go), Genkit a2ui/exp seulement en option, Temporal sdk-go v1.50 + go.temporal.io/googleadk pour les tâches longues, OTel Go → SigNoz, Postgres, Keycloak (JWT vérifiés par JWKS), canal app en WebSocket (coder/websocket) derrière Kong

Au 2026-10-27, l'option tout-Go est crédible. Le SDK officiel openai-go/v3 couvre déjà GPT-Live de bout en bout : client.Live.New (POST /live/sessions), client.Live.Sideband.Connect (GET live/sessions/{id}/attach), les événements session.delegation.created, commentary.append et thinking.append, ainsi que Hangup et Fork. On n'a donc ni WebSocket ni relais SDP à écrire à la main. go-genai expose Live et AuthTokens.Create (encore marqué expérimental), le go-sdk MCP gère complètement la spec 2026-07-28 depuis la v1.7.0, et a2a-go/v2 cible A2A v1.0. ADK Go v2 et l'intégration Temporal go.temporal.io/googleadk rendent l'orchestrateur durable sans changer de langage. Il y a toutefois un vrai trou : aucun SDK A2UI officiel en Go (l'officiel existe en Python, TS, Dart, Kotlin et Swift ; le plugin Genkit Go est en preview et documenté pour v0.9). Il faut donc écrire une couche de génération et de validation A2UI maison. Autre point : le kit Septeo est en Go 1.23/1.24 alors que ces SDK exigent Go 1.26 ou plus, et son intercepteur JWT ne vérifie pas la signature des jetons.

**Composants**
- voice-session (adapter in) — Route authentifiée de relais SDP : reçoit l'offre du client Flutter, applique les quotas et la vérification d'origine, appelle client.Live.New avec delegation.type=client, renvoie la réponse SDP, stocke session.id et le user_id en base, puis démarre l'attache sideband. Côté Gemini, émet un jeton éphémère (AuthTokens.Create avec LiveConnectConstraints, uses=1). (net/http ou gRPC + Kong, openai-go/v3/live, google.golang.org/genai, Postgres)
- sideband-supervisor — Une goroutine par session : Sideband.Connect, boucle Recv, reconstitue le contexte depuis input/output_transcript.delta, transmet chaque session.delegation.created au port Orchestrator, renvoie commentary.append et thinking.append (500 tokens au plus, event_id unique), gère l'annulation sur barge-in, la reconnexion (Reconnect) et la séquence session.close → closed. Affinité de session : le supervisor tourne sur le pod qui détient la WS. (openai-go/v3/live SidebandConnection, context.Context, errgroup)
- orchestrator (application service) — Port in.Orchestrator.Handle(delegation) : routeur déterministe d'abord, routeur LLM ensuite si nécessaire. Appelle comme outils l'agent GenUI, les toolsets MCP et, en phase 2, les agents A2A. Produit deux sorties distinctes : un résumé parlable, et des messages A2UI envoyés au canal app. Pas de faux {status: ok}. (Go hexagonal (ports/in, ports/out), ADK Go v2 llmagent/AgentTool optionnel)
- genui-agent — Agent LLM qui génère l'A2UI (v0.9 aligné sur genui 0.10, puis v1.0) à partir du catalogue métier versionné. Le JSON est validé contre le JSON Schema du catalogue avant l'envoi : en cas de rejet, nouvelle génération bornée. Contrôle aussi les URLs d'Image/openUrl (allowlist) et l'absence de secrets dans le data model. (ADK Go v2 (model gemini ou openaimodel) ou openai-go Responses, google/jsonschema-go, types A2UI générés depuis specification/v0_9 et v1_0)
- mcp-gateway (adapter out) — Clients MCP vers les serveurs métier en Streamable HTTP, sans état (2026-07-28) avec repli sur initialize. Gère OAuth (authorization_code, client_credentials), une allowlist d'hôtes contre le SSRF et un journal d'audit des appels. (github.com/modelcontextprotocol/go-sdk v1.8.0 (mcp, auth, auth/extauth))
- a2a-gateway (phase 2) — Client A2A v1.0 vers des agents spécialisés : Agent Card signée, tasks longues, streaming SSE et push. Peut aussi exposer l'orchestrateur en A2A pour genui_a2a. (github.com/a2aproject/a2a-go/v2 v2.7.0, adk-go server/adka2a/v2)
- app-channel — Canal serveur → Flutter : messages A2UI (createSurface, updateComponents, updateDataModel), état de délégation, et retour des actions utilisateur typées. Clé de corrélation : session_id + delegation_id. Propagation de traceparent. (WebSocket (github.com/coder/websocket) ou SSE derrière Kong, Postgres/Redis pour le fan-out multi-pod)
- long-tasks — Délégations longues (plus de quelques secondes) : workflow Temporal. Chaque appel LLM et chaque appel MCP devient une activité rejouable. Annulation via signal sur barge-in. Notification par le canal app ou par FCM. (go.temporal.io/sdk v1.50.0, go.temporal.io/googleadk (ADK dans un Workflow), infra Temporal existante)
- identity/quotas/observability — Vérification réelle des JWT Keycloak (JWKS, iss, aud, exp), quotas par utilisateur et par tenant (minutes voix, tokens), spans gen_ai.* (invoke_agent orchestrator, execute_tool, invoke_agent genui) avec gen_ai.conversation.id = session.id, export OTLP vers SigNoz. (golang-jwt/v5 + keyfunc JWKS, Kong rate-limiting, OpenTelemetry Go SDK, télémétrie ADK Go (semconv gen_ai))

**Affirmations SDK**
- openai-go v3 contient un package live : client.Live.New (POST /live/sessions) et client.Live.Sessions avec Accept, Fork, Hangup, Refer, Reject et DownloadRecording. — https://github.com/openai/openai-go/blob/main/live/api.md
- openai-go v3 fournit SidebandService.Connect(ctx, sessionID, ...), qui ouvre un WebSocket GET sur live/sessions/{id}/attach, avec Send, Recv, SendRaw, RecvRaw, Close et Reconnect. — https://github.com/openai/openai-go/blob/main/live/live_sideband_websocket.go
- Les événements sideband typés dans openai-go v3 incluent session.delegation.created, session.commentary.append/appended, session.thinking.append/appended, session.instructions.append, session.input_transcript.delta, session.output_transcript.delta, session.input_audio.mute et session.close/closed. — https://github.com/openai/openai-go/blob/main/live/sideband.go
- openai-go v3 exige go 1.26.0 dans son go.mod. Les releases sont très fréquentes : v3.83.0 à v3.88.0 entre le 20 et le 26 octobre 2026. Le commit « add delegation controls » date du 2026-10-23. — https://github.com/openai/openai-go/releases
- google.golang.org/genai v1.76.0 (22 oct. 2026) expose Live.Connect et LiveConnectConstraints. Le service de jetons est accessible par client.AuthTokens (type Tokens) avec Create(ctx, *CreateAuthTokenConfig) ; il journalise que « The SDK's ephemeral tokens implementation is experimental ». Le module exige go 1.24. — https://github.com/googleapis/go-genai/blob/main/tokens.go
- Les types Live et AuthToken / CreateAuthTokenConfig sont documentés dans le package genai. — https://pkg.go.dev/google.golang.org/genai
- modelcontextprotocol/go-sdk v1.7.0 (28 juil. 2026) apporte la prise en charge complète du protocole 2026-07-28 (server/discover, mode Stateless en Streamable HTTP, repli sur initialize). v1.8.0 (14 sept. 2026) est la dernière version. ClientCredentialsHandler OAuth existe depuis la v1.6.0. — https://github.com/modelcontextprotocol/go-sdk/releases
- a2a-go : le module github.com/a2aproject/a2a-go/v2 cible la « v1.0 Protocol Specification », avec les bindings gRPC, REST et JSON-RPC, et exige Go 1.26.0. Dernière version : v2.7.0 du 21 oct. 2026. La couche a2acompat/a2av0 assure la compatibilité v0.3. — https://github.com/a2aproject/a2a-go
- ADK Go v2 (module google.golang.org/adk/v2, go 1.26.10) dépend de modelcontextprotocol/go-sdk v1.8.0, openai-go/v3, genai v1.75.0, et à la fois de a2a-go v0.3.15 et de a2a-go/v2 v2.6.0. Le serveur adka2a a un sous-package v2. Dernière version : v2.6.0 (13 oct. 2026). La branche v1 est maintenue en parallèle (v1.9.0). — https://github.com/google/adk-go/blob/main/go.mod
- Les releases ADK Go v2.x corrigent le streaming live, les toolsets MCP et l'authentification A2A par requête (v2.6.0). — https://github.com/google/adk-go/releases
- Temporal fournit une intégration Go pour ADK (go.temporal.io/googleadk) : chaque appel LLM devient une Activity durable, NewMCPToolset est disponible, et le plancher est Go 1.26.6. Elle a quitté sdk-go/contrib pour temporalio/ai-integrations. — https://github.com/temporalio/ai-integrations/tree/main/go/googleadk
- Temporal Go SDK : dernière version v1.50.0, publiée le 15 oct. 2026. Le kit Septeo est encore en v1.34.0. — https://github.com/temporalio/sdk-go/releases
- Il n'existe pas de SDK A2UI Go officiel. Le dépôt a2ui-project/a2ui contient des implémentations dart, kotlin, python, swift et typescript, et des spécifications v0_8, v0_9, v0_9_1 et v1_0. Les releases récentes sont Python (a2ui-agent-sdk v0.9.0, a2ui-adk v0.1.0, 17 oct. 2026). — https://github.com/a2ui-project/a2ui
- Genkit Go propose un plugin A2UI (github.com/firebase/genkit/go/plugins/a2ui/exp) en preview. Il offre un mode Validate warn, strict ou off, sur la structure et les noms de composants seulement, sans assainissement des valeurs. La version v0.9 est documentée par défaut. — https://genkit.dev/docs/agents/a2ui/
- google/jsonschema-go (v0.4.3) valide des valeurs JSON contre un schéma et infère des schémas depuis des structs Go, sans dépendance hors stdlib. — https://github.com/google/jsonschema-go

**Forces**
- Continuité totale avec l'équipe et l'existant : même langage, même hexagonal, même Temporal, même OTel/SigNoz, même BDD Godog + testcontainers. Pas de deuxième runtime à opérer.
- GPT-Live est couvert par le SDK officiel (openai-go/v3/live) : création de session, sideband attach typé, Reconnect, Hangup, Fork. C'est le composant le plus critique, et il n'y a ni protocole à écrire à la main ni version Python à attendre.
- Go est très adapté au supervisor sideband : une goroutine et un WebSocket longue durée par session, une annulation propre par context.Context, une faible empreinte mémoire pour des milliers de sessions simultanées.
- Les SDK officiels Go existent et sont à jour pour tous les protocoles : MCP go-sdk (2026-07-28 complet depuis v1.7.0), a2a-go/v2 (A2A v1.0, trois bindings), go-genai (Live + AuthTokens), ADK Go v2 (multi-modèles gemini/openai, MCP, A2A, télémétrie gen_ai).
- Durabilité native : go.temporal.io/googleadk transforme un agent ADK en Workflow Temporal (LLM et MCP en Activities rejouables), ce qui sert directement les tâches longues et l'annulation sur barge-in.
- Binaire statique, image Docker minime, démarrage rapide : adapté à la CI Azure et au déploiement existant.

**Faiblesses**
- Pas de SDK A2UI Go officiel : il faut générer les types depuis specification/v0_9 et v1_0, écrire le prompt de catalogue et la validation JSON Schema soi-même. Python dispose de a2ui-agent-sdk et a2ui-adk, Go non. Le plugin Genkit Go est en preview, ne valide que la structure et les noms de composants, et documente seulement v0.9.
- L'écosystème agents est plus riche en Python et TS : les exemples, les intégrations d'évaluation et les nouveautés (ADK, Agents SDK, A2UI) arrivent souvent d'abord en Python. ADK Go a une doc moins fournie, et ses « collaboration modes » ne figurent pas explicitement dans ses notes de release.
- Saut de version Go : le kit est en 1.23/1.24, alors que openai-go/v3 et a2a-go/v2 exigent 1.26.0, adk/v2 1.26.10 et googleadk 1.26.6. Il faut monter OTel (1.35 → 1.45 ou plus) et Temporal (1.34 → 1.50) en même temps.
- openai-go/v3 sort plusieurs releases par semaine et le package live est récent (contrôles de délégation ajoutés le 2026-10-23) : risque de ruptures d'API mineures et besoin d'épingler les versions.
- Les jetons éphémères de go-genai sont marqués expérimentaux par le SDK lui-même.
- ADK Go v2 tire en dépendance deux versions d'a2a-go (v0.3.15 et v2.6.0) : graphe de dépendances lourd (cloud.google.com, aiplatform, storage) même si on n'utilise pas Vertex.
- Les tests BDD en Go sur des flux WebSocket asynchrones (sideband, canal app) sont plus verbeux que l'unaire gRPC actuel : il faut construire un faux serveur Live.

**Risques**
- Sécurité héritée : le kit décode les JWT sans vérifier la signature (server.go ParseUnverified) et Kong n'a pas de plugin d'auth. Copié tel quel, n'importe qui pourrait ouvrir des sessions GPT-Live facturées au projet.
- Affinité de session : le WebSocket sideband vit sur un pod. En scaling horizontal ou en redéploiement, il faut un ownership (lease Postgres ou Temporal) et un Reconnect, sinon des délégations sont perdues ou traitées deux fois (règle « un seul propriétaire par appel »).
- Latence : chaque saut LLM (routeur, puis agent GenUI, puis validation et éventuelle régénération) s'ajoute au délai vocal. Mesurer le temps jusqu'au premier commentary.append, utiliser acknowledgement_delay_ms et router de façon déterministe d'abord.
- Dérive A2UI : genui 0.10 côté Flutter et la spec v0.9 / v0.9.1 / v1.0 évoluent. Sans SDK Go officiel, il faut maintenir nous-mêmes la synchronisation du schéma (tests de conformité contre a2ui/conformance).
- Kong et le canal app : la passerelle actuelle fait du grpc-gateway unaire. Le WebSocket / SSE longue durée demande des routes dédiées (timeouts, upgrade) à valider sur la version Kong utilisée (non vérifié ici).
- Churn des SDK (openai-go quasi quotidien, ADK v1 et v2 en parallèle, a2a-go v2.x mensuel) : épingler les versions, mettre en place Renovate et des tests contractuels sur fixtures d'événements Live.
- Données personnelles : le sideband reçoit une copie de l'audio et des transcripts. Ne pas les journaliser ni les tracer par défaut (contenus gen_ai en opt-in).

**Plan phase 1**
- 1. Créer backend/agent_orchestrator (module Go 1.26.x) en copiant le squelette hexagonal de customer_service, monter OTel en v1.45 ou plus et Temporal en v1.50. Corriger tout de suite l'auth : vérification JWKS Keycloak (iss, aud, exp) dans un middleware HTTP/gRPC commun.
- 2. Écrire d'abord les BDD Godog : « relais SDP authentifié → 201 + session persistée », « délégation client → commentary.append + message A2UI valide sur le canal app », « JSON A2UI hors catalogue → rejeté puis régénéré », « barge-in → annulation, sans faux résultat ». Prévoir un faux serveur Live (httptest + WebSocket rejouant des fixtures d'événements).
- 3. Adapter out.LiveProvider/openai : POST relais SDP via client.Live.New (delegation.type=client, acknowledgement_delay_ms), avec quotas Kong rate-limiting et contrôle d'origine. Table live_sessions (session_id, user_id, tenant, owner_pod, statut).
- 4. Sideband supervisor : client.Live.Sideband.Connect par session, boucle Recv, tampon de transcripts, dispatch de session.delegation.created vers in.Orchestrator, gestion de Reconnect et de close/closed, lease d'ownership en Postgres.
- 5. Orchestrateur minimal : routeur déterministe (intentions connues) avec repli LLM. Une délégation donne un résumé parlable (commentary.append) et des messages A2UI (canal app). Spans invoke_agent et execute_tool avec gen_ai.conversation.id = session.id.
- 6. Agent GenUI : types A2UI v0.9 générés depuis a2ui/specification/v0_9 (ce que consomme genui 0.10), catalogue métier JSON Schema versionné partagé avec l'app Flutter, validation google/jsonschema-go avant envoi, au plus N régénérations, allowlist d'URLs. Garder Genkit a2ui/exp comme alternative à évaluer, sans en dépendre.
- 7. Canal app WebSocket (coder/websocket) : auth par JWT, corrélation session_id/delegation_id, retour des actions utilisateur typées vers l'orchestrateur, propagation de traceparent. Route Kong dédiée.
- 8. Outils MCP : client go-sdk v1.8 en Streamable HTTP sans état vers un premier serveur métier (exposer customer_service en MCP via le même SDK), OAuth client_credentials, allowlist d'hôtes, audit.
- 9. Gemini Live : endpoint d'émission de jeton (client.AuthTokens.Create, uses=1, LiveConnectConstraints verrouillant le modèle et l'instruction système) derrière le même port VoiceSessionService. Ou Firebase AI Logic + App Check selon le choix client.
- 10. Tâches longues : seuil de durée, au-delà duquel la délégation lance un Workflow Temporal (agent ADK via go.temporal.io/googleadk ou activités maison). Annulation par signal, résultat poussé sur le canal app. Puis activer les tests dans la CI Azure (go test -race, Godog + testcontainers).

**Intégration saaster kit** : On reprend le squelette de /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service et on crée un module frère backend/agent_orchestrator. Ce qui se réutilise :
1. Le découpage hexagonal internal/{domain/entities, ports/in, ports/out, adapters, application/services, workflows}. Ports proposés : in.VoiceSessionService, in.Orchestrator, out.LiveProvider (openai, gemini), out.ToolGateway (MCP), out.UIChannel, out.LLM.
2. Le câblage DI manuel dans cmd/main.go (driven adapters → services → driver adapters).
3. La façade OTel internal/adapters/observability/otel_facade.go et le port ports/out/observability.go (StartSpan/RecordDuration). On y ajoute les attributs gen_ai.*. Il faut monter go.opentelemetry.io/otel de v1.35 vers au moins v1.45 pour être compatible avec ADK et googleadk.
4. L'adapter internal/adapters/temporal/client.go et le pattern internal/workflows/customer_workflows.go + customer_activities.go pour les délégations longues.
5. La batterie BDD tests/ (Godog v0.13 + testcontainers v0.37, tests/testcontainers.go, features/*.feature) pour écrire des scénarios « délégation → A2UI validé » avec un faux serveur Live (httptest + WebSocket) et un serveur MCP in-process (go-sdk).
6. Les migrations golang-migrate dans migrations/ pour live_sessions, delegations et quotas.
7. Kong (infra/kong/kong.yml : cors, rate-limiting déjà présents) devant les routes HTTP/WebSocket. La SigNoz et le Temporal de docker-compose.yml restent inchangés.
À corriger avant réutilisation :
1. go.mod est en go 1.23.0 / toolchain 1.24.3, alors que openai-go/v3, a2a-go/v2 et adk/v2 exigent Go 1.26 ou plus. Monter le toolchain, et faire un module séparé si customer_service ne peut pas suivre.
2. internal/adapters/grpc/server.go:137 appelle jwt.Parser.ParseUnverified, et kong.yml n'a aucun plugin jwt/oidc. Les JWT Keycloak ne sont donc jamais vérifiés. C'est inacceptable pour une route qui dépense des minutes voix : il faut une vérification JWKS (iss, aud, exp).
3. Les intercepteurs ne sont qu'unaires : il faut ajouter des StreamInterceptor si le canal app passe en gRPC streaming.
4. Le Makefile proto contient des chemins /Users/bfontaine en dur.
5. La CI Azure ne lance aucun test.

### TypeScript / Node.js 24 LTS. Un service « voice-orchestrator » (Fastify 5 + ws) à côté du backend Go existant. SDK : openai 7.45.0 (live.sessions + SidebandWS), @google/genai 2.31.0 (authTokens), @openai/agents 0.21.0 pour le routeur et l'agent GenUI, @modelcontextprotocol/client 2.4.0 (spec MCP 2026-07-28), @a2ui/web_core 0.14.0 (validation Zod A2UI v0.9/v1.0), @ag-ui/core/@ag-ui/encoder 1.0.3 (canal vers l'app, option), @a2a-js/sdk 1.3.0 (A2A v1.0, phase 2), @temporalio/* 1.24.0, @opentelemetry/sdk-node, zod 4, jose (JWT Keycloak). Tests : @cucumber/cucumber 13.3.0 + testcontainers 12.2.1. Go reste le système de référence métier.

Je propose un orchestrateur TypeScript séparé, branché sur l'infrastructure du saaster kit (Kong, Keycloak, Temporal, SigNoz, Postgres) sans modifier les services Go. L'argument principal de TS : au 2026-10-27, c'est l'écosystème où les briques « agents » les plus récentes sont officielles et stables. On y trouve le client MCP v2 qui implémente la spec 2026-07-28, la validation A2UI officielle (@a2ui/web_core, Zod v0.9/v1.0), le SDK A2A 1.0 avec compatibilité 0.3, et AG-UI en 1.0 avec un middleware A2UI. En revanche, @openai/agents-realtime ne gère PAS GPT-Live (seulement /v1/realtime, modèle par défaut gpt-realtime-2.1). Pour la voix, il faut donc utiliser le SDK bas niveau openai 7.45 (live.sessions + SidebandWS). Go dispose de l'équivalent avec openai-go v3.88. Honnêtement, l'avantage de TS est réel mais étroit : il porte surtout sur MCP 2026-07-28 et la validation A2UI côté serveur. Il faut le comparer au coût d'un troisième langage pour une équipe Flutter + Go.

**Composants**
- Voice Session Gateway — POST /voice/sessions {provider, agentProfile} protégé par JWT Keycloak et quotas. GPT-Live : relais SDP via openai.live.sessions.create (model gpt-live-1, delegation.type 'client', instructions côté serveur) et réponse avec l'answer SDP. Gemini : client.authTokens.create (uses 1, expireTime court, liveConnectConstraints qui verrouille le modèle et la config). Conserve session.id ↔ userId. (Fastify 5, openai 7.45.0, @google/genai 2.31.0, jose, zod)
- Sideband Supervisor — Pour chaque session GPT-Live, ouvre SidebandWS (wss://api.openai.com/v1/live/sessions/{id}/attach) avec reconnexion. Tamponne session.input_transcript.delta/output_transcript.delta pour reconstruire la demande, reçoit session.delegation.created (target client) et renvoie les résultats via session.thinking.append / session.commentary.append (≤500 tokens, event_id unique). Ferme via session.close puis attend session.closed. Un seul propriétaire par délégation. (openai 7.45.0 (resources/live/sideband, SidebandWS sur ws 8.22))
- Gemini delegate endpoint — Point d'entrée de l'outil vocal unique delegate(task) quand Gemini Live tourne côté client : l'app relaie le function call au backend, qui renvoie un résumé parlable court, et l'A2UI part sur le canal app. (Fastify route + même use case Orchestrate que le sideband)
- Orchestrator / Router — Use case central. Routage d'abord déterministe (intentions connues), avec un LLM routeur seulement en repli. Il appelle comme outils (agent-as-tool) l'agent GenUI, les outils MCP et plus tard des agents A2A. Il produit deux sorties distinctes : un résumé parlable réel (pas de faux 'ok') et des messages A2UI. Il gère aussi l'annulation : une interruption vocale n'annule pas le travail. (@openai/agents 0.21.0 (Agent, tools, handoffs) ou appels directs openai.responses ; architecture hexagonale TS (domain/ports/adapters))
- GenUI Agent + A2UI Validator — LLM qui génère des messages A2UI v0.9/v1.0 à partir du catalogue métier, un JSON partagé et versionné avec l'app Flutter. Chaque message est validé côté serveur contre ce catalogue avant envoi ; en cas de rejet, nouvelle génération bornée. Filtre aussi les URLs (openUrl/Image en https et sur des domaines autorisés). (@a2ui/web_core 0.14.0 (MessageProcessor, schémas Zod générés depuis specification/), zod 4, structured outputs)
- MCP Client Hub — Clients MCP Streamable HTTP + OAuth vers les serveurs d'outils métier, avec la négociation de version 2026-07-28 (server/discover, _meta, input_required/MRTR) et un repli sur les serveurs de l'ère 2025. Liste blanche d'outils, journal d'audit, secrets jamais hors du backend. (@modelcontextprotocol/client 2.4.0 (v2 stable))
- App Channel (A2UI push) — Canal ordonné et fiable de l'orchestrateur vers l'app Flutter : en phase 1, WebSocket authentifié (JSONL d'enveloppes A2UI + actions utilisateur en retour). Options ultérieures : AG-UI (SSE) si on ajoute état partagé et texte en streaming, ou un serveur A2A consommable par genui_a2a. (ws 8.22 / Fastify ; option @ag-ui/encoder 1.0.3 + @ag-ui/a2ui-middleware 0.0.13 ; option @a2a-js/sdk 1.3.0 (serveur))
- A2A Client (phase 2) — Délégation à des agents distants spécialisés (Agent Card, SendMessage, streaming SSE/push), avec une couche de compatibilité v0.3 pour les pairs non migrés. (@a2a-js/sdk 1.3.0 (JSON-RPC, HTTP+JSON, gRPC ; stores Postgres via Kysely))
- Long tasks — Tâches longues (rapports, traitements multi-étapes) sous forme de workflows Temporal, avec annonce vocale à la fin via commentary.append si la session vit encore, sinon notification push. (@temporalio/client + worker 1.24.0 sur le cluster Temporal existant (task queue dédiée))
- Observability — Une trace par session vocale (gen_ai.conversation.id = id de session). Spans invoke_agent orchestrator / genui, execute_tool pour MCP et A2A, attributs delegation.id. Propagation du traceparent depuis Flutter. Export OTLP vers le collector SigNoz existant. Contenus des messages en opt-in. (@opentelemetry/sdk-node + spans gen_ai.* manuels (pas d'export OTel GenAI natif dans @openai/agents-core 0.21.0))
- Auth & Quotas — Vérification des JWT Keycloak (JWKS), contrôle d'origine, limitation de débit par utilisateur sur la création de sessions et sur les délégations, budgets de tokens et de minutes voix stockés dans Postgres. (jose, Postgres (pg/Kysely), plugin rate-limiting Kong en amont)

**Affirmations SDK**
- Le SDK Node officiel openai est en 7.45.0 (publié le 2026-10-26). Il expose client.live.sessions (create, accept, hangup, refer, reject, fork) et une classe SidebandWS (resources/live/sideband/ws) pour l'attachement /live/sessions/{id}/attach, avec reconnexion configurable. Ses types incluent session.delegation.created, session.thinking.append et session.commentary.append (vérifié dans le tarball npm). — https://registry.npmjs.org/openai
- @openai/agents et @openai/agents-realtime sont en 0.21.0 (2026-10-20). @openai/agents-realtime ne cible que l'API Realtime (/v1/realtime/calls, /v1/realtime?call_id=, DEFAULT_OPENAI_REALTIME_MODEL = 'gpt-realtime-2.1') : aucun support de /v1/live/sessions ni de gpt-live-1 dans le code publié. — https://registry.npmjs.org/@openai/agents-realtime
- @openai/agents-core 0.21.0 : aucune dépendance OpenTelemetry ni attribut gen_ai.* trouvé dans dist. Le tracing OTel GenAI devra être instrumenté à la main ou via un processeur tiers. — https://registry.npmjs.org/@openai/agents-core
- @google/genai est en 2.31.0 (2026-10-23). La doc des jetons éphémères montre client.authTokens.create({config:{uses, expireTime, newSessionExpireTime, liveConnectConstraints:{model:'gemini-3.8-live', ...}}}) ; ces jetons ne fonctionnent qu'avec la Live API en v1beta. — https://ai.google.dev/gemini-api/docs/ephemeral-tokens
- Le SDK MCP TypeScript v2 est découpé en @modelcontextprotocol/client, /server et /core 2.4.0 (2026-10-23). Le README le présente comme « the stable release line, implementing the 2026-07-28 MCP spec », avec server/discover, resultType input_required et une négociation de version avec repli vers l'ère 2025. Le package historique @modelcontextprotocol/sdk 1.32.2 reste en LATEST_PROTOCOL_VERSION 2025-11-25. — https://registry.npmjs.org/@modelcontextprotocol/client
- @a2a-js/sdk 1.3.0 (2026-09-29) est le SDK officiel A2A JS, en « v1.0 stable release implementing A2A Protocol Specification v1.0 ». Il propose trois transports (JSON-RPC, HTTP+JSON/REST, gRPC Node), une couche de compatibilité v0.3 opt-in et des stores Postgres/MySQL/SQLite. — https://registry.npmjs.org/@a2a-js/sdk
- @a2ui/web_core 0.14.0 (2026-10-17) est le moteur A2UI agnostique du framework (base des renderers Lit/React/Angular). Il fournit un MessageProcessor qui valide les messages, un système de catalogues avec validation à l'exécution et des schémas Zod générés pour v0_9 et v1_0. Il peut donc servir à valider l'A2UI côté Node. — https://registry.npmjs.org/@a2ui/web_core
- AG-UI est natif TS : @ag-ui/core, @ag-ui/client et @ag-ui/encoder sont en 1.0.3 (2026-10-16). @ag-ui/a2ui-middleware 0.0.13 diffuse des surfaces A2UI dans un flux AG-UI (peer @ag-ui/client >=1.0.0, rxjs). Le SDK Go AG-UI n'existe que dans sdks/community/go, sans tag (pseudo-version 2026-10-26). — https://registry.npmjs.org/@ag-ui/core
- @copilotkit/runtime 1.80.0 et @copilotkit/a2ui-renderer 1.80.0 (2026-10-24) existent, mais ce sont des runtimes et renderers web/React : ils ne servent à rien pour un client Flutter, sauf comme serveur AG-UI. — https://registry.npmjs.org/@copilotkit/runtime
- Côté Go, les équivalents existent : openai-go v3.88.0 (2026-10-26) contient live/live_sideband_websocket_binding.go et les routes live/sessions/%s/attach ; a2a-go/v2 v2.7.0 (2026-10-21) ; MCP go-sdk v1.8.0 (2026-09-04) avec un support partiel ou transitoire de 2026-07-28 (server/discover présent) ; google.golang.org/genai v1.76.0 ; adk-go v1.9.0. — https://proxy.golang.org/github.com/openai/openai-go/v3/@latest
- Outillage TS pour reproduire le BDD et l'infrastructure du kit : @cucumber/cucumber 13.3.0, testcontainers 12.2.1 et @testcontainers/postgresql 12.2.1, @temporalio/client 1.24.0, @connectrpc/connect-node 2.2.0, @grpc/grpc-js 1.14.6. — https://registry.npmjs.org/@cucumber/cucumber

**Forces**
- MCP : le SDK TS v2 (@modelcontextprotocol/client 2.4.0) est l'implémentation de référence. Il est déclaré stable et conforme à la spec 2026-07-28 (stateless, server/discover, MRTR input_required) avec repli vers l'ère 2025. Le go-sdk 1.8.0 est encore en transition.
- A2UI : validation serveur officielle disponible (@a2ui/web_core 0.14, Zod v0.9 et v1.0, MessageProcessor). Pas d'équivalent officiel trouvé en Go. C'est exactement le contrôle « valider deux fois » exigé par genui-a2ui-security.
- AG-UI est natif TS (1.0.3) avec un middleware A2UI. En Go, le SDK est communautaire et non versionné. Si le canal app ↔ backend évolue vers AG-UI, TS est le choix naturel.
- A2A : SDK JS officiel en v1.0 avec compatibilité v0.3 et stores persistants (Postgres). C'est utile en phase 2, et pour exposer l'orchestrateur en serveur A2A consommé par genui_a2a.
- Voix : le SDK openai Node 7.45 type complètement GPT-Live (sessions, SidebandWS avec reconnexion, événements de délégation). Le relais SDP et le sideband tiennent en peu de code.
- JSON natif + Zod : structured outputs LLM, schémas A2UI et validation des payloads MCP dans un seul système de types. La boucle génération → validation → nouvelle génération est simple à écrire.
- Modèle I/O événementiel de Node adapté à des milliers de WebSockets longue durée (sideband + canal app) qui font surtout de l'attente réseau.
- Le plus gros volume d'exemples, de docs et d'outillage pour les agents (OpenAI, Google, CopilotKit, MCP) est publié d'abord en TS/Python : moins de traduction pour suivre un écosystème qui change chaque mois.

**Faiblesses**
- Troisième langage pour une équipe Flutter + Go : nouvelle chaîne (npm, tsconfig, ESLint, cucumber-js, Dockerfile Node), revues de code moins expertes, deux styles hexagonaux à maintenir.
- @openai/agents-realtime, le framework vocal phare de TS, ne gère pas GPT-Live (seulement /v1/realtime, gpt-realtime-2.1). La partie voix utilise le SDK bas niveau, qui existe aussi en Go (openai-go v3.88 live + sideband) : TS n'a aucun avantage côté voix.
- L'écart avec Go est étroit : openai-go v3.88 (live/sideband), a2a-go/v2 v2.7.0, go-sdk MCP 1.8.0 (2026-07-28 partiel), genai Go v1.76 et adk-go v1.9 couvrent l'essentiel. L'avantage de TS se limite à MCP 2026-07-28 complet, à la validation A2UI et à AG-UI.
- @openai/agents reste en 0.x (0.21.0) : API instable, ruptures à chaque version mineure possibles. Pas d'export OTel GenAI natif, donc les spans gen_ai.* sont à écrire à la main.
- Les renderers A2UI/CopilotKit (React, Lit, Angular) sont inutiles pour un client Flutter. Une partie de l'argument « écosystème A2UI TS » ne s'applique pas.
- La chaîne d'approvisionnement npm (dépendances transitives nombreuses) est une surface d'attaque plus large que les modules Go. Il faut un lockfile strict, l'audit et éventuellement une whitelist de registre.
- Un seul thread CPU par process : la validation Zod de gros catalogues ou un traitement audio (copie PCM du sideband) peut bloquer l'event loop. Il faut ignorer l'audio du sideband, ou passer par des worker_threads.
- Le code des types partagés avec Go (proto) passe par une génération supplémentaire (connect-es/ts-proto) et un nouveau pipeline CI.

**Risques**
- État en mémoire par session (sideband WebSocket, tampon de transcripts, délégations en cours) : une instance doit être propriétaire de la session. Il faut de l'affinité ou un registre des propriétaires (Postgres advisory lock ou Redis), sinon après un redéploiement deux sidebands répondent à la même délégation (doublons rejetés ou action exécutée deux fois).
- GPT-Live : aucun client secret documenté. Le relais SDP est donc obligatoire et devient un point critique de disponibilité et de sécurité (auth, origine, quotas) ; une panne du backend coupe toute la voix.
- Évolutions rapides et ruptures : MCP v2 TS (nouvelle découpe de packages), A2A 1.0 contre 0.3 sur le fil, A2UI v0.9 contre v1.0 (genui 0.10.4 dépend de a2ui_core ^0.1), @openai/agents 0.x. Il faut figer les versions et prévoir des tests de contrat.
- Désalignement du catalogue A2UI : le JSON du catalogue doit être une source unique partagée entre Flutter (genui) et Node (@a2ui/web_core), versionnée par URI. Sinon, le serveur valide contre un schéma que le client rejette.
- Compétences : si l'équipe Go ne monte pas en TS, l'orchestrateur, qui est le composant le plus critique, devient un îlot maintenu par une ou deux personnes.
- Sécurité des prompts : les résultats MCP et A2A injectés via thinking.append ou commentary.append entrent dans le contexte vocal. Il faut filtrer, ne jamais y mettre de secret et confirmer les actions sensibles hors GenUI.
- Coûts et latence : chaque saut LLM (routeur + GenUI) s'ajoute à la latence vocale. Router de façon déterministe et utiliser acknowledgement_delay_ms / thinking.append pour masquer l'attente.
- Dates d'expiration : App Check obligatoire pour Firebase AI Logic dès le 2026-11-02, et les jetons Gemini ne fonctionnent qu'en v1beta (API susceptible de changer).

**Plan phase 1**
- Prendre la décision de langage avec l'équipe Go : valider explicitement le coût d'un troisième langage, à comparer à une option tout-Go (openai-go v3.88 + go-sdk MCP + a2a-go/v2). Si TS est retenu, désigner au moins deux propriétaires TS.
- Créer backend/voice_orchestrator (Node 24 LTS, TS strict, ESM, pnpm avec lockfile) avec une arborescence hexagonale calquée sur customer_service. Ajouter Dockerfile, le service docker-compose et l'étape CI dans azure-pipelines.yml.
- Écrire d'abord les features Gherkin (cucumber-js + testcontainers Postgres/Temporal) et de faux serveurs OpenAI Live (HTTP SDP + WS sideband) et Gemini auth_tokens à la frontière, en TDD outside-in.
- Implémenter POST /voice/sessions : JWT Keycloak (jose/JWKS), vérification d'origine, quotas par utilisateur. GPT-Live : openai.live.sessions.create (gpt-live-1, delegation.type 'client', acknowledgement_delay_ms) puis réponse avec l'answer SDP. Gemini : authTokens.create (uses 1, expireTime court, liveConnectConstraints). Exposer la route via Kong.
- Implémenter le Sideband Supervisor : SidebandWS par session, tampon des transcripts, gestion de session.delegation.created, thinking.append / commentary.append (≤500 tokens, event_id unique), fermeture propre (session.close puis session.closed) et verrou de propriété de session.
- Implémenter le use case Orchestrate (outil unique delegate, avec la même entrée pour le sideband GPT-Live et pour l'endpoint /delegate de Gemini) : routeur déterministe, plus un LLM de repli via @openai/agents. Le résumé parlable doit refléter le vrai résultat. Gérer l'annulation explicite.
- Définir le catalogue A2UI métier (JSON versionné par URI, partagé avec l'app Flutter) puis implémenter l'agent GenUI : génération, validation @a2ui/web_core, nouvelle génération bornée, filtrage des URLs. Couvrir le tout par des tests de contrat contre le catalogue Flutter.
- Ouvrir le canal app WebSocket authentifié (JSONL A2UI ordonné, actions utilisateur typées en retour vers l'orchestrateur) et le brancher sur le transport genui côté Flutter.
- Brancher un premier serveur MCP via @modelcontextprotocol/client 2.4.0 (Streamable HTTP + OAuth), idéalement un serveur MCP Go devant customer_service. Ajouter la liste blanche d'outils et le journal d'audit.
- Mettre en place l'observabilité : sdk-node OTLP vers le collector SigNoz, une trace par session (gen_ai.conversation.id), spans invoke_agent / execute_tool, traceparent propagé depuis Flutter, contenus en opt-in.
- Déléguer les tâches longues en asynchrone : démarrer des workflows Temporal (client TS ; workflows en Go ou en TS) et annoncer le résultat via commentary.append si la session est encore ouverte.

**Intégration saaster kit** : On ne touche pas aux services Go : l'orchestrateur TS devient un nouveau service du monorepo (backend/voice_orchestrator/) qui réutilise l'infrastructure.
(1) docker-compose.yml : ajouter un service à côté de customer_service, sur le même réseau, branché sur le Postgres existant (schéma dédié) et sur le cluster temporal (task queue 'voice-orchestrator').
(2) Kong (infra/kong/kong.yml, mode déclaratif « off ») : ajouter un service HTTP avec des routes pour /voice/sessions et /delegate, plus une route ws/wss pour le canal A2UI, en réutilisant les plugins globaux cors, request-size-limiting et rate-limiting. Le relais SDP doit refuser les origines inattendues.
(3) Keycloak/OIDC : vérifier les JWT avec jose sur le JWKS Keycloak, comme golang-jwt/jwt/v5 dans customer_service.
(4) SigNoz/OTel : exporter en OTLP vers saaster-kit-otel-collector:4317 (route oltp-collector-grpc déjà présente), en reprenant les conventions de internal/adapters/observability/otel_facade.go (service.name, logs + traces + métriques).
(5) Domaine Go : l'orchestrateur appelle customer_service en gRPC avec des stubs générés depuis backend/customer_service/proto/customer.proto (connect-es ou ts-proto). Le plus propre est de faire exposer par Go un serveur MCP (go-sdk) pour les outils métier, afin que l'orchestrateur ne connaisse que MCP.
(6) Architecture hexagonale : on transpose en TS l'arborescence internal/domain, ports/in, ports/out, adapters, application/services décrite dans backend/CLAUDE.md.
(7) BDD : mêmes fichiers .feature en Gherkin (modèle tests/features/*.feature) exécutés par @cucumber/cucumber, avec testcontainers-node calqué sur tests/testcontainers.go (Postgres + Temporal). Les fournisseurs OpenAI/Gemini sont simulés par de faux serveurs WS/HTTP à la frontière.
(8) CI azure-pipelines.yml : ajouter une étape « Build & push Voice Orchestrator » (Docker@2) dans les stages Pré-Production et Production, sur le modèle de « Build & push Backend ».
Workflows Temporal de longue durée : ils peuvent rester en Go (workflows/customer_workflows.go comme modèle), avec un client TS qui les démarre.

### Python 3.12 : orchestrateur FastAPI/Starlette (uvicorn), SDK officiel `openai` 3.39 (client.live + sideband) pour GPT-Live, `google-genai` 2.33 pour les jetons éphémères Gemini, Google ADK Python 2.13 + `a2ui-agent-sdk` 0.9 / `a2ui-adk` 0.1 pour l'agent GenUI, SDK `mcp` 2.3 pour les outils MCP (spec 2026-07-28), `a2a-sdk` 1.2 (A2A v1.0) en phase 2, `ag-ui-protocol` 1.0 en option, `temporalio` 1.34 pour les tâches longues, OpenTelemetry exporté vers le SigNoz existant. Le service est déployé comme un nouveau microservice du saaster kit, derrière Kong et Keycloak. Les services Go métier restent en Go et sont exposés à l'orchestrateur comme serveurs MCP ou appelés en gRPC.

Python est l'écosystème où les briques agent sont les plus complètes au 2026-10-27. On y trouve le seul SDK agent A2UI officiel (validation contre le catalogue, prompts, intégration ADK), ADK dans sa version la plus mûre (2.13 contre 1.9 en Go), les adaptateurs AG-UI et les intégrations Temporal dédiées aux agents. En revanche, la plomberie vocale (relais SDP GPT-Live, sideband, jetons Gemini) et MCP/A2A sont aussi bien couverts en Go : l'avantage de Python se joue sur la couche « agents/GenUI », pas sur la couche voix. Point à corriger dans le brief : `openai-agents` (0.24.0) ne gère PAS GPT-Live, seulement l'ancienne API Realtime. Pydantic AI gère GPT-Live, mais uniquement en délégation `responses`. Pour la délégation `client`, il faut donc utiliser directement `openai.live` / `live.sideband`. Le coût réel est d'introduire un second langage de production pour une équipe Go/Flutter (outillage, CI, revue, astreinte). On peut le limiter en cantonnant Python à un seul service « orchestrateur » qui suit les conventions hexagonales et BDD du kit.

**Composants**
- voice-session-api (adapter HTTP entrant) — POST /voice/sessions {provider, agentProfile} : authentifie l'utilisateur (JWT Keycloak vérifié via JWKS), applique les quotas, puis relaie l'offre SDP vers POST /v1/live/sessions (gpt-live-1, delegation.type=client) et renvoie l'answer SDP. Pour Gemini, émet un jeton v1beta/auth_tokens (uses=1, liveConnectConstraints). Instructions et outils restent côté serveur. (FastAPI, openai 3.39 (client.live.create), google-genai 2.33 (client.auth_tokens.create), PyJWT/authlib pour la vérification JWKS)
- sideband-supervisor — Pour chaque session GPT-Live, ouvre wss://…/v1/live/sessions/{id}/attach, reconstruit le contexte depuis input/output_transcript.delta, reçoit session.delegation.created, appelle l'orchestrateur et renvoie session.thinking.append / commentary.append (≤500 tokens, event_id unique). Gère session.close, le hangup et la reconnexion, avec un seul propriétaire par délégation. (openai.AsyncOpenAI().live.sideband.connect (reconnexion intégrée), asyncio TaskGroup, un worker par session (sticky))
- orchestrator / router — Point d'entrée de l'outil vocal unique `delegate` (délégation GPT-Live client ou function call Gemini). Route d'abord de façon déterministe (sortie structurée), puis par LLM si besoin. Appelle l'agent GenUI, les outils MCP et, plus tard, les agents A2A comme des outils (agent-as-tool). Produit deux sorties : un résumé parlable réel et des messages A2UI. (Google ADK Python 2.13 (LlmAgent + AgentTool, modes single_turn/task) ou orchestration par le code en Python pur ; Pydantic pour les contrats)
- genui-agent — LLM qui génère des messages A2UI v0.9/v1.0, validés contre le catalogue négocié avec le client Flutter (capacités envoyées par genui), réparés ou rejetés avant envoi. Le JSON A2UI n'est jamais renvoyé au modèle vocal. (a2ui-agent-sdk 0.9 (A2uiGenerator, CatalogConfig, validate_payload, ComponentPruningTransformer), a2ui-core 0.4 (V0_8/V0_9/V1_0), a2ui-adk 0.1 (SendA2uiToClientToolset))
- mcp-gateway (clients MCP) — Clients MCP Streamable HTTP vers les outils métier, avec OAuth par serveur, liste blanche d'URL anti-SSRF, journal d'audit, MRTR/elicitation et repli `initialize` pour les serveurs antérieurs à 2026-07-28. Les services Go Septeo sont exposés comme serveurs MCP (go-sdk) ou appelés en gRPC. (mcp 2.3 (Python), ADK McpToolset ; côté Go, modelcontextprotocol/go-sdk 1.8 pour exposer les services existants)
- app-channel (push A2UI vers Flutter) — Canal authentifié app ↔ orchestrateur : envoie les messages A2UI (createSurface/updateComponents/dataModel) vers la Surface genui et remonte les actions utilisateur. Phase 1 : WebSocket simple. Option : A2A (genui_a2a) ou AG-UI quand il faudra de l'état partagé. (Starlette WebSocket (ou SSE) ; option a2a-sdk 1.2 + a2ui-a2a ; option ag-ui-protocol 1.0 / ag-ui-adk 0.11)
- long-running tasks — Tâches longues ou durables (délégations > quelques secondes, confirmations, push FCM) : le vocal reçoit un accusé immédiat, le résultat arrive plus tard via commentary.append ou une surface A2UI. (temporalio 1.34 (worker Python sur une task queue dédiée, contrib google_adk_agents / openai_agents / opentelemetry) sur le cluster Temporal déjà présent dans docker-compose)
- observability — Une trace par session vocale (gen_ai.conversation.id = session.id). Spans invoke_agent orchestrator, execute_tool pour MCP/A2A et invoke_agent genui. Propagation du traceparent depuis Flutter. Contenus de messages en opt-in. (opentelemetry-sdk 1.39–1.44 (contrainte ADK), télémétrie native ADK, opentelemetry-instrumentation-google-genai 1.3b0 / openai-v2 2.4b0, export OTLP vers le collector SigNoz du kit)

**Affirmations SDK**
- Le SDK officiel `openai` Python 3.39.0 (2026-10-26) expose GPT-Live : `client.live.create` (POST /live/sessions), `client.live.sideband.connect(session_id=…)` (WebSocket /live/sessions/{id}/attach, avec reconnexion et file d'envoi), ainsi que `live.sessions.hangup/fork/accept/reject` et les types ClientDelegation, DelegationCreatedEvent, CommentaryAppendEvent et ThinkingAppendEvent. Vérifié en inspectant la wheel (resources/live/api.md, sideband.py). — https://pypi.org/pypi/openai/json
- Les types du SDK `openai` 3.39.0 contiennent un troisième mode de délégation `decisions` (DecisionsDelegationConfig), absent de la base de connaissances. À vérifier dans la doc avant usage. — https://pypi.org/pypi/openai/json
- `openai-agents` 0.24.0 (2026-10-15) ne gère pas GPT-Live : son module realtime se connecte à wss://api.openai.com/v1/realtime (?model= ou ?call_id=), c'est-à-dire l'ancienne API Realtime. gpt-live n'y apparaît que comme modèle de transcription (gpt-live-transcribe). — https://pypi.org/pypi/openai-agents/json
- Pydantic AI (pydantic-ai 2.62.0) gère gpt-live-1 (OpenAILiveModel, answer_webrtc_offer côté serveur, sideband via connect_webrtc), mais ne configure que la délégation `responses`, et create_client_secret lève toujours une erreur (pas de client secret pour GPT-Live). — https://pydantic.dev/docs/ai/api/realtime/openai_live/
- `google-adk` Python 2.13.0 (2026-10-23, Python ≥ 3.11) intègre des modules a2a, live, telemetry, workflow et mcp_tool. Extras : a2a-sdk[http-server] >=0.3.4,<2 et mcp >=1.24,<3. OpenTelemetry est épinglé en >=1.39,<=1.44. — https://pypi.org/pypi/google-adk/json
- `a2a-sdk` Python 1.2.3 (2026-10-19) définit PROTOCOL_VERSION_CURRENT = '1.0' et garde une couche de compatibilité 0.3 (en-tête de version absent = 0.3). — https://pypi.org/pypi/a2a-sdk/json
- Le SDK `mcp` Python 2.3.0 (2026-10-02) implémente la spec 2026-07-28 (subscriptions/listen SEP-2575, dépréciation du sampling SEP-2577) tout en gérant les versions antérieures. — https://pypi.org/pypi/mcp/json
- Le dépôt A2UI a migré de google/A2UI vers a2ui-project/a2ui. Il fournit des SDK python (a2ui_core, a2ui_agent, a2ui_adk, a2ui_a2a), dart, kotlin, swift et typescript, mais aucun SDK Go. Des exemples d'agents ADK sont dans samples/agent/adk (restaurant_finder, custom-components-example). — https://api.github.com/repositories/1063641074/contents/python
- `a2ui-agent-sdk` 0.9.0 (2026-10-17) fournit A2uiGenerator, A2uiRequestProcessor, CatalogConfig, des transformers d'élagage du catalogue et validate_payload (validation « comme le renderer »). Il dépend de a2ui-core >=0.4,<0.5, qui déclare les ProtocolVersion V0_8, V0_9 et V1_0. — https://pypi.org/pypi/a2ui-agent-sdk/json
- `a2ui-adk` 0.1.0 (2026-10-19) fournit SendA2uiToClientToolset (l'agent ADK envoie de l'A2UI au client via un appel d'outil) et un extra [a2a] avec convertisseurs ADK→A2A et orchestration de sous-agents A2UI. — https://pypi.org/pypi/a2ui-adk/json
- AG-UI Python : `ag-ui-protocol` 1.0.0 (2026-09-17, module ag_ui.core, événements lifecycle/text/tool call/state) et `ag-ui-adk` 0.11.0 (2026-10-21) comme adaptateur ADK. — https://docs.ag-ui.com/sdk/python/core/overview
- `temporalio` Python 1.34.0 inclut des intégrations temporalio.contrib.google_adk_agents, openai_agents, google_genai et opentelemetry (vérifié dans la wheel manylinux). — https://pypi.org/pypi/temporalio/json
- Instrumentation OTel GenAI Python : opentelemetry-instrumentation-google-genai 1.3b0 (2026-10-23) et opentelemetry-instrumentation-openai-v2 2.4b0 (2026-05-01), toutes deux en bêta. — https://pypi.org/pypi/opentelemetry-instrumentation-google-genai/json
- `google-genai` Python 2.33.0 expose client.auth_tokens.create (jetons éphémères Live). — https://pypi.org/pypi/google-genai/json
- Contre-argument honnête : Go a la parité sur la plomberie. openai-go v3.88.0 (2026-10-26) a un package live/ (live.go, fork.go, decisions) ; modelcontextprotocol/go-sdk v1.8.0 gère server/discover en 2026-07-28 ; a2a-go/v2 v2.7.0 (2026-10-21) ; google.golang.org/adk v1.9.0 ; google.golang.org/genai v1.76.0 contient un exemple live_with_ephemeral_token. — https://proxy.golang.org/github.com/openai/openai-go/v3/@latest

**Forces**
- Seul langage avec un SDK agent A2UI officiel (a2ui-agent-sdk + a2ui-core V0_9/V1_0 + a2ui-adk) : génération, élagage du catalogue et validation `validate_payload` existent déjà, alors qu'en Go il faudrait les réécrire à partir des JSON Schemas.
- Google ADK Python 2.13 est la version de référence (modes chat/task/single_turn, workflows en graphe, AgentTool, télémétrie GenAI native, McpToolset, extra A2A), nettement en avance sur ADK Go 1.9.
- Les exemples A2UI officiels côté agent (samples/agent/adk) sont en Python : chemin le plus court vers un agent GenUI qui marche avec genui/genui_a2a.
- Le SDK `openai` Python couvre complètement GPT-Live (create, sideband.connect avec reconnexion, hangup, fork) et le relais SDP et le sideband client se codent en quelques dizaines de lignes d'asyncio.
- Écosystème d'évaluation et de prompts (pytest, ADK eval, Pydantic pour les sorties structurées) et la plupart des exemples MCP/A2A/AG-UI de la communauté sont en Python : itération plus rapide sur les prompts et le routeur.
- Temporal Python a des intégrations dédiées aux agents (contrib.google_adk_agents, openai_agents) et réutilise le cluster Temporal du kit.
- AG-UI Python (ag-ui-protocol 1.0 + ag-ui-adk) est prêt si le canal app doit évoluer vers de l'état partagé.

**Faiblesses**
- Nouveau langage pour une équipe Go + Flutter : nouvelles conventions (uv/poetry, ruff, mypy/pyright), nouvelles images, nouvelle CI, revue de code moins experte et astreinte sur un runtime que l'équipe maîtrise mal.
- Le facteur décisif annoncé n'existe pas : `openai-agents` ne gère pas GPT-Live (seulement /v1/realtime), et Pydantic AI ne gère que la délégation `responses`. Pour la délégation `client` retenue, Python n'apporte que le SDK `openai` brut, que Go possède aussi (openai-go v3.88 package live).
- Parité Go sur la plomberie : MCP 2026-07-28 (go-sdk 1.8), A2A v1.0 (a2a-go/v2 2.7), jetons Gemini (genai Go 1.76). L'avantage Python se limite à A2UI agent-side, ADK mature et AG-UI.
- Concurrence : un sideband WebSocket longue durée par session vocale. asyncio est suffisant, mais un appel bloquant ou CPU-bound dans la boucle (validation JSON Schema volumineuse, SDK synchrone) dégrade toutes les sessions du worker. Les goroutines Go sont plus tolérantes.
- Mémoire et densité : un process Python avec ADK, genai et openai pèse plusieurs centaines de Mo, contre quelques dizaines pour un binaire Go. À prendre en compte pour la mise à l'échelle par session.
- Contraintes de dépendances serrées : ADK épingle opentelemetry 1.39–1.44 et a2a-sdk <2, et les instrumentations OTel GenAI sont en bêta. Conflits de versions probables entre ADK, a2ui-adk (0.1.0) et openai.
- Deux piles d'observabilité et d'auth à maintenir en parallèle (Go et Python) au lieu d'une seule.

**Risques**
- Maturité : a2ui-adk 0.1.0, a2ui-agent-sdk 0.9 et ag-ui-adk 0.11 sont pré-1.0 et le dépôt A2UI vient de changer d'organisation (google/A2UI vers a2ui-project/a2ui) : ruptures d'API probables. À épingler strictement.
- Compatibilité A2UI client/serveur : genui 0.10.4 dépend de a2ui_core ^0.1.0 (Dart) alors que le Python est en a2ui-core 0.4. Il faut verrouiller la version de protocole (v0.9) négociée et tester la conformité (dossier conformance du dépôt).
- Affinité de session : le sideband est attaché à un worker précis, donc il faut du sticky routing, un drain propre au redéploiement et une reprise (session.close / hangup) si le pod meurt. C'est indépendant du langage, mais critique.
- Un seul propriétaire par délégation : si l'app (outils locaux) et le sideband répondent tous deux, on obtient des doublons ou des actions exécutées deux fois.
- Mode `decisions` présent dans les types du SDK OpenAI mais pas dans la base : la doc ou le comportement GPT-Live évolue vite. Prévoir un adapter fin et des tests de contrat.
- Sécurité : endpoint relais SDP = dépense directe. Il faut un JWT vérifié (ne pas copier ParseUnverified de server.go), des quotas par utilisateur, une vérification d'origine et resserrer le CORS Kong. Protéger aussi MCP contre le SSRF et l'injection via résultats d'outils.
- Risque organisationnel : si le service Python repose sur une ou deux personnes, bus factor faible. Si l'équipe ne monte pas en compétence, la dette se reporte vers un portage Go ultérieur.
- Latence : chaque saut LLM (routeur, puis GenUI) s'ajoute au temps avant le premier commentary.append. Il faut router de façon déterministe et utiliser acknowledgement_delay_ms et thinking.append pour masquer l'attente.

**Plan phase 1**
- Créer backend/agent_orchestrator/ (Python 3.12, uv, ruff, mypy strict) avec l'arborescence hexagonale du kit : domain/, ports/in, ports/out, adapters/, application/. Ajouter le service au docker-compose et une route Kong /agent (HTTP + WebSocket) avec un CORS restreint.
- Auth : middleware FastAPI qui vérifie le JWT Keycloak via JWKS (signature, iss, aud, exp), et non ParseUnverified. Quotas par utilisateur (Postgres ou Redis) et vérification d'origine.
- Écrire en Gherkin (pytest-bdd + testcontainers-python) les scénarios « créer une session voix », « délégation reçue → résultat parlé + surface A2UI », « fournisseur indisponible », avant le code (TDD outside-in).
- Port VoiceSessionProvider avec deux adapters : GPT-Live (openai.live.create, delegation.type=client, acknowledgement_delay_ms) qui renvoie l'answer SDP, et Gemini (google-genai auth_tokens.create, uses=1, liveConnectConstraints) qui renvoie le jeton. Exposés via POST /voice/sessions.
- Sideband supervisor : une tâche asyncio par session avec live.sideband.connect(session_id). Elle reconstruit le contexte depuis les transcripts, traite session.delegation.created, répond via thinking.append/commentary.append (≤500 tokens) et gère close/hangup. Fake du sideband pour les tests.
- Orchestrateur minimal : outil unique `delegate`, routeur déterministe (sortie structurée Pydantic), puis appel de l'agent GenUI et d'un premier outil MCP. Vrais résultats uniquement, jamais de faux {status: ok}.
- Agent GenUI : a2ui-agent-sdk avec CatalogConfig chargé depuis le catalogue exporté par l'app Flutter (même source de vérité), élagage du catalogue, validate_payload avant tout envoi, A2UI v0.9 verrouillé. Tests golden des payloads.
- Canal app : WebSocket authentifié /agent/surfaces/{sessionId} qui pousse createSurface/updateComponents et reçoit les actions utilisateur. Côté Flutter, un Transport genui qui le consomme.
- MCP : un client mcp 2.3 (Streamable HTTP, OAuth, liste blanche d'hôtes). Exposer un service Go existant (customer_service) comme serveur MCP avec modelcontextprotocol/go-sdk, pour prouver la cohabitation Go/Python.
- Observabilité : OTLP vers SigNoz. Une trace par session (gen_ai.conversation.id), spans invoke_agent/execute_tool, propagation du traceparent depuis Flutter, contenus en opt-in. Métrique : latence délégation → premier commentary.
- Tâches longues : worker Temporal Python sur une task queue dédiée pour les délégations > N secondes (accusé immédiat, résultat différé). Scénario BDD « Temporal indisponible » sur le modèle de customer_temporal_workflows.feature.
- CI Azure : job lint/type/test et image Docker@2. Revue de fin de phase 1 : mesurer la latence, la charge mémoire par session et l'aisance de l'équipe. Si le coût Python est jugé trop élevé, garder Python seulement pour l'agent GenUI (A2UI SDK) et basculer relais SDP et sideband en Go (openai-go live).

**Intégration saaster kit** : Python ne réutilise pas le code Go, mais il réutilise toute l'infrastructure et les conventions du kit. (1) docker-compose.yml (/home/bfontaine/septeo/septeo_saaster_kit/docker-compose.yml) : on y ajoute un service `orchestrator` qui partage `postgres`, `temporal` (worker Python sur une task queue dédiée, à côté des workers Go de backend/customer_service/internal/adapters/temporal/client.go), `keycloak` et le collector SigNoz. (2) Kong (/home/bfontaine/septeo/septeo_saaster_kit/infra/kong/kong.yml) : nouvelle route HTTP/WebSocket `/agent` vers l'orchestrateur, sans grpc-gateway puisque le service parle HTTP/WS nativement. Il faut resserrer le plugin cors (origins ["*"] avec credentials: true) pour la route relais SDP. (3) Architecture : l'orchestrateur reprend l'arborescence hexagonale de backend/customer_service/internal (domain, ports/in, ports/out, adapters, application/services) en Python. OpenAI Live, Gemini, MCP, A2A et le canal app sont des adapters sortants derrière des ports, ce qui permet les fakes en test. (4) BDD : les .feature Gherkin écrits comme backend/customer_service/tests/features/*.feature (y compris le style « Temporal disponible / indisponible ») tournent avec pytest-bdd et testcontainers-python, comme tests/testcontainers.go. (5) Observabilité : on garde le même schéma OTLP que internal/adapters/observability/otel_facade.go et les mêmes noms de ressource. (6) CI : azure-pipelines.yml construit déjà les images avec Docker@2, on ajoute une image et un job pytest/ruff/mypy. (7) Les services Go existants deviennent des outils de l'orchestrateur : exposés en serveurs MCP via modelcontextprotocol/go-sdk (à ajouter dans leur go.mod), ou appelés en gRPC via des stubs Python générés depuis proto/customer.proto. Anti-pattern à ne PAS reproduire : internal/adapters/grpc/server.go:137 décode le JWT avec `ParseUnverified`, sans vérifier la signature. L'orchestrateur, qui émet des sessions vocales payantes, doit vérifier signature, issuer et audience via le JWKS Keycloak, ou s'appuyer sur un plugin OIDC Kong.

## 2. Vérifications adverses (5)

### Vérification 1

**Vérification de la stack backend Go (2026-10-27)**

Toutes les preuves viennent des fichiers source et des releases GitHub, lus avec `gh api`, et du dépôt local `/home/bfontaine/septeo/septeo_saaster_kit`. Aucune affirmation n'a été réfutée sur le fond. Trois sont fausses sur un détail, deux restent non prouvées, et plusieurs demandent une nuance.

**Liste des claims**

1. **openai-go v3 contient un package `live` : `client.Live.New` (POST /live/sessions) et `client.Live.Sessions` (Accept, Fork, Hangup, Refer, Reject, DownloadRecording).**
   - Verdict : confirmé.
   - Preuve : `live/api.md` liste ces six méthodes. `live/live.go` contient `path := "live/sessions"` en POST, avec le commentaire « Create a Live WebRTC session ». `LiveNewResponse.Transport.Sdp` porte la réponse SDP, donc le relais SDP passe bien par `Live.New`.
   - URL : https://github.com/openai/openai-go/blob/main/live/api.md

2. **`SidebandService.Connect(ctx, sessionID, ...)` ouvre un WebSocket GET sur live/sessions/{id}/attach, avec Send, Recv, SendRaw, RecvRaw, Close et Reconnect.**
   - Verdict : confirmé.
   - Preuve : la signature `Connect(ctx, sessionID string, options SidebandConnectionOptions, ...)` existe. Le binding fait `http.MethodGet` sur `"live/sessions/%s/attach"`. Les six méthodes sont présentes, plus une septième, `Abort`.
   - URL : https://github.com/openai/openai-go/blob/main/live/live_sideband_websocket.go

3. **Les événements sideband typés incluent `delegation.created`, `commentary.append/appended`, `thinking.append/appended`, `instructions.append`, `input_transcript.delta`, `output_transcript.delta`, `input_audio.mute` et `close/closed`.**
   - Verdict : confirmé.
   - Preuve : les chaînes `"session.*"` correspondantes sont dans `sideband.go`. `live.go:1029` indique « Speakable context... limited to 500 tokens ». `ClientDelegation.AcknowledgementDelayMs` et le discriminant `"client"` existent.
   - URL : https://github.com/openai/openai-go/blob/main/live/sideband.go

4. **openai-go v3 exige go 1.26.0 ; v3.83.0 à v3.88.0 sont sorties du 20 au 26 octobre ; le commit « add delegation controls » date du 2026-10-23.**
   - Verdict : confirmé, avec une nuance.
   - Preuve : `go 1.26.0` est dans le `go.mod`. v3.84.0 date du 21/10 et v3.88.0 du 26/10. Le commit #1150 date du 2026-10-23 à 23:04Z.
   - Nuance : les événements sideband typés datent seulement du 2026-10-17 (#1088), soit dix jours. Le package est donc encore plus jeune que ce que dit la proposition.
   - URL : https://github.com/openai/openai-go/releases

5. **go-genai v1.76.0 (22 octobre) expose `Live.Connect` et `LiveConnectConstraints` ; `client.AuthTokens` (type `Tokens`) a `Create` et journalise « experimental » ; le module exige go 1.24.**
   - Verdict : confirmé, sauf `Live.Connect` qui n'a pas été vérifié.
   - Preuve : `tokens.go:186-193` contient le message « ephemeral tokens implementation is experimental ». `client.go:55` déclare `AuthTokens *Tokens`. `types.go` contient `LiveConnectConstraints`, `CreateAuthTokenConfig` et `Uses *int32`. Le `go.mod` indique `go 1.24`, et v1.76.0 est datée du 2026-10-22.
   - URL : https://github.com/googleapis/go-genai/blob/main/tokens.go

6. **Les types Live et AuthToken sont documentés dans le package genai.**
   - Verdict : confirmé.
   - Preuve : les types sont dans `types.go` du package genai. Je n'ai pas ouvert pkg.go.dev.
   - URL : https://pkg.go.dev/google.golang.org/genai

7. **MCP go-sdk v1.7.0 (28 juillet) prend en charge complètement la spec 2026-07-28 (server/discover, mode Stateless, repli sur initialize) ; v1.8.0 (14 septembre) est la dernière ; `ClientCredentialsHandler` existe depuis v1.6.0.**
   - Verdict : confirmé, avec une nuance importante.
   - Preuve : les notes de v1.7.0 disent « full support for protocol version 2026-07-28 » et « falls back to legacy initialize if discover fails ». Les notes de v1.6.0 introduisent `ClientCredentialsHandler`. v1.8.0 ne change pas les révisions de protocole.
   - Nuance : la révision 2026-07-28 n'est acceptée en HTTP que si le serveur a `Stateless = true`. Sinon le client redescend en 2025-11-25.
   - URL : https://github.com/modelcontextprotocol/go-sdk/releases

8. **a2a-go/v2 cible la v1.0 Protocol Specification, avec les bindings gRPC, REST et JSON-RPC ; exige Go 1.26.0 ; dernière version v2.7.0 du 21 octobre ; compatibilité v0.3 via `a2acompat`.**
   - Verdict : confirmé.
   - Preuve : le README contient « v1.0 Protocol Specification » et liste les trois bindings. Le `go.mod` indique `go 1.26.0`, v2.7.0 est datée du 2026-10-21, et le dossier `a2acompat` existe. Le sous-paquet `a2av0` n'a pas été vérifié.
   - URL : https://github.com/a2aproject/a2a-go

9. **ADK Go v2 (go 1.26.10) dépend de go-sdk v1.8.0, openai-go/v3, genai v1.75.0, a2a-go v0.3.15 et a2a-go/v2 v2.6.0 ; `adka2a` a un sous-package v2 ; dernière v2.6.0 du 13 octobre ; v1.9.0 en parallèle.**
   - Verdict : confirmé.
   - Preuve : toutes ces lignes sont dans le `go.mod`. openai-go y est épinglé en v3.82.0. `server/adka2a/v2` existe. v2.6.0 date du 2026-10-13 et v1.9.0 du 2026-10-15.
   - Point à noter : le même `go.mod` exige `go.opentelemetry.io/otel v1.47.0`.
   - URL : https://github.com/google/adk-go/blob/main/go.mod

10. **Les releases ADK v2.x corrigent le streaming live, les toolsets MCP et l'auth A2A par requête (v2.6.0).**
    - Verdict : confirmé.
    - Preuve : les notes de v2.6.0 contiennent « feat(remoteagent): apply per-request auth to A2A », plusieurs « fix(mcptoolset) » et « fix(runner): preserve buffered live events ».
    - URL : https://github.com/google/adk-go/releases

11. **Temporal `go.temporal.io/googleadk` : chaque appel LLM devient une Activity, `NewMCPToolset` existe, plancher Go 1.26.6, déplacé hors de sdk-go/contrib.**
    - Verdict : confirmé.
    - Preuve : le `go.mod` indique `go 1.26.6`. Le README contient « Every LLM turn is a durable Activity », `googleadk.NewMCPToolset`, et « replacing go.temporal.io/sdk/contrib/googleadk ».
    - URL : https://github.com/temporalio/ai-integrations/tree/main/go/googleadk

12. **Temporal Go SDK v1.50.0 publiée le 15 octobre ; le kit Septeo est en v1.34.0.**
    - Verdict : confirmé.
    - Preuve : la release v1.50.0 date du 2026-10-15. Le `go.mod` local de customer_service contient `go.temporal.io/sdk v1.34.0`.
    - URL : https://github.com/temporalio/sdk-go/releases

13. **Pas de SDK A2UI Go officiel ; le dépôt contient dart, kotlin, python, swift et typescript, et les specs v0_8, v0_9, v0_9_1 et v1_0 ; les releases récentes sont Python (17 octobre).**
    - Verdict : confirmé.
    - Preuve : la racine du dépôt n'a aucun dossier Go et la recherche de code Go renvoie 0 résultat. Le dossier `specification/` contient bien les quatre versions. Les releases du 2026-10-17 sont a2ui-agent-sdk v0.9.0, a2ui-adk v0.1.0, a2ui-a2a v0.1.0 et a2ui-core v0.4.0.
    - URL : https://github.com/a2ui-project/a2ui

14. **Le plugin Genkit Go `a2ui/exp` est en preview, avec un mode Validate warn/strict/off sur la structure seulement, sans assainissement ; v0.9 par défaut.**
    - Verdict : confirmé.
    - Preuve : le code dit « in-preview » et contient `ValidateStrict`, `ValidateWarn` et `ValidateOff`. Il précise « well-formedness check, not sanitization... Image's url... pass through ». On y trouve aussi `DefaultVersion = "v0.9"` et `SupportedVersions = {"v0.9","v0.9.1"}` : il n'y a pas de v1.0.
    - URL : https://genkit.dev/docs/agents/a2ui/ (vérifié dans le code : https://github.com/firebase/genkit/tree/main/go/plugins/a2ui/exp)

15. **google/jsonschema-go v0.4.3 valide du JSON contre un schéma, infère des schémas depuis des structs Go, et ne dépend que de la stdlib.**
    - Verdict : confirmé.
    - Preuve : le README le dit. v0.4.3 date du 2026-04-27. Le `go.mod` indique `go 1.23.0` et ne requiert que go-cmp.
    - URL : https://github.com/google/jsonschema-go

16. **Le kit Septeo est en go 1.23.0 / toolchain 1.24.3 avec OTel v1.35.0.**
    - Verdict : confirmé.
    - Preuve : lignes correspondantes du `go.mod` local.
    - Fichier : /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service/go.mod

17. **`server.go:137` utilise `ParseUnverified` et Kong n'a pas de plugin JWT/OIDC.**
    - Verdict : confirmé.
    - Preuve : `server.go:137` contient `new(jwt.Parser).ParseUnverified(...)`. `kong.yml` n'a que `cors` et `rate-limiting`, sans jwt, oidc ni openid.
    - Fichiers : /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service/internal/adapters/grpc/server.go et /home/bfontaine/septeo/septeo_saaster_kit/infra/kong/kong.yml

18. **Les tests BDD utilisent Godog v0.13 et testcontainers v0.37 ; le Makefile contient des chemins `/Users/bfontaine` en dur.**
    - Verdict : confirmé.
    - Preuve : `tests/go.mod` contient godog v0.13.0 et testcontainers-go v0.37.0. Les lignes 33 et 34 du Makefile utilisent `/Users/bfontaine/go/bin`.
    - Fichiers : /home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service/tests/go.mod et le Makefile du même dossier

19. **« Il faut monter OTel vers au moins v1.45 pour être compatible avec ADK et googleadk. »**
    - Verdict : réfuté (seuil faux).
    - Preuve : googleadk exige otel v1.45.0, mais adk/v2 exige otel v1.47.0. Le plancher réel est donc v1.47.
    - URL : https://github.com/google/adk-go/blob/main/go.mod

20. **« Go 1.26.x » comme version du module dans le plan de phase 1.**
    - Verdict : réfuté (imprécis).
    - Preuve : adk/v2 exige `go 1.26.10`. Le toolchain doit donc être au moins 1.26.10, pas une 1.26.x quelconque.
    - URL : https://github.com/google/adk-go/blob/main/go.mod

21. **La CI Azure ne lance aucun test.**
    - Verdict : non prouvé.
    - Preuve : je n'ai trouvé aucun fichier de pipeline Azure dans les chemins que j'ai regardés.

22. **genui 0.10 côté Flutter consomme A2UI v0.9.**
    - Verdict : non prouvé.
    - Preuve : pas vérifié (paquet pub.dev non consulté).

23. **« Le client MCP en Streamable HTTP sans état (2026-07-28) avec repli sur initialize » comme chemin par défaut.**
    - Verdict : réfuté (nuance).
    - Preuve : le mode sans état ne s'applique que si chaque serveur métier active `Stateless=true`. Un serveur stateful fait redescendre la négociation en 2025-11-25. Ce n'est pas le client qui le décide.
    - URL : https://github.com/modelcontextprotocol/go-sdk/releases/tag/v1.7.0

**Les 3 corrections les plus importantes pour la proposition**

1. **Planchers de version.** Le toolchain doit être au moins Go 1.26.10, imposé par adk/v2 (1.26.6 et 1.26.0 ne suffisent pas). OTel doit être au moins v1.47.0, pas v1.45. Le plus simple est un module `agent_orchestrator` séparé, pour ne pas imposer ce double saut à customer_service. Il faut aussi épingler openai-go : ADK v2.6.0 tire v3.82.0, alors que les contrôles de délégation n'arrivent qu'en v3.86/v3.88, et Go retiendra la version la plus haute (MVS).

2. **Maturité de `openai-go/v3/live`.** Les événements sideband typés n'existent que depuis le 2026-10-17, et les contrôles de délégation depuis le 2026-10-23. La proposition le présente comme un acquis stable (« de bout en bout »), ce qui ne tient pas. Il faut l'isoler derrière `out.LiveProvider`, s'appuyer sur `SendRaw`/`RecvRaw` en repli, et écrire des tests contractuels sur des fixtures d'événements dès le premier jour. Même chose pour `AuthTokens.Create` côté Gemini, que le SDK marque lui-même expérimental.

3. **Version MCP réellement négociée.** Le 2026-07-28 sans état n'est obtenu que si chaque serveur MCP métier active `StreamableHTTPOptions.Stateless = true`, y compris customer_service exposé en MCP. Sinon on est en 2025-11-25 stateful, avec sessions, et le gateway doit le gérer. De même côté A2UI : Genkit ne couvre que v0.9 et v0.9.1, donc la cible v1.0 repose entièrement sur des types générés maison depuis `specification/v1_0`. Les métriques et tests de conformité doivent couvrir les deux versions.

### Vérification 2

# Vérification sceptique de la proposition hybride Go + Python (2026-10-27)

Bilan : l'essentiel des versions et des dates tient. Une affirmation structurante est fausse : openai-go fournit bien un client sideband typé (`SidebandService.Connect`). Plusieurs affirmations sont imprécises ou non prouvées.

## Affirmations vérifiées

1. **a2a-go v2.7.0 (2026-10-21) ; v2.4.0 apporte la compatibilité REST v0.3 ; v0.3.15 existe**
   - Verdict : **confirmé**.
   - Preuve : l'API GitHub des releases donne v2.7.0 au 2026-10-21. Les notes de v2.4.0 contiennent « a2acompat/a2av0: implement A2A v0.3 REST wire format ». Les tags v0.3.15 et v0.3.15+itk existent.
   - Source : https://github.com/a2aproject/a2a-go/releases

2. **README a2a-go : spec A2A v1.0, `go get .../a2a-go/v2`, Go 1.26.0 ou plus, bindings gRPC/REST/JSON-RPC, `a2aclient.NewFromCard`**
   - Verdict : **confirmé**.
   - Preuve : citation du README, « v1.0 Protocol Specification ». L'exemple `NewFromCard` y figure.
   - Source : https://github.com/a2aproject/a2a-go

3. **go.mod : a2a-go/v2 en `go 1.26.0`, MCP go-sdk en `go 1.25.0`, kit en go 1.23.0 / toolchain go1.24.3**
   - Verdict : **confirmé**.
   - Preuve : fichiers go.mod bruts lus directement. Le kit (`customer_service/go.mod`) est bien en `go 1.23.0` / `toolchain go1.24.3`.
   - Source : https://raw.githubusercontent.com/a2aproject/a2a-go/main/go.mod

4. **a2a-sdk Python 1.2.3 (2026-10-19), spec v1.0, compat 0.3, Python 3.10 ou plus**
   - Verdict : **confirmé**.
   - Preuve : l'API JSON de PyPI donne 1.2.3 au 2026-10-19 et `>=3.10`. La description dit « implements A2A 1.0, with compatibility mode for 0.3 ».
   - Source : https://pypi.org/project/a2a-sdk/

5. **google-adk 2.13.0 (2026-10-23), extras a2a et mcp, contraintes `a2a-sdk>=0.3.4,<2` et `mcp>=1.24,<3`**
   - Verdict : **confirmé**.
   - Preuve : PyPI et pyproject.toml.
   - Précision à ajouter : google-adk exige **Python 3.11 ou plus**, pas 3.10. Le plan, qui prévoit Python 3.12, reste compatible.
   - Source : https://raw.githubusercontent.com/google/adk-python/main/pyproject.toml

6. **Intégration A2UI d'ADK documentée en Python seulement, A2UI v0.9, DataPart `application/json+a2ui`**
   - Verdict : **confirmé, avec une nuance**.
   - Preuve : la page est étiquetée Python et tous les exemples sont en Python. On y trouve `A2uiSchemaManager`, `parse_response_to_parts` et `create_a2ui_part`, ainsi que le MIME type `application/json+a2ui`.
   - Nuance : la version d'A2UI n'est pas figée. Le gestionnaire de schéma « detect[s] the A2UI version from incoming client requests », et on peut l'épingler avec `VERSION_0_9`.
   - Source : https://adk.dev/integrations/a2ui/

7. **a2ui-core 0.4.0 (2026-10-17), Pydantic + JSON Schema 2020-12, A2UI v0.9 et suivantes ; aucun équivalent Go**
   - Verdict : **confirmé pour la version et le contenu**.
   - Preuve : PyPI donne 0.4.0 au 2026-10-17. La description dit « strictly targets v0.9 and onwards », « Pydantic » et « JSON Schema Draft 2020-12 ».
   - L'absence d'équivalent Go est **non prouvée** : « non mentionné » ne veut pas dire « inexistant ».
   - Complément : a2ui-agent-sdk est en 0.9.0 (2026-10-17).
   - Source : https://pypi.org/project/a2ui-core/

8. **ADK Go v2.6.0 (13 octobre) avec A2A, mcptoolset, RunLive et modèle OpenAI ; go 1.26.10 ; dépend de a2a-go/v2 v2.6.0 et MCP go-sdk v1.8.0**
   - Verdict : **confirmé**.
   - Preuve : la release v2.6.0 date du 2026-10-13. Le dépôt contient `model/openaimodel/openaimodel.go`, et `runner.go` déclare `func (r *Runner) RunLive`. Le go.mod donne `go 1.26.10`, a2a-go/v2 v2.6.0 et go-sdk v1.8.0.
   - Points à ajouter : le go.mod dépend **aussi** d'a2a-go v0.3.15. Une ligne v1.x (v1.9.0, 2026-10-15) est maintenue en parallèle.
   - Source : https://github.com/google/adk-go/releases

9. **MCP go-sdk v1.8.0 ; spec 2026-07-28 prise en charge depuis v1.7.0 en Streamable HTTP Stateless ; repli sur 2025-11-25**
   - Verdict : **confirmé**.
   - Preuve : les notes de v1.7.0 disent « full support for protocol version 2026-07-28… only when StreamableHTTPOptions.Stateless = true… negotiate down to 2025-11-25 ». Celles de v1.8.0 disent « 2026-07-28 remains the newest ».
   - Les gestionnaires OAuth client n'ont **pas été vérifiés** nommément.
   - Source : https://github.com/modelcontextprotocol/go-sdk/releases

10. **openai-go expose `client.Live.New` (POST /live/sessions), `MediaSessionConfigModelGPTLive1` et un transport SDP ; aucune méthode Go d'attachement sideband**
    - Verdict : **confirmé pour la page, mais la conclusion est réfutée**.
    - Preuve : la page documente bien `client.Live.New`, `live.MediaSessionConfigModelGPTLive1` et `LiveNewParamsTransport.Sdp`. Elle renvoie cependant vers une référence « Sideband WebSocket » distincte.
    - Ce que montre le code : `live/sideband.go` et `live/live_sideband_websocket.go` définissent `SidebandService.Connect(ctx, sessionID, …) (*SidebandConnection, error)`, avec `Send`, `Recv`, `SendRaw` et `RecvRaw`. Les constructeurs `ConnectClientEventParamOfSessionThinkingAppend` et `…CommentaryAppend` et `…InstructionsAppend` sont présents.
    - Ces helpers existent depuis l'ajout de la Live API (commit #912 du 2026-09-10) et sont présents en v3.70 comme en v3.88.
    - Source : https://github.com/openai/openai-go/tree/main/live

11. **openai-go v3.88.0 (2026-10-26) ; changement cassant Live en v3.86.0 ; helpers WebSocket bruts en v3.83.0 ; aucune entrée sur le sideband**
    - Verdict : **partiellement réfuté**.
    - Ce qui est exact : les dates, et le contenu de v3.83.0 (« add raw WebSocket helpers »).
    - Imprécision : le changement cassant de v3.86.0 (2026-10-23) ne touche que les champs `Instructions` des Decisions et des questions Live, devenus des unions typées. Il ne concerne pas « les champs Live » en général.
    - Erreur : « aucune entrée sur le sideband » mène à une conclusion fausse. `SendRaw` et `RecvRaw` ont été ajoutés justement à `SidebandConnection`, et le sideband typé existe depuis septembre.
    - Source : https://github.com/openai/openai-go/releases

12. **Sideband : `wss://…/v1/live/sessions/{id}/attach`, Bearer avec une clé du même projet, liste d'événements ; aucun exemple d'attachement complet**
    - Verdict : **confirmé pour l'URL, l'authentification et les événements ; réfuté pour les exemples**.
    - Preuve : l'URL et l'authentification sont citées telles quelles. Les événements `session.thinking.append`, `commentary.append`, `instructions.append`, `response.item.create`, `response.create` et `session.close` figurent sur la page.
    - Ce qui est faux : la page contient bien des exemples, en JavaScript (Node `ws`) et en Python (`connection.session.instructions.append`).
    - Source : https://developers.openai.com/api/docs/guides/voice-server-controls?api=live

13. **openai-python v3.35.0 (2026-10-17) ajoute des événements sideband typés ; dernière version v3.39.0 (2026-10-26) ; Python plus avancé que Go sur ce point**
    - Verdict : **confirmé pour les faits, réfuté pour la conclusion**.
    - Preuve : les notes de v3.35.0 disent « add typed Live sideband events ». v3.39.0 date bien du 2026-10-26.
    - Ce qui est faux : la conclusion « plus avancé que Go ». Go dispose d'événements typés depuis 2026-09-10 (voir point 10).
    - Source : https://github.com/openai/openai-python/releases

14. **google.golang.org/genai v1.76.0 (2026-10-22) : `AuthToken`, `CreateAuthTokenConfig`, `Tokens.Create`, Live**
    - Verdict : **confirmé**.
    - Preuve : proxy.golang.org donne v1.76.0 au 2026-10-22. pkg.go.dev liste `type AuthToken`, `CreateAuthTokenConfig`, `Tokens.Create(ctx, config)`, `LiveConnectConstraints` et `Live.Connect`.
    - Source : https://pkg.go.dev/google.golang.org/genai

15. **Jetons éphémères Gemini : exemples Python, JS et REST, pas de Go ; expireTime 30 min, newSessionExpireTime 1 min, uses 1, liveConnectConstraints**
    - Verdict : **confirmé**.
    - Preuve : l'endpoint est `v1beta/auth_tokens`, et la page précise que les jetons fonctionnent « only with the v1beta version ». Les valeurs par défaut correspondent.
    - Source : https://ai.google.dev/gemini-api/docs/ephemeral-tokens

16. **genui_a2a 0.10.1 : `A2uiAgentConnector`, version A2A non indiquée, transport ambigu**
    - Verdict : **confirmé**.
    - Preuve : la page dit « Handles the low-level WebSocket communication with the A2A server ». Elle liste `sse_channel` en dépendance sans en expliquer le rôle, et n'indique aucune version A2A.
    - Source : https://pub.dev/packages/genui_a2a

17. **go.temporal.io/sdk v1.50.0 (2026-10-15) ; le kit est en v1.34.0**
    - Verdict : **confirmé**.
    - Preuve : la release GitHub v1.50.0 date du 2026-10-15. Le go.mod du kit déclare `go.temporal.io/sdk v1.34.0`.
    - Source : https://github.com/temporalio/sdk-go/releases

18. **mcp Python 2.3.0 (2026-10-02) ; version de spec non précisée**
    - Verdict : **confirmé**.
    - Preuve : PyPI donne 2.3.0 au 2026-10-02. La description ne mentionne aucune date de spec.
    - Conséquence : la prise en charge de la spec 2026-07-28 en Python est **non prouvée**, alors que la proposition l'affirme pour l'outil MCP de phase 1.
    - Source : https://pypi.org/project/mcp/

19. **Délégation client GPT-Live : `session.delegation.created` sans les mots de l'utilisateur, transcripts par `input_transcript.delta` et `output_transcript.delta`, 500 tokens par message, `event_id` unique, `delegation.type='client'`, `acknowledgement_delay_ms`**
    - Verdict : **confirmé**.
    - Preuve : le guide de délégation dit « does not contain the user's utterance or task text » et « limited to 500 tokens per append ». Il donne l'exemple `{"type":"client","acknowledgement_delay_ms":800}`.
    - Source : https://developers.openai.com/api/docs/guides/live-delegation

20. **Barge-in : annulation à gérer côté backend, puis confirmation avant de l'annoncer**
    - Verdict : **confirmé**.
    - Preuve : le guide dit « Interrupting the spoken conversation leaves backend work running… confirm it succeeded before telling the user ». Aucune commande d'annulation de délégation n'existe côté Live.
    - Point à ajouter : toute commande `thinking.append` ou `commentary.append` annule **tous** les accusés automatiques en attente de la session, y compris ceux des autres délégations.
    - Source : https://developers.openai.com/api/docs/guides/live-delegation

21. **A2UI v1.0 encore en RC**
    - Verdict : **confirmé**.
    - Preuve : a2ui.org indique « v1.0 candidate… for production use, consider v0.9.1 (Current) ».
    - Source : https://a2ui.org/specification/v1.0-a2ui/

22. **Prérequis du kit : `ParseUnverified` ligne 137, CORS `*` avec credentials:true, pas de plugin JWT/OIDC, pipeline Azure limité aux builds Docker**
    - Verdict : **confirmé**.
    - Preuve : lecture locale de `internal/adapters/grpc/server.go:137`, `infra/kong/kong.yml` (aucun plugin jwt/oidc) et `azure-pipelines.yml` (tâches Docker@2 uniquement).
    - Source : /home/bfontaine/septeo/septeo_saaster_kit

23. **`NON_BLOCKING` indisponible dans firebase_ai**
    - Verdict : **non prouvé**.
    - Preuve : la documentation Gemini décrit `NON_BLOCKING` pour Python et JS. Rien n'a été trouvé sur firebase_ai, ni pour, ni contre.
    - Source : https://ai.google.dev/gemini-api/docs/live-api/tools

24. **Jeton éphémère v1beta utilisable par l'app Flutter via firebase_ai**
    - Verdict : **non prouvé (risque implicite)**.
    - Preuve : firebase_ai passe par le proxy Firebase AI Logic et App Check (`FirebaseAI.googleAI(appCheck: …)`). Aucune source ne montre que firebase_ai accepte un jeton éphémère `auth_tokens`.
    - Source : https://firebase.google.com/docs/ai-logic/app-check

25. **Surcoût de 2 à 15 ms par saut Go vers Python**
    - Verdict : **non prouvé**.
    - Preuve : c'est une estimation de l'auteur, qu'il signale lui-même comme non mesurée.
    - Source : aucune

## Les 3 corrections les plus importantes

1. **Corriger l'argument sur le sideband.** openai-go fournit `live.SidebandService.Connect` et `SidebandConnection.Send`, `Recv`, `SendRaw` et `RecvRaw`, avec des constructeurs typés pour `session.thinking.append`, `commentary.append` et `instructions.append`. Ils existent depuis la Live API du 2026-09-10.
   - Il faut supprimer la faiblesse « protocole écrit à la main en Go, Python plus confortable » et retirer coder/websocket et gorilla de la stack du SidebandSupervisor.
   - La conclusion change : le SidebandSupervisor en Go devient moins risqué. En revanche, l'argument en faveur de Python se réduit encore à la seule brique A2UI.

2. **Rouvrir l'option tout-Go et ne plus la renvoyer en fin de phase 1.** Côté Go, tout est vérifié : ADK Go v2.6 (A2A, mcptoolset, RunLive, openaimodel), a2a-go/v2, MCP go-sdk 2026-07-28, genai Tokens.Create, et le sideband typé d'openai-go.
   - Le seul manque réel est l'outillage A2UI côté agent, qui n'existe qu'en Python. Or la proposition prévoit déjà une validation JSON Schema 2020-12 du catalogue en Go.
   - Avant d'imposer deux langages à une équipe Flutter + Go, il faut chiffrer la variante tout-Go : génération A2UI guidée par le schéma du catalogue, validation santhosh-tekuri/jsonschema, régénération en cas de rejet.
   - Si l'hybride est conservé, il faut le justifier par autre chose que le sideband.

3. **Préciser le chemin Gemini et les versions.**
   - (a) Il n'est pas prouvé que firebase_ai, qui passe par Firebase AI Logic et App Check, accepte un jeton `v1beta/auth_tokens`. Il faut soit utiliser une connexion WebSocket Gemini directe côté Flutter, soit utiliser App Check plutôt qu'un jeton émis par le gateway. Il faut trancher par un spike avant l'étape 2.
   - (b) Le support de la spec MCP 2026-07-28 par le SDK Python mcp 2.3.0 n'est pas documenté. Il faut le vérifier, ou accepter un repli sur 2025-11-25.
   - (c) Corriger les détails : google-adk exige Python 3.11 ou plus ; le changement cassant de v3.86.0 ne touche que les champs `Instructions` ; la page sideband contient bien des exemples en JS et en Python ; ADK Go dépend aussi d'a2a-go v0.3.15.

### Vérification 3

# Vérification de la stack backend Dart (2026-10-27)

La plupart des affirmations tiennent. Trois points sont faux ou à corriger :
- **A2UI v1.0 n'est pas une version stable.** C'est un « release candidate ». La version en production est v0.9.1.
- **La « double validation identique » entre l'app et l'orchestrateur ne tient pas avec les versions proposées** (voir correction 1).
- **Le champ de configuration des jetons Gemini est mal nommé** dans la proposition (voir correction 3).

Par ailleurs, openai_dart couvre déjà la délégation et le sideband dans son code : le risque principal du spike est donc plus faible qu'annoncé.

Méthode : métadonnées de l'API pub.dev, lecture du code et des changelogs des archives téléchargées (/tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/4c090190-d378-4c58-84ec-7e52cf30a8ed/scratchpad/pub/tars/), documentation officielle (OpenAI, Google, a2ui.org, A2A, Temporal, api.dart.dev) et fichiers du saaster kit.

## Liste des affirmations

1. **a2ui_core 0.3.0 est du Dart pur, gère les enveloppes v0.9, v0.9.1 et v1.0, et fournit PayloadValidator (JSON Schema 2020-12).**
   - Verdict : **confirmé.**
   - Preuve : publié par labs.flutter.dev le 2026-10-19. Ses dépendances sont exactement celles citées, sans Flutter. Tags `sdk:dart`, `runtime:native-aot`. Le README annonce la validation des enveloppes v0.9, v0.9.1 et v1.0 et « JSON Schema Draft 2020-12 ».
   - Réserve : sur a2ui.org, la v1.0 est un « Release candidate » et la v0.9.1 est la « Current production release ».
   - URL : https://pub.dev/packages/a2ui_core

2. **0.3.0 introduit la v1.0 (RpcHandler, allowedCallers, openUrl sous activation utilisateur) avec de nombreuses ruptures ; en 0.2.x, seul v0.9 était accepté.**
   - Verdict : **confirmé.**
   - Preuve : le changelog 0.2.0 dit « Every entry point accepts protocol v0.9 only ». La 0.3.0 liste de nombreux « **Breaking:** » et indique que `BasicCatalog.v1_0().functions['openUrl']` exige une activation utilisateur. Nuance : la 0.2.2 avait déjà des tests de conformité v1.0.
   - URL : https://pub.dev/packages/a2ui_core/changelog

3. **genui 0.10.4 exige Flutter (Android, iOS, macOS, web) et dépend de a2ui_core ^0.1.0.**
   - Verdict : **confirmé.**
   - Preuve : dépendances `flutter: sdk`, `a2ui_core: ^0.1.0`, ce qui veut dire inférieur à 0.2.0. Tags de plateforme android, ios, macos et web.
   - URL : https://pub.dev/packages/genui

4. **genui_a2a 0.10.1 dépend de a2ui_core ^0.1.0 et ne précise pas sa version de spec A2A.**
   - Verdict : **confirmé.** Le README ne donne aucune version.
   - Ce que montre le code : il appelle les méthodes JSON-RPC `message/send` et `message/stream`, et l'AgentCard porte `protocolVersion` à la racine. Ce sont les formes de la spec v0.3, pas de la v1.0.
   - URL : https://pub.dev/packages/genui_a2a

5. **mcp_dart 2.4.3 (leehack.com) préfère MCP 2026-07-28 avec repli, offre le Streamable HTTP, OAuth + PKCE et un authenticator serveur.**
   - Verdict : **confirmé.**
   - Preuve : le changelog dit « McpProtocol.stable now prefers MCP 2026-07-28 and falls back ». Le code contient la vérification PKCE S256 dans `streamable_https.dart`. Le changelog revendique que les suites officielles « alpha.10 » de la 2026-07-28 passent, y compris « all 25 OAuth scenarios ». La spec 2026-07-28 est finale, publiée le 28/07. La conformité reste une auto-déclaration.
   - URL : https://pub.dev/packages/mcp_dart

6. **a2a 4.3.1 cible A2A v0.3, en JSON-RPC uniquement, avec un serveur toujours bloquant et sans l'auth de la §4.**
   - Verdict : **confirmé.**
   - Preuve : le README dit mot pour mot « implements the A2A Protocol Specification V0.3 », « Only the JSON-RPC 2.0 transport », « section 4 … is not supported », « server will always treat the request as blocking ». L'éditeur est darticulate.com.
   - URL : https://pub.dev/packages/a2a

7. **Les SDK A2A officiels existent en Python, Go, Java, JS, .NET et Rust, pas en Dart.**
   - Verdict : **confirmé.**
   - URL : https://a2a-protocol.org/latest/sdk/

8. **openai_dart 11.0.1 est communautaire (davidmiguel.com) et couvre Responses (SSE, WebSockets persistants) et Live.**
   - Verdict : **confirmé.**
   - Preuve : le README dit « community-maintained … not affiliated with … OpenAI ». Le changelog 11.0.0 couvre `responses.connect()` et `client.live.sessions`.
   - URL : https://pub.dev/packages/openai_dart

9. **Le changelog ne nomme ni la délégation ni commentary.append, donc leur couverture reste à vérifier.**
   - Verdict : **réfuté sur le fond.** Le changelog ne les nomme pas, mais le code les implémente.
   - Ce que contient le code :
     - `LiveDelegationCreated` pour l'événement `session.delegation.created` ;
     - les événements `session.thinking.appended` et `session.commentary.appended` ;
     - le endpoint `'/live/sessions/$encoded/attach'` ;
     - les commandes client documentées « limited to 500 tokens » ;
     - le mode `delegation.type` avec `'client'` par défaut.
   - Le seul identifiant de modèle présent dans le code est `gpt-live-transcribe`. Le code ne fixe donc pas de modèle Live ; gpt-live-1 se passe en paramètre.
   - URL : https://pub.dev/packages/openai_dart (lib/src/models/live/)

10. **API OpenAI elle-même : POST /live/sessions pour WebRTC, sideband `/v1/live/sessions/{id}/attach`, `delegation: {type: "client"}`, `session.thinking.append`.**
    - Verdict : **confirmé.**
    - Pour `session.commentary.append` : **non prouvé** par la documentation publique consultée, mais présent dans openai_dart.
    - URL : https://developers.openai.com/api/reference/resources/live/sideband-websocket

11. **googleai_dart 13.0.0 est communautaire et annonce le Live API (createLiveClient) et les Auth Tokens.**
    - Verdict : **confirmé.**
    - Preuve : le README dit « not affiliated with … Google » et indique « Auth Tokens | ✅ Full ». Le code construit l'URL `/{version}/auth_tokens`.
    - URL : https://pub.dev/packages/googleai_dart

12. **Jeton éphémère Gemini via v1beta/auth_tokens « avec liveConnectConstraints ».**
    - Verdict : **réfuté en partie.**
    - Ce qui tient : v1beta est bien requis pour l'API Live.
    - Ce qui ne tient pas : dans l'API REST, le champ s'appelle `bidiGenerateContentSetup` (avec `fieldMask`, `uses`, `expireTime` et `newSessionExpireTime`). `liveConnectConstraints` est le nom utilisé par le SDK google-genai. googleai_dart sérialise bien `bidiGenerateContentSetup`.
    - URL : https://ai.google.dev/api/live#AuthToken

13. **dart:io WebSocket.connect accepte `headers` (Map<String, dynamic>?).**
    - Verdict : **confirmé.**
    - URL : https://api.dart.dev/dart-io/WebSocket/connect.html

14. **firebase_admin_sdk 0.5.6 est publié par firebase.google.com avec appCheck().verifyToken, et dart_firebase_admin est discontinué.**
    - Verdict : **confirmé.**
    - Preuve : dart_firebase_admin a `isDiscontinued=true` avec `replacedBy=firebase_admin_sdk`.
    - URL : https://pub.dev/packages/firebase_admin_sdk

15. **dartastic_opentelemetry 0.12.0 fournit traces, métriques et logs en OTLP gRPC et HTTP, et n'est pas encore CNCF.**
    - Verdict : **confirmé.**
    - Preuve : il a des exporteurs gRPC et HTTP pour les trois signaux. Le README parle d'un projet « in the process of being Donation to the CNCF ».
    - Nuance pour la faiblesse « aucune instrumentation automatique » : il existe des intégrations `otel_*`, dont Shelf. L'instrumentation GenAI automatique n'existe qu'en offre « Pro ».
    - URL : https://pub.dev/packages/dartastic_opentelemetry

16. **Le package `opentelemetry` est déprécié au profit de opentelemetry_wk.**
    - Verdict : **confirmé.**
    - Preuve : le README s'intitule « opentelemetry (deprecated) » et le package ne fait plus que réexporter opentelemetry_wk (éditeur workiva.com).
    - URL : https://pub.dev/packages/opentelemetry

17. **Temporal n'a pas de SDK Dart.**
    - Verdict : **confirmé.** Les SDK officiels sont Go, Java, Python, TypeScript, .NET, Ruby, PHP et Rust. Dart n'est pas non plus parmi les SDK non officiels.
    - URL : https://docs.temporal.io/encyclopedia/temporal-sdks

18. **dart_frog 1.2.6 date d'environ 11 mois, dart_frog_web_socket 1.0.3 d'environ 12 mois.**
    - Verdict : **confirmé, à un mois près.** Les dates de publication sont le 2025-11-03 (environ 12 mois) et le 2025-10-03 (environ 13 mois).
    - À noter aussi : shelf_web_socket 3.0.0 date du 2025-01-30.
    - URL : https://pub.dev/packages/dart_frog

19. **serverpod 4.0.4 apporte ORM, auth, sockets et future calls persistantes, sans OpenTelemetry.**
    - Verdict : **confirmé.** Le README dit « The calls persist even if the server is restarted ». Ni le README ni le code ne contiennent « opentelemetry ».
    - URL : https://pub.dev/packages/serverpod

20. **grpc 5.2.0 (dart.dev) supporte la VM Dart.**
    - Verdict : **confirmé.** Publié le 2026-10-15.
    - URL : https://pub.dev/packages/grpc

21. **Affirmations sur le saaster kit.**
    - Verdict : **confirmé.** Les fichiers cités existent :
      - `backend/customer_service/proto/customer.proto` ;
      - la cible `proto:` du Makefile ;
      - `internal/workflows/` ;
      - `adapters/observability/otel_facade.go` ;
      - `infra/kong/kong.yml` ;
      - `azure-pipelines.yml` ;
      - les services keycloak et signoz-otel-collector dans le docker-compose.
    - `openid_client` : **non prouvé**, non vérifié.

22. **Critère du spike : moins de 50 ms de latence ajoutée.**
    - Verdict : **non prouvé.** C'est un objectif, sans mesure ni source.

## Les 3 corrections les plus importantes

1. **Le principal argument de la proposition, « même moteur a2ui_core côté app et serveur », est faux tel qu'écrit.**
   - L'app genui 0.10.4 est verrouillée sur a2ui_core inférieur à 0.2.0, qui n'accepte que v0.9.
   - A2UI v1.0 n'est qu'un « release candidate » ; la version en production est v0.9.1.
   - Pour qu'une double validation soit réellement identique en phase 1, l'orchestrateur doit épingler la même a2ui_core 0.1.x que genui et produire du v0.9. Le passage à 0.3.0 / v1.0 doit attendre que genui migre et que la v1.0 soit finale.
   - Il faut aussi retirer « v1.0 » de la description de la stack et des atouts.

2. **Revoir le risque n°1 du spike sideband à la baisse.**
   - openai_dart 11 type déjà `session.delegation.created`, les événements thinking et commentary appended, l'attach `/live/sessions/{id}/attach` et `delegation.type=client` (limite de 500 tokens documentée).
   - Le spike doit donc commencer par openai_dart et vérifier seulement deux points : que gpt-live-1 est accepté en paramètre, et que `session.commentary.append` existe bien dans la référence OpenAI (non trouvé dans la documentation publique consultée).
   - Le WebSocket fait à la main reste le plan B.

3. **Corriger les jetons Gemini.**
   - L'API REST `v1beta/auth_tokens` attend `bidiGenerateContentSetup` + `fieldMask`. `liveConnectConstraints` est le nom du SDK google-genai, et googleai_dart utilise `bidiGenerateContentSetup`.
   - Il faut aussi fixer `newSessionExpireTime` (60 s par défaut), `expireTime` et `uses=1`.
   - Mettre à jour le composant « Relais de session voix » et la tâche S1 en conséquence.

Point secondaire : le canal « plus tard genui_a2a » parle de l'A2A v0.3 (`message/send`), pas de la v1.0, comme le package a2a. Il ne faut donc compter sur aucune voie Dart pour l'A2A v1.0 en phase 2.

### Vérification 4

# Vérification de la stack backend Python, au 2026-10-27

J'ai téléchargé et ouvert les wheels PyPI des paquets cités, interrogé `proxy.golang.org`, pub.dev et l'API GitHub, puis relu le saaster kit en local. Sur 15 affirmations SDK, 12 sont confirmées par le code. Deux erreurs comptent vraiment : un conflit de dépendances qui casse la stack telle qu'elle est écrite, et une erreur sur la version de l'API Gemini.

## Verdicts

```json
[
 {"claim":"openai 3.39.0 (2026-10-26) expose GPT-Live : client.live.create, live.sideband.connect avec reconnexion et file d'envoi, sessions.hangup/fork/accept/reject, les types ClientDelegation, DelegationCreatedEvent, CommentaryAppendEvent et ThinkingAppendEvent","verdict":"confirmé","preuve":"Wheel 3.39.0 (upload 2026-10-26T19:19). resources/live/live.py:create fait POST /live/sessions avec transport {type:'webrtc', sdp}. sideband.py fait /live/sessions/{id}/attach, avec on_reconnecting, max_retries=5 et SendQueue. sessions.py contient accept, fork, hangup, refer et reject. commentary_append_event_param et thinking_append_event_param indiquent « limited to 500 tokens ». acknowledgement_delay_ms est dans media_session_config_param.","url":"https://pypi.org/pypi/openai/json"},
 {"claim":"Troisième mode de délégation `decisions` dans le SDK openai","verdict":"confirmé","preuve":"types/live/decisions_delegation_config.py et une trentaine de types decision_*. DelegationCreatedEvent.target vaut Literal['client','responses','decisions']. openai-go v3.88.0 contient aussi live/decisions_contract_test.go.","url":"https://pypi.org/pypi/openai/json"},
 {"claim":"openai-agents 0.24.0 ne gère pas GPT-Live (seulement /v1/realtime)","verdict":"confirmé","preuve":"agents/realtime/openai_realtime.py:631-633 se connecte à wss://api.openai.com/v1/realtime?call_id= ou ?model=. gpt-live n'apparaît que sous la forme gpt-live-transcribe, dans voice/ et realtime/config.py:85.","url":"https://pypi.org/pypi/openai-agents/json"},
 {"claim":"pydantic-ai 2.62.0 gère gpt-live-1, mais seulement la délégation responses, et create_client_secret lève toujours une erreur","verdict":"confirmé","preuve":"realtime/openai_live.py : la docstring dit que l'adaptateur configure seulement `responses`. _map_delegation renvoie une erreur 'live_client_delegation' si target=='client'. create_client_secret lève UserError ('GPT-Live has no ephemeral client secrets'). Le paquet est sorti le 2026-10-27, donc il bouge vite.","url":"https://pypi.org/pypi/pydantic-ai-slim/json"},
 {"claim":"google-adk 2.13.0 (2026-10-23, Python ≥3.11) : modules a2a/live/telemetry/workflow/mcp_tool, a2a-sdk <2, mcp <3, OTel 1.39–1.44","verdict":"confirmé","preuve":"Les modules a2a, live, telemetry, workflow et tools/mcp_tool sont présents, ainsi que AgentMode.SINGLE_TURN et tools/agent_tool.py. METADATA : opentelemetry-api/sdk >=1.39,<=1.44 ; a2a-sdk[http-server] >=0.3.4,<2 ; mcp >=1.24,<3. Point omis par la proposition : les extras [openai], [extensions] et [all] imposent openai >=2.20,<3, ce qui est incompatible avec openai 3.39.","url":"https://pypi.org/pypi/google-adk/json"},
 {"claim":"a2a-sdk 1.2.3 : PROTOCOL_VERSION_CURRENT='1.0', compatibilité 0.3 quand l'en-tête est absent","verdict":"confirmé","preuve":"a2a/utils/constants.py:29-31 (PROTOCOL_VERSION_1_0='1.0', CURRENT=1_0, PROTOCOL_VERSION_0_3='0.3'). version_validator.py:27 traite un en-tête A2A-Version absent comme 0.3.","url":"https://pypi.org/pypi/a2a-sdk/json"},
 {"claim":"mcp 2.3.0 (2026-10-02) implémente la spec 2026-07-28 (SEP-2575 subscriptions/listen, SEP-2577 dépréciation du sampling) et gère les versions antérieures","verdict":"confirmé","preuve":"mcp/shared/subscriptions.py:1 (« subscriptions/listen (2026-07-28, SEP-2575) »). peer.py:88 marque le sampling @deprecated (SEP-2577). mcp_types/methods.py associe les méthodes aux versions. Je n'ai pas testé moi-même le repli `initialize` pour les anciens serveurs.","url":"https://pypi.org/pypi/mcp/json"},
 {"claim":"A2UI a migré de google/A2UI vers a2ui-project/a2ui ; SDK python, dart, kotlin, swift et typescript, pas de Go ; exemples dans samples/agent/adk","verdict":"confirmé","preuve":"api.github.com/repos/google/A2UI renvoie 301 vers repositories/1063641074, qui a pour full_name a2ui-project/a2ui. À la racine : dart, kotlin, python, swift, typescript, conformance, aucun dossier go. python/ contient a2ui_a2a, a2ui_adk, a2ui_agent et a2ui_core. samples/agent/adk contient custom-components-example et restaurant_finder.","url":"https://api.github.com/repositories/1063641074/contents/python"},
 {"claim":"a2ui-agent-sdk 0.9.0 : A2uiGenerator, A2uiRequestProcessor, CatalogConfig, transformers d'élagage, validate_payload ; a2ui-core 0.4 avec V0_8, V0_9 et V1_0","verdict":"confirmé","preuve":"processor/generator.py:35, processor/processor.py:33, processor/catalog_config.py:31, utils/validation.py:75, ComponentPruningTransformer et FunctionPruningTransformer. Dépend de a2ui-core <0.5,>=0.4. a2ui/core/schema/__init__.py définit V0_8, V0_9, V0_9_1 et V1_0. La proposition ne mentionne pas V0_9_1, qui existe.","url":"https://pypi.org/pypi/a2ui-agent-sdk/json"},
 {"claim":"a2ui-adk 0.1.0 : SendA2uiToClientToolset et extra [a2a] (convertisseurs, orchestration)","verdict":"confirmé","preuve":"a2ui/adk/send_a2ui_to_client_toolset.py:123, dossiers a2ui/adk/a2a et a2ui/adk/orchestration. L'extra a2a dépend de a2ui-a2a et de google-adk[a2a]>=1.28.1.","url":"https://pypi.org/pypi/a2ui-adk/json"},
 {"claim":"ag-ui-protocol 1.0.0 (2026-09-17, ag_ui.core) et ag-ui-adk 0.11.0 (2026-10-21)","verdict":"confirmé","preuve":"Dates confirmées sur PyPI. ag_ui/core contient events.py, types.py et capabilities.py. ag-ui-adk dépend de a2ui-agent-sdk >=0.9,<0.10 et de a2ui-core <0.5, ce qui est cohérent avec la proposition.","url":"https://pypi.org/pypi/ag-ui-adk/json"},
 {"claim":"temporalio 1.34.0 inclut contrib google_adk_agents, openai_agents, google_genai et opentelemetry, utilisables dans cette stack","verdict":"réfuté (partiellement)","preuve":"Les modules existent bien dans la wheel. En revanche, les extras sont incompatibles avec la stack proposée. temporalio[google-adk] impose mcp >=1.24,<2, alors que la stack prévoit mcp 2.3. temporalio[openai-agents] impose openai-agents >=0.19.2,<0.20 et mcp <2. Avec mcp 2.3, ces intégrations ne s'installent pas proprement. Autre point : la 1.34.0 date du 2026-09-30.","url":"https://pypi.org/pypi/temporalio/json"},
 {"claim":"opentelemetry-instrumentation-google-genai 1.3b0 (2026-10-23) et openai-v2 2.4b0 (2026-05-01), en bêta","verdict":"confirmé","preuve":"Dates confirmées. google-genai 1.3b0 impose opentelemetry-api ~=1.43. Avec le plafond ADK (<=1.44), la fenêtre OTel réelle est donc 1.43–1.44, et non 1.39–1.44.","url":"https://pypi.org/pypi/opentelemetry-instrumentation-google-genai/json"},
 {"claim":"google-genai 2.33.0 expose client.auth_tokens.create ; endpoint v1beta/auth_tokens, uses=1, liveConnectConstraints","verdict":"réfuté (partiellement)","preuve":"client.auth_tokens.create existe (tokens.py:123), marqué « [Experimental] ». CreateAuthTokenConfig contient bien uses, live_connect_constraints et lock_additional_fields. Mais la docstring dit « Support in v1alpha only » et l'exemple utilise HttpOptions(api_version='v1alpha'). Rien dans le SDK ne confirme « v1beta/auth_tokens ».","url":"https://pypi.org/pypi/google-genai/json"},
 {"claim":"Parité Go : openai-go v3.88.0 avec live/ ; go-sdk v1.8.0 avec server/discover 2026-07-28 ; a2a-go/v2 v2.7.0 ; adk-go v1.9.0 ; genai Go v1.76.0 avec l'exemple live_with_ephemeral_token","verdict":"confirmé","preuve":"proxy.golang.org : openai-go v3.88.0 (2026-10-26), go-sdk v1.8.0 (sortie le 2026-09-04, pas en octobre), a2a-go/v2 v2.7.0 (2026-10-21), adk v1.9.0 (2026-10-15), genai v1.76.0 (2026-10-22). openai-go/live contient live.go, fork.go, sideband.go et decisions_contract_test.go. go-sdk mcp/transport_example_test.go montre server/discover avec supportedVersions qui inclut 2026-07-28. go-genai contient examples/live_with_ephemeral_token/.","url":"https://proxy.golang.org/github.com/openai/openai-go/v3/@latest"},
 {"claim":"genui 0.10.4 dépend de a2ui_core ^0.1.0 (Dart)","verdict":"confirmé","preuve":"pub.dev /api/packages/genui : latest 0.10.4, dependencies a2ui_core ^0.1.0.","url":"https://pub.dev/api/packages/genui"},
 {"claim":"Saaster kit : server.go:137 ParseUnverified ; CORS Kong origins ['*'] avec credentials:true ; temporal, keycloak et signoz-otel-collector dans docker-compose ; features Gherkin dont customer_temporal_workflows.feature","verdict":"confirmé","preuve":"Lecture locale : grpc/server.go:137 contient `new(jwt.Parser).ParseUnverified`. kong.yml:6-9, 68-71 et 97 : origins [\"*\"] avec credentials: true. docker-compose.yml contient les services temporal (auto-setup), keycloak, signoz-otel-collector et customer_service. tests/features contient 6 fichiers .feature, dont customer_temporal_workflows.feature.","url":"file:///home/bfontaine/septeo/septeo_saaster_kit/infra/kong/kong.yml"},
 {"claim":"Affirmation forte du résumé et des points forts : « Python est l'écosystème où les briques agent sont les plus complètes » et « Le SDK openai Python couvre complètement GPT-Live »","verdict":"non-prouvé","preuve":"La couverture API est confirmée. « Complètement » ne l'est pas, faute de test réel contre l'API, et openai-go v3.88 expose les mêmes ressources (live, sideband, fork, decisions). L'avantage réel de Python se limite à A2UI côté agent et à ADK (2.13 contre 1.9). Les chiffres de mémoire par process (« centaines de Mo contre dizaines ») n'ont pas été mesurés.","url":"https://api.github.com/repos/openai/openai-go/contents/live?ref=v3.88.0"}
]
```

## Les 3 corrections les plus importantes pour la proposition

1. **Corriger le conflit de dépendances, qui empêche la stack de s'installer telle quelle.**
   - `temporalio[google-adk]` et `temporalio[openai-agents]` imposent `mcp<2`, alors que la stack prévoit mcp 2.3.
   - Les extras `[openai]`, `[extensions]` et `[all]` de `google-adk` imposent `openai<3`, alors que la stack prévoit openai 3.39, indispensable pour GPT-Live.
   - Deux options pour résoudre le conflit :
     - Option A : n'installer ADK qu'avec ses extras sans contrainte openai, comme `[a2a]` et `[mcp]`, et ne pas utiliser les contribs Temporal ADK et openai-agents (Temporal reste utilisé avec des activités écrites à la main).
     - Option B : séparer le worker Temporal et l'agent GenUI en process ou images distincts.
   - Dans tous les cas, il faut un lockfile `uv` vérifié dès le premier jour de la phase 1. La fenêtre OTel réelle est **1.43–1.44**, pas 1.39–1.44.

2. **Corriger l'adapter Gemini.** `auth_tokens.create` est marqué « [Experimental] » et le SDK indique **v1alpha uniquement**. Il ne faut donc pas viser `v1beta/auth_tokens`. L'adapter doit configurer `http_options=HttpOptions(api_version='v1alpha')` et être couvert par un test de contrat, puisque l'API peut changer.

3. **Revoir l'argument principal en faveur de Python.**
   - Le SDK confirme que le mode `decisions` est un troisième mode réel. Il faut l'évaluer avant de figer `delegation.type=client`, car il peut changer le partage du travail entre le sideband et l'orchestrateur.
   - Pour la délégation `client`, aucun framework Python n'aide : openai-agents ne gère pas GPT-Live, et Pydantic AI rejette explicitement les délégations `client`. Python n'apporte donc que le SDK brut, que openai-go v3.88 possède aussi. Le seul vrai avantage de Python est la couche GenUI : A2UI et ADK.
   - La solution de repli de la phase 1 devrait devenir le plan principal. Le relais SDP, le sideband et l'authentification passent en Go, dans le langage de l'équipe et avec une vraie vérification JWKS. Seul l'agent GenUI reste en Python.
   - Il faut aussi verrouiller A2UI sur **v0.9** côté serveur, et non « v0.9/v1.0 ». Le client Flutter genui 0.10.4 est encore en a2ui_core ^0.1.0, et a2ui-core 0.4 contient aussi V0_9_1 : la version exacte doit être négociée explicitement.

J'ai inspecté les wheels décompressées dans `/tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/4c090190-d378-4c58-84ec-7e52cf30a8ed/scratchpad/wh/`.

### Vérification 5

# Vérification de la stack backend TypeScript (au 2026-10-27)

J'ai vérifié chaque affirmation contre les tarballs npm, les zips du proxy Go, pub.dev et la doc officielle. Trois points de la proposition sont faux, et deux autres sont à nuancer.

## Liste des affirmations

1. **openai 7.45.0 et l'appel `openai.live.sessions.create`**
   - verdict : réfuté (partiellement)
   - preuve : la version et sa date (2026-10-26) sont exactes. En revanche, `client.live.sessions` n'a pas de méthode `create`. La classe `Sessions` expose `accept`, `downloadRecording`, `fork`, `hangup`, `refer` et `reject`. La session WebRTC se crée avec `client.live.create({session:{model:'gpt-live-1'}, transport:{type:'webrtc', sdp}})`, qui fait un POST sur `/live/sessions` (resources/live/live.d.ts:29). Le reste est exact :
     - `SidebandWS` existe dans `resources/live/sideband/ws.d.ts` et s'attache sur `/live/sessions/${id}/attach`.
     - La reconnexion est configurable (`reconnectInitialDelay`, `reconnectMaxDelay`).
     - Les événements `session.delegation.created`, `thinking.append`, `commentary.append`, `close`, `closed`, `input_transcript.delta` et `output_transcript.delta` sont typés.
     - `delegation.type` accepte `'client' | 'responses'`, et `acknowledgement_delay_ms` existe.
     - La limite de 500 tokens figure dans les commentaires du code.
     - `ws ^8.21.0` est une dépendance pair (peer).
   - url : https://registry.npmjs.org/openai

2. **@openai/agents et @openai/agents-realtime 0.21.0, sans support de GPT-Live**
   - verdict : confirmé
   - preuve : publiés le 2026-10-20. Le code de `dist` contient `DEFAULT_OPENAI_REALTIME_MODEL = 'gpt-realtime-2.1'` et utilise seulement les routes `v1/realtime/calls`, `v1/realtime?call_id=` et `v1/realtime?model=`. Il n'y a aucune trace de `/live/sessions` ni de `gpt-live-1` (on trouve seulement `gpt-live-transcribe`).
   - url : https://registry.npmjs.org/@openai/agents-realtime

3. **@openai/agents-core 0.21.0 n'a pas d'OpenTelemetry**
   - verdict : confirmé
   - preuve : ses dépendances sont `@standard-schema/spec`, `debug` et `openai ^7.2.0`. Une recherche de `opentelemetry` ou `gen_ai.` dans `dist` ne trouve rien.
   - url : https://registry.npmjs.org/@openai/agents-core

4. **@google/genai 2.31.0 et `authTokens.create` en v1beta**
   - verdict : confirmé, avec une nuance
   - preuve : version publiée le 2026-10-23. La doc web montre `authTokens.create` avec `uses`, `expireTime`, `newSessionExpireTime` et `liveConnectConstraints` (modèle `gemini-3.8-live`), et indique « only works for the live API, and only with the v1beta version ». Mais la JSDoc de `Tokens.create` dans `node.d.ts` (ligne 16116) dit encore « Support in v1alpha only » et donne `httpOptions:{apiVersion:'v1alpha'}` en exemple. Il faut tester la version d'API réellement acceptée.
   - url : https://ai.google.dev/gemini-api/docs/ephemeral-tokens

5. **MCP TS v2 : @modelcontextprotocol/client, /core et /server 2.4.0, spec 2026-07-28 avec repli vers l'ère 2025**
   - verdict : confirmé
   - preuve : publié le 2026-10-23. Le README dit « stable release line, implementing the 2026-07-28 MCP spec ». Dans le code :
     - `FIRST_MODERN_PROTOCOL_VERSION = "2026-07-28"` ;
     - les versions modernes et les versions 2025 sont négociées séparément (`SUPPORTED_PROTOCOL_VERSIONS` liste les versions 2025-11-25 à 2024-10-07) ;
     - `server/discover`, `input_required`, `StreamableHTTPClientTransport` et `OAuthClientProvider` sont présents.

     De plus, @modelcontextprotocol/sdk 1.32.2 a bien `LATEST_PROTOCOL_VERSION = '2025-11-25'`. Le client dépend de `zod ^4.2.0`.
   - url : https://registry.npmjs.org/@modelcontextprotocol/client

6. **@a2a-js/sdk 1.3.0 : A2A v1.0, trois transports, compatibilité v0.3, stores persistants**
   - verdict : confirmé
   - preuve : publié le 2026-09-29. Le README annonce une « v1.0 stable release » avec JSON-RPC, HTTP+JSON et gRPC (Node). Les exports `./compat/v0_3/*` et `./server/database` existent. Kysely et pg, mysql2 ou better-sqlite3 sont des dépendances pair.
   - url : https://registry.npmjs.org/@a2a-js/sdk

7. **@a2ui/web_core 0.14.0 pour valider l'A2UI côté Node**
   - verdict : réfuté (partiellement)
   - preuve : ce qui est vrai :
     - publié le 2026-10-17 ;
     - `MessageProcessor` est présent dans `src/processing` ;
     - les exports `./v0_9` et `./v1_0` existent ;
     - `lit` n'est importé que dans `src/universal`, la partie qui sert au rendu.

     Ce qui est faux :
     - Ce n'est pas la brique côté agent. Le SDK officiel pour l'agent est **@a2ui/agent 0.0.2** (publié le 2026-10-24, il dépend de `@a2ui/web_core ^0.14.0`). Il cible v0.9 et v1.0 et fournit `A2uiGenerator`, `CatalogConfig.fromPath`, la négociation des capacités du renderer, `promptSnippet` et `parseResponse` avec validation et `A2uiError`.
     - web_core dépend de `zod ^3.25.76`, pas de zod 4.
   - url : https://registry.npmjs.org/@a2ui/agent

8. **AG-UI 1.0.3, middleware A2UI 0.0.13, SDK Go seulement communautaire et sans tag**
   - verdict : confirmé
   - preuve :
     - `@ag-ui/core` et `@ag-ui/encoder` sont en 1.0.3 (2026-10-16).
     - `@ag-ui/a2ui-middleware` 0.0.13 (2026-10-19) a pour dépendances pair `@ag-ui/client >=1.0.0` et `rxjs 7.8.1`.
     - Le SDK Go n'existe que sous `sdks/community/go`, en pseudo-version `v0.0.0-20261026220504`.
   - url : https://registry.npmjs.org/@ag-ui/core

9. **@copilotkit/runtime et @copilotkit/a2ui-renderer 1.80.0**
   - verdict : confirmé pour les versions (2026-10-24)
   - preuve : la conclusion « inutile pour Flutter » est une appréciation, pas un fait vérifiable. Je ne l'ai pas contestée.
   - url : https://registry.npmjs.org/@copilotkit/runtime

10. **Équivalents Go, dont un go-sdk MCP 1.8.0 en support « partiel ou transitoire » de 2026-07-28**
    - verdict : réfuté (pour le MCP Go)
    - preuve : dans le go-sdk v1.8.0 (2026-09-04), `latestProtocolVersion = protocolVersion20260728`. Le tableau du README indique « v1.7.0+ | 2026-07-28 | 2026-07-28, 2025-11-25*, … ». Le seul astérisque concerne l'OAuth côté client, marqué expérimental. `server/discover` et `input_required` sont implémentés. Les autres versions Go sont exactes :
      - openai-go v3.88.0 (2026-10-26) contient `live/live_sideband_websocket_binding.go` et la route `live/sessions/%s/attach` ;
      - a2a-go/v2 v2.7.0 (2026-10-21) ;
      - genai v1.76.0 (2026-10-22) ;
      - adk v1.9.0 (2026-10-15).
    - url : https://proxy.golang.org/github.com/modelcontextprotocol/go-sdk/@latest

11. **Outillage TS : cucumber 13.3.0, testcontainers 12.2.1, temporalio 1.24.0, connect-node 2.2.0, grpc-js 1.14.6, ws 8.22, Fastify 5**
    - verdict : confirmé
    - preuve : toutes ces versions sont les « latest » sur npm. Fastify 5 correspond à la 5.12.7.
    - url : https://registry.npmjs.org/@cucumber/cucumber

12. **« Node.js 24 LTS »**
    - verdict : réfuté (partiellement)
    - preuve : Node 24 est passé en maintenance le 2026-10-20. Node 26 devient Active LTS le 2026-10-28, et la 26.12.1 est déjà sortie.
    - url : https://raw.githubusercontent.com/nodejs/Release/main/schedule.json

13. **GPT-Live n'a pas de client secret, d'où le relais SDP obligatoire**
    - verdict : confirmé (faute de preuve contraire)
    - preuve : `resources/live` ne contient ni `client_secret` ni `ephemeral` (ces notions n'existent que sous `resources/realtime`). Le guide Live demande « a trusted server with an OpenAI project API key. Keep the key on the server ».
    - url : https://developers.openai.com/api/docs/guides/live

14. **Résultats renvoyés par `thinking.append` et `commentary.append`, avec `acknowledgement_delay_ms`**
    - verdict : confirmé
    - preuve : le guide de délégation en mode client documente `session.delegation.created`, `thinking.append`, `commentary.append` et `instructions.append` (avec `delegation_id`) via le sideband, ainsi que `delegation.acknowledgement_delay_ms`. Le SDK n'a aucun événement « delegation.result » dédié.
    - url : https://developers.openai.com/api/docs/guides/live-delegation?delegation-mode=client

15. **« Pas d'équivalent officiel A2UI en Go »**
    - verdict : confirmé
    - preuve : le module `github.com/google/a2ui` (pseudo-version 2026-10-14) ne contient aucun fichier `.go`. Il y a seulement du TypeScript, Python, Dart, Kotlin et Swift. En revanche, les schémas JSON de `specification/v0_9`, `v0_9_1` et `v1_0`, ainsi qu'un dossier `conformance/`, sont publiés. On peut donc valider en Go avec un validateur JSON Schema générique.
    - url : https://github.com/google/A2UI

16. **genui 0.10.4 dépend de `a2ui_core ^0.1`**
    - verdict : confirmé
    - preuve : la dépendance est bien `a2ui_core ^0.1.0`, alors que `a2ui_core` est déjà en 0.3.0 (2026-10-19). Le risque de décalage de version entre Flutter et le serveur est donc réel et plus fort qu'annoncé.
    - url : https://pub.dev/packages/genui

17. **« JSON natif + Zod : un seul système de types »**
    - verdict : réfuté
    - preuve : `@a2ui/web_core` exige `zod ^3.25.76`, tandis que `@modelcontextprotocol/client` et la proposition utilisent zod 4. On aura deux versions majeures de Zod dont les schémas ne sont pas interchangeables.
    - url : https://registry.npmjs.org/@a2ui/web_core

18. **App Check obligatoire pour Firebase AI Logic à partir du 2026-11-02**
    - verdict : non prouvé
    - preuve : je n'ai pas vérifié ce point, qui sort du périmètre des SDK.
    - url : (aucune)

## Les 3 corrections les plus importantes

1. **Corriger l'API GPT-Live.** Il faut remplacer `openai.live.sessions.create` par `client.live.create({session:{model:'gpt-live-1', delegation:{type:'client', acknowledgement_delay_ms}}, transport:{type:'webrtc', sdp}})`. `live.sessions` sert seulement à `accept`, `hangup`, `refer`, `reject`, `fork` et `downloadRecording`. La correction vaut pour le composant Voice Session Gateway, l'étape 4 du plan de la phase 1 et les faux serveurs de test.

2. **Revoir l'argument « MCP 2026-07-28 » en faveur de TS.** Le go-sdk Go 1.7.0 et plus annonce officiellement 2026-07-28 comme spec la plus récente, avec `server/discover` et `input_required`. Seul l'OAuth côté client y est expérimental. L'avantage de TS se réduit donc à A2UI et AG-UI, ce qui renforce l'option tout-Go à évaluer dès l'étape 1. Les passages « go-sdk en transition » dans les forces et les faiblesses sont à supprimer.

3. **Changer la brique de validation A2UI.** Pour l'agent GenUI, il faut utiliser `@a2ui/agent` 0.0.2, le SDK officiel côté agent : génération, négociation de catalogue, `parseResponse` validé. web_core n'est que son moteur interne. Il faut aussi :
   - noter que `@a2ui/agent` en est à 0.0.x, donc très immature ;
   - noter qu'il entraîne zod 3, alors que MCP v2 utilise zod 4 ;
   - aligner explicitement la version du protocole avec genui 0.10.4, qui épingle `a2ui_core ^0.1` alors que la dernière est en 0.3.0.

   En Go, une validation reste possible avec les schémas JSON de `specification/` et la suite `conformance/`.

**Corrections secondaires**
- Passer à Node 26, qui devient LTS le 2026-10-28.
- Tester les jetons Gemini en v1beta et en v1alpha, car la doc et la JSDoc du SDK se contredisent.

Les tarballs et zips inspectés sont dans `/tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/4c090190-d378-4c58-84ec-7e52cf30a8ed/scratchpad/pk` et `/tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/4c090190-d378-4c58-84ec-7e52cf30a8ed/scratchpad/gomods`.

## 3. Jugements (3)

### Lentille : ÉQUIPE & EXPLOITATION : compétences (Flutter + Go), réutilisation du saaster_kit (Keycloak, Kong, Temporal, SigNoz, CI Azure, Godog), nombre de langages, coût d'exploitation, recrutement, testabilité TDD/BDD

**scores**
- **go : 9/10** — C'est la meilleure option sous cette lentille. On garde un seul langage backend, celui que l'équipe maîtrise déjà. L'option réutilise directement l'hexagonal, la façade OTel/SigNoz, l'adapter Temporal, Godog + testcontainers, golang-migrate et Kong. On n'a ni deuxième runtime à opérer ni deuxième astreinte, et le binaire statique reste léger. Les fact-checks confirment presque toutes les affirmations sur les SDK (openai-go live et sideband typé, go-sdk MCP 2026-07-28, a2a-go/v2, googleadk Temporal). Trois points pèsent contre elle, et ils sont mineurs. (1) Les planchers de version annoncés sont faux : Go doit être en 1.26.10 au moins et OTel en v1.47, pas en 1.26.x et v1.45. Le saut de version est donc un peu plus lourd que prévu, ce qui milite pour un module séparé. (2) Le package live d'openai-go a seulement 10 jours. Il faut donc des tests contractuels et épingler les versions. (3) La couche A2UI reste à écrire, ce qui fait du code maison à maintenir. L'affirmation « la CI Azure ne lance aucun test » n'est pas prouvée par ce fact-check, mais un autre fact-check la confirme. Le plan TDD/BDD est le plus concret de toutes les options : faux serveur Live en httptest, serveur MCP in-process.
- **hybrid-go-python : 6/10** — Toute la partie infra et sécurité reste en Go et reprend le kit : Keycloak, Kong, Temporal, SigNoz, Godog. Mais l'option ajoute un deuxième langage pour une équipe qui n'a aucune compétence Python. Il faut alors deux CI, deux piles de dépendances et d'observabilité, plus un contrat A2A interne à versionner et à tester des deux côtés. Le bus factor du côté Python est faible. Son argument « sideband écrit à la main en Go » est réfuté : openai-go fournit SidebandService.Connect. Cela affaiblit encore la justification d'un second langage, réduite à la seule brique A2UI. Le fact-check demande aussi de rouvrir l'option tout-Go. Le surcoût de 2 à 15 ms n'est pas prouvé. Elle a deux atouts : la frontière A2A permet une migration locale vers ADK Go, et elle prévoit un point de décision en fin de phase 1.
- **dart : 5/10** — Le langage est déjà connu de l'équipe Flutter, et c'est ce qui la rend intéressante sous cette lentille : contribution des développeurs Flutter, package ui_contract partagé, meilleur bus factor. En exploitation, en revanche, l'option est faible. Il n'existe pas de SDK Temporal Dart, ce qui oblige à passer par un RPC Go. Les SDK OpenAI et Gemini sont communautaires, maintenus par un seul éditeur. L'OTel Dart n'est pas CNCF. Les frameworks web s'essoufflent. On n'a pas de pile BDD/testcontainers mûre, d'où des tests Godog en boîte noire. Il n'y a pas d'A2A v1.0 en Dart, et le recrutement de développeurs Dart backend est difficile. L'argument central, « même moteur a2ui_core dans l'app et dans le serveur », est réfuté avec les versions actuelles (genui épingle a2ui_core ^0.1). Le nom liveConnectConstraints n'est pas le bon dans l'API REST. Point positif : le risque du spike sideband est plus faible qu'annoncé, car openai_dart type déjà la délégation.
- **python : 4/10** — C'est un nouveau langage pour une équipe Go + Flutter : nouvel outillage (uv, ruff, mypy), nouvelle CI, nouvelle astreinte, et une revue de code moins experte. Python réutilise l'infrastructure du kit (docker-compose, Kong, Temporal, SigNoz) mais aucun de son code, et les BDD passent à pytest-bdd. Le fact-check relève un conflit de dépendances qui empêche d'installer la stack telle qu'elle est écrite : temporalio[google-adk] impose mcp<2, et les extras ADK imposent openai<3. C'est exactement le genre de coût d'exploitation redouté sous cette lentille. La fenêtre OTel réelle est plus étroite qu'annoncé (1.43-1.44), et la version d'API des jetons Gemini est erronée. Le fact-check estime lui-même que le repli « Go pour la voix, Python seulement pour GenUI » devrait devenir le plan principal, ce qui revient à l'option hybride.
- **typescript : 3/10** — C'est un troisième langage, sans aucune compétence dans l'équipe : npm, tsconfig, cucumber-js, génération proto supplémentaire. La chaîne d'approvisionnement npm est large, Node est mono-thread, et le Node 24 annoncé comme LTS est déjà passé en maintenance. Plusieurs affirmations sont réfutées. L'appel live.sessions.create n'existe pas. L'avantage MCP sur Go est faux. Le « système de types Zod unique » est faux, puisque zod 3 et zod 4 cohabitent. La brique A2UI choisie n'est pas la bonne, et la bonne (@a2ui/agent 0.0.2) est très immature. La proposition admet elle-même que l'avantage est étroit et qu'il faut comparer avec une option tout-Go. Le kit n'est réutilisé qu'au niveau de l'infrastructure.

**Gagnant** : go

**Idées à greffer**
- Tirer de Dart et TS : un catalogue A2UI unique (JSON Schema versionné par URI) dans un package de contrat partagé avec l'app Flutter (ui_contract), validé par des tests de conformité des deux côtés (a2ui/conformance), A2UI épinglé en v0.9/v0.9.1 tant que genui 0.10.x dépend de a2ui_core ^0.1.
- Tirer de l'hybride : isoler l'agent GenUI et le routeur derrière un port (out.AgentRuntime), avec une frontière qui pourra devenir A2A plus tard. On pourra ainsi brancher un runtime Python a2ui-agent-sdk si la validation A2UI maison en Go s'avère trop coûteuse, sans toucher au gateway.
- Tirer de l'hybride et de TS : point de décision chiffré en fin de phase 1 (latence délégation → premier commentary.append, coût de maintenance de la couche A2UI maison), mesuré dans SigNoz.
- Tirer de l'hybride et de Python : prérequis de sécurité à traiter dès le jour 0. Remplacer ParseUnverified par une vérification JWKS, ajouter une allowlist d'origines en remplacement du CORS * avec credentials dans Kong, et lancer go test -race et Godog dans azure-pipelines.yml.
- Tirer de Dart : laisser les développeurs Flutter contribuer aux scénarios Gherkin et au catalogue, avec Godog qui pilote le service en boîte noire (faux serveur Live sur WebSocket, Keycloak et Postgres en testcontainers).
- Tirer du fact-check Go : un module agent_orchestrator séparé, avec Go 1.26.10 au moins et OTel v1.47 au moins, pour ne pas imposer ce saut de version à customer_service. Épingler openai-go au-delà de v3.86 (règle MVS face au v3.82 d'ADK). Utiliser Renovate, et des tests contractuels sur fixtures d'événements sideband, avec repli SendRaw/RecvRaw.
- Tirer de TS : désigner au moins deux propriétaires de l'orchestrateur et de la couche A2UI, pour éviter un bus factor faible sur le composant le plus critique.
- Tirer du fact-check hybride : un spike précoce sur le chemin Gemini (jeton auth_tokens v1alpha ou v1beta, ou bien Firebase AI Logic + App Check) avant de figer l'endpoint d'émission de jeton.

### Lentille : Technique temps réel et protocoles. Critères : maturité réelle des SDK d'après les fact-checks, support de GPT-Live (sideband, délégation client) et de Gemini Live, A2A v1.0, MCP 2026-07-28, génération et validation A2UI, latence de la boucle voix → délégation → résultat, concurrence sur des milliers de WebSockets sideband.

**scores**
- **go : 8.5/10** — C'est l'option qui couvre le mieux les protocoles, et le fact-check le confirme. openai-go/v3 fournit le relais SDP (Live.New) et un sideband typé : SidebandService.Connect, Recv/Send, SendRaw/RecvRaw, Reconnect, ainsi que les événements delegation.created, commentary.append et thinking.append (limite de 500 tokens, acknowledgement_delay_ms). Le go-sdk MCP v1.7+ prend en charge la spec 2026-07-28 et en fait sa version la plus récente, avec server/discover et input_required. Seul l'OAuth côté client y est encore expérimental. a2a-go/v2 est officiel pour A2A v1.0, avec trois bindings. Le module genai Go expose Tokens.Create et LiveConnectConstraints, mais le SDK marque ces jetons comme expérimentaux. Pour la concurrence, une goroutine par sideband garantit la meilleure densité et une annulation propre via context, ce qui convient à des milliers de WebSockets. La latence est minimale : un seul process, sans saut entre services. Points faibles : (1) aucun SDK A2UI Go, mais les JSON Schemas v0_9, v0_9_1 et v1_0 et la suite conformance/ permettent une validation solide ; c'est la génération guidée qu'il faut écrire soi-même. (2) Le package live est jeune : les sources divergent, typé depuis le 10/09 selon l'une, événements typés seulement depuis le 17/10 selon l'autre, et le churn est quotidien. (3) Plusieurs planchers étaient faux : Go 1.26.10 et OTel 1.47, pas 1.45. ADK v2 tire openai-go v3.82, qui n'a pas les contrôles de délégation : il faut épingler une version plus récente. (4) MCP 2026-07-28 n'est négocié que si les serveurs sont Stateless=true.
- **hybrid-go-python : 7/10** — La voix (SDP, sideband, quotas, canal app) reste en Go, ce qui hérite de toutes les forces de l'option go. L'outillage A2UI côté agent devient officiel (a2ui-agent-sdk, a2ui-core, ADK). En revanche, l'argument structurant de la proposition est réfuté : elle affirme que le sideband doit être écrit à la main en Go, or openai-go le type. La justification de l'hybride se réduit donc à la seule couche A2UI. Sur la boucle voix, le saut A2A Go→Python s'ajoute à chaque délégation. Son coût de 2 à 15 ms n'est pas mesuré, et il faut aussi convertir les Parts en commentary et thinking, propager CancelTask et traceparent, et valider l'A2UI deux fois. Cela fait plus de pièces mobiles dans le chemin critique de latence et d'annulation sur barge-in. Autres faiblesses : le support de MCP 2026-07-28 par mcp Python 2.3 n'est pas prouvé dans ce fact-check (il l'est dans celui de l'option python). Le chemin Gemini est flou : v1beta contre v1alpha, et rien ne prouve que firebase_ai accepte un jeton éphémère. Les conflits de dépendances Python (google-adk[openai] contre openai 3.x, temporalio contribs avec mcp<2) s'appliquent aussi en partie. La frontière A2A reste propre et réversible.
- **typescript : 6.5/10** — La couverture protocolaire officielle est très bonne. Le SDK openai Node type entièrement le sideband (SidebandWS avec reconnexion), même si la proposition appelle à tort live.sessions.create au lieu de live.create. MCP TS v2 2.4 est la ligne de référence pour 2026-07-28. @a2a-js/sdk 1.3 est en v1.0 avec une compatibilité 0.3. AG-UI est natif. L'event loop de Node est adaptée à de nombreux WebSockets inactifs, mais la copie de l'audio PCM du sideband ou une validation Zod volumineuse peut bloquer tout le process. Côté A2UI, la vraie brique côté agent est @a2ui/agent 0.0.2, très immature. Le fact-check relève aussi un conflit zod 3/zod 4, ce qui réfute l'argument « un seul système de types ». L'argument « go-sdk MCP en transition » est réfuté : l'avantage de TS sur Go se réduit à A2UI et AG-UI. @openai/agents-realtime ne gère pas GPT-Live, donc rien n'est gagné sur la voix. Enfin, la doc et la JSDoc du SDK se contredisent sur la version d'API des jetons Gemini (v1beta ou v1alpha).
- **python : 6/10** — Le SDK openai Python couvre GPT-Live : create, sideband.connect avec reconnexion et SendQueue, événements de délégation. Il expose même le mode decisions. MCP 2.3 (2026-07-28) et a2a-sdk 1.2 (v1.0) sont confirmés, et A2UI côté agent est officiel et le plus mûr (a2ui-agent-sdk 0.9 avec V0_9, V0_9_1 et V1_0). Mais la stack telle qu'elle est écrite ne s'installe pas. temporalio[google-adk] et [openai-agents] imposent mcp<2, et google-adk[openai/extensions/all] impose openai<3, alors que GPT-Live a besoin d'openai 3.x. La fenêtre OTel réelle est 1.43–1.44. Les jetons Gemini sont réservés à v1alpha et expérimentaux selon le SDK, et la proposition visait v1beta. Aucun framework n'aide pour la délégation client : openai-agents ne gère pas GPT-Live et Pydantic AI refuse le mode client. Pour la concurrence, asyncio suffit, mais un appel bloquant ou une validation coûteuse dans la boucle dégrade toutes les sessions du worker, et l'empreinte mémoire par process est plus lourde. Pour la voix, l'option n'apporte rien de plus que Go.
- **dart : 4/10** — openai_dart 11 type bien la délégation et le sideband. Le fact-check revoit ce risque à la baisse, mais il s'agit d'un SDK communautaire maintenu par une seule personne, et la présence de commentary.append dans la doc publique n'est pas confirmée. googleai_dart est lui aussi communautaire, et la proposition nomme mal le champ REST (bidiGenerateContentSetup et non liveConnectConstraints). mcp_dart annonce 2026-07-28, mais c'est une conformité auto-déclarée. Pour A2A v1.0, aucune voie Dart : le package a2a et genui_a2a suivent la forme v0.3, sans auth, avec un serveur bloquant. Il n'existe pas de SDK Temporal ni d'OTel GenAI mature. La « double validation identique » via a2ui_core ne tient pas : genui est verrouillé sur ^0.1 (v0.9 seulement) alors que le serveur proposé est en 0.3 (v1.0 RC). Côté concurrence, l'isolate est mono-thread et la gestion de backpressure du sideband est à construire. La latence ajoute un saut gRPC vers Go pour toute tâche longue.

**Gagnant** : go

**Idées à greffer**
- Isoler GPT-Live derrière out.LiveProvider avec repli SendRaw/RecvRaw. Écrire dès le premier jour des tests de contrat sur des fixtures d'événements sideband enregistrées (idée commune à tous les fact-checks). Épingler openai-go au-dessus de la v3.82 tirée par ADK, ou se passer d'ADK.
- Évaluer le troisième mode de délégation 'decisions' (présent dans openai Python et dans openai-go via decisions_contract_test.go) avant de figer delegation.type=client (fact-check Python).
- Fixer l'A2UI côté serveur sur v0.9 ou v0.9.1, aligné sur genui 0.10.4 (a2ui_core ^0.1). La v1.0 n'est qu'un RC. Valider avec les schémas specification/ et la suite conformance/ du dépôt a2ui (fact-checks Dart et TS).
- Porter en Go les bonnes idées d'a2ui-agent-sdk et de @a2ui/agent : élagage du catalogue (ComponentPruningTransformer), extrait de prompt généré depuis le catalogue, négociation des supportedCatalogIds du renderer, parse et validation, puis régénération bornée.
- Garder en réserve la frontière A2A de l'option hybride : si la génération A2UI en Go s'avère trop coûteuse, déporter seulement l'agent GenUI en sidecar Python derrière a2a-go/v2, sans toucher au gateway.
- Faire un spike Gemini avant la phase 1 : vérifier la version d'API des jetons (v1alpha selon les SDK, v1beta selon la doc), le nommage REST bidiGenerateContentSetup/fieldMask contre liveConnectConstraints dans le SDK, et si firebase_ai accepte un jeton auth_tokens, ou bien adopter App Check.
- Gérer le fait que tout thinking.append ou commentary.append annule tous les accusés automatiques en attente de la session, y compris ceux des autres délégations. Il faut donc ordonner les délégations concurrentes (fact-check hybride).
- Exiger StreamableHTTPOptions.Stateless=true sur les serveurs MCP métier (dont customer_service exposé en MCP) pour réellement négocier 2026-07-28. Sinon le gateway doit gérer les sessions 2025-11-25.
- Instrumenter et mesurer la latence délégation → premier commentary.append. Mettre en place un lease d'ownership de la session sideband (Postgres advisory lock) et un drain au redéploiement. Ignorer ou ne pas décoder l'audio PCM du sideband pour préserver la densité.

### Lentille : RISQUE & ÉVOLUTIVITÉ : sécurité (secrets, injection de prompt, validation A2UI), dépendance à des bibliothèques alpha ou communautaires, vitesse d'adoption des nouveautés IA, réversibilité, phase 2 (A2A, AG-UI, agents tiers)

**scores**
- **hybrid-go-python : 8/10** — C'est l'option la plus solide sous cette lentille. Sécurité : le gateway Go est le seul point d'entrée. Il porte l'auth JWKS, les quotas, le CORS restreint et l'audit. Le service Python n'est jamais exposé, et l'A2UI est validée deux fois, en Python avec a2ui-agent-sdk puis en Go par JSON Schema, ce que recommande la note genui-a2ui-security. Vitesse d'adoption : la couche qui bouge le plus (ADK, A2UI, prompts) reste dans l'écosystème Python où les nouveautés arrivent en premier, et elle se déploie seule. Réversibilité : la frontière A2A v1.0 s'appuie sur des SDK officiels des deux côtés, ce qui permet de remplacer le runtime Python par ADK Go sans toucher au gateway (étape 9). Phase 2 : A2A est déjà le contrat interne. Effet de bord favorable : le service Python n'a pas besoin d'openai 3.x puisque le sideband est en Go, donc il évite le conflit google-adk/openai<3 que le fact-check relève dans l'option Python. Ce qui pèse contre elle : 1) l'affirmation « sideband écrit à la main en Go » est réfutée ; corrigée, elle réduit en fait le risque. 2) Le support MCP 2026-07-28 par mcp 2.3 est non prouvé selon ce fact-check. 3) L'acceptation d'un jeton éphémère par firebase_ai est non prouvée. 4) Le surcoût de 2 à 15 ms n'a pas été mesuré. 5) Il faut propager l'identité à travers la frontière (token exchange) et éviter la dérive du contrat. 6) Deux langages : le bus factor est faible sur Python.
- **go : 7/10** — Points forts : SDK officiels pour tous les protocoles (openai-go live et sideband typés, MCP go-sdk 2026-07-28, a2a-go/v2 v1.0, genai), un seul runtime, peu de surface de supply chain, des ports hexagonaux qui isolent LiveProvider. L'option corrige explicitement ParseUnverified. Les faiblesses tombent toutes dans cette lentille. 1) Il n'y a pas de SDK A2UI Go : la validation est maison, et la synchronisation des schémas v0.9/v1.0 reste à notre charge. C'est un risque de sécurité si le schéma dérive. 2) Les nouveautés IA (ADK, A2UI, AG-UI, dont le SDK Go est seulement communautaire) arrivent en retard en Go. 3) Le package live a dix jours. Le fact-check réfute « de bout en bout stable » et corrige des seuils de version (Go 1.26.10, OTel 1.47). Il signale aussi le piège MVS : ADK tire openai-go v3.82, antérieur aux contrôles de délégation. Réversibilité correcte, mais tout revirement vers Python ou TS impliquerait de réécrire l'orchestrateur.
- **python : 6/10** — C'est l'adoption des nouveautés IA la plus rapide : A2UI agent SDK officiel avec validate_payload, ADK 2.13, AG-UI, A2A 1.0. La phase 2 est bien couverte. Mais le fact-check réfute que la stack s'installe telle quelle : temporalio[google-adk] impose mcp<2, google-adk[openai] impose openai<3 alors que GPT-Live demande openai 3.39, et la fenêtre OTel réelle est 1.43–1.44. L'adapter Gemini vise aussi la mauvaise version d'API (v1alpha, et non v1beta). Plusieurs briques critiques sont avant la 1.0 (a2ui-adk 0.1, a2ui-agent-sdk 0.9). Toute la surface exposée (relais SDP payant, sideband, auth) tourne dans un langage que l'équipe maîtrise mal, ce qui augmente le risque de sécurité opérationnelle. Le proposant reconnaît lui-même que le repli vers Go est sans doute préférable.
- **typescript : 5/10** — Bon écosystème officiel : MCP v2 2026-07-28, @a2a-js/sdk 1.0, AG-UI natif, openai Node avec SidebandWS. Mais plusieurs affirmations sont réfutées. 1) L'appel GPT-Live live.sessions.create n'existe pas. 2) Le brique A2UI choisie n'est pas la bonne : le vrai SDK côté agent est @a2ui/agent 0.0.2, très immature. 3) L'argument « un seul système de types Zod » est faux (zod 3 et zod 4 cohabitent). 4) L'avantage MCP sur Go est réfuté. 5) Node 24 n'est plus LTS active. S'y ajoutent une supply chain npm large et un troisième langage pour l'équipe, donc une réversibilité et une maintenance plus coûteuses. L'avantage réel se limite à AG-UI.
- **dart : 3/10** — Risque le plus élevé. Les SDK OpenAI et Gemini sont communautaires et tenus par un seul mainteneur (davidmiguel.com). Il n'y a pas de SDK A2A v1.0 : le package a2a est en v0.3, sans auth, avec un serveur bloquant, et genui_a2a est aussi en v0.3. Pas de SDK Temporal, pas de framework d'agents, une OTel immature. L'argument principal, « même moteur a2ui_core dans l'app et dans le serveur », est réfuté : genui épingle a2ui_core ^0.1, qui n'accepte que v0.9, et la v1.0 n'est qu'une release candidate. Le champ des jetons Gemini est mal nommé : bidiGenerateContentSetup en REST. La phase 2 (A2A, agents tiers) est quasiment bloquée. Seul point favorable : le risque du spike sideband est plus faible qu'annoncé, puisque openai_dart type déjà la délégation.

**Gagnant** : hybrid-go-python

**Idées à greffer**
- Depuis go : utiliser le sideband typé d'openai-go/v3 (SidebandService.Connect, et SendRaw/RecvRaw en repli) au lieu de coder/websocket écrit à la main. Ajouter des tests contractuels sur des fixtures d'événements Live dès le premier jour, et un faux serveur Live (httptest + WebSocket).
- Depuis go : épingler explicitement openai-go à une version au moins égale à v3.86/v3.88, car avec MVS une dépendance ADK Go qui tire v3.82 ne doit pas l'emporter. Fixer les planchers Go à 1.26.10 et OTel à 1.47 dans un module voice_gateway séparé, mettre en place Renovate, et ajouter un lease d'ownership Postgres par session sideband avec Reconnect.
- Depuis go : activer StreamableHTTPOptions.Stateless=true sur chaque serveur MCP métier en Go, y compris customer_service, sinon la négociation redescend en 2025-11-25. Sinon, gérer les deux versions dans la gateway.
- Depuis python : évaluer le troisième mode de délégation `decisions` (confirmé dans les SDK) avant de figer delegation.type=client. Faire un spike Gemini auth_tokens qui teste v1alpha et v1beta, puisque les SDK disent v1alpha et la doc v1beta. Utiliser un lockfile uv vérifié dès le premier jour.
- Depuis python (fact-check) : dans agents-runtime, ne pas installer google-adk[openai] ni les contribs temporalio[google-adk]/[openai-agents], qui imposent openai<3 et mcp<2. Utiliser les extras [a2a] et [mcp] seulement, et écrire les activités Temporal Python à la main.
- Depuis dart : créer un package ui_contract qui sert de source unique. Il contient le catalogue métier en JSON Schema versionné par URI, l'enveloppe du canal WebSocket et les ids de délégation. Figer A2UI à v0.9 tant que genui épingle a2ui_core ^0.1.
- Depuis dart : écrire les scénarios Gherkin de l'orchestrateur en Godog, en boîte noire contre le conteneur Python, pour garder un seul runner BDD dans une équipe Go.
- Depuis typescript, python et la note genui-a2ui-security : dans la seconde validation Go, ajouter une allowlist https et domaines pour openUrl, Image et Video, refuser tout secret dans le data model, et confirmer les actions sensibles hors GenUI.
- Depuis le fact-check hybride : tenir compte du fait que tout thinking.append ou commentary.append annule tous les accusés automatiques en attente de la session. Il faut donc ordonner les envois du DelegationBroker quand plusieurs délégations tournent en parallèle, et propager CancelTask avant d'annoncer une annulation.
- Depuis python et typescript : remplacer le CORS Kong origins * avec credentials:true par une allowlist d'origines sur la route du relais SDP, en plus de la vérification JWKS (iss, aud, exp).

## 4. Synthèse (1)

**Proposition à valider : le backend orchestrateur en Go**

**Stack recommandée.** Je propose un nouveau module `backend/agent_orchestrator` dans le saaster kit, avec la même architecture hexagonale que `customer_service`. Il demande Go ≥ 1.26.10 (exigé par adk/v2) et OTel ≥ v1.47. En faire un module séparé évite d'imposer ce saut de version à `customer_service`.
- **Voix :** `openai-go/v3` épinglé à v3.86 ou plus (`Live.New` pour le relais SDP, `Live.Sideband.Connect` pour le sideband typé) et `genai` (`AuthTokens.Create`).
- **Outils :** MCP go-sdk v1.8, a2a-go/v2 en phase 2, ADK Go v2 en option.
- **A2UI :** il n'existe pas de SDK Go. On écrit une couche maison : un catalogue en JSON Schema, une validation avec `jsonschema-go` et les tests de `conformance/`, avec A2UI épinglé en v0.9.
- **Socle :** Temporal v1.50, Postgres, Keycloak avec vérification des JWT par JWKS, SigNoz, Kong.

**Services, regroupés dans un seul déployable :** `voice-session`, `sideband-supervisor`, `orchestrator` (routeur déterministe d'abord, LLM en repli), un agent GenUI derrière un port `out.AgentRuntime`, `mcp-gateway`, `app-channel` (WebSocket), et des workflows Temporal pour les tâches longues.

**Pourquoi Go.**
- L'équipe n'a qu'un langage backend, celui qu'elle maîtrise déjà.
- Les SDK officiels Go couvrent toute la partie temps réel : GPT-Live, MCP 2026-07-28, A2A v1.0 et les jetons Gemini.
- Une goroutine par sideband, sans saut réseau dans la boucle vocale.
- **Idée reprise de l'option hybride :** si la couche A2UI maison coûte trop, on remplace l'implémentation de `out.AgentRuntime` par un sidecar Python (`a2ui-agent-sdk`) appelé en A2A, sans toucher au reste du backend.

**Classement** (somme des trois juges : équipe, temps réel, risque) :

| Rang | Option | Scores | Total /30 |
|---|---|---|---|
| 1 | Go | 9 / 8,5 / 7 | 24,5 |
| 2 | Hybride Go + Python | 6 / 7 / 8 | 21 |
| 3 | Python | 4 / 6 / 6 | 16 |
| 4 | TypeScript | 3 / 6,5 / 5 | 14,5 |
| 5 | Dart | 5 / 4 / 3 | 12 |

Les juges ne sont pas d'accord sur un point : le juge « risque » préfère l'hybride. Ses raisons : l'outillage A2UI côté agent est officiel en Python, la double validation est native et la frontière A2A est réversible. Les deux autres juges retiennent Go. Ils notent aussi que l'argument central de l'hybride (« le sideband serait à écrire à la main en Go ») est faux : `SidebandService.Connect` existe dans openai-go.

**Les 3 principaux risques**
1. **Sécurité copiée du kit :** `server.go:137` décode les JWT avec `ParseUnverified` (signature jamais vérifiée), et Kong accepte toutes les origines (`cors *`) avec credentials. Recopié tel quel, le relais SDP peut faire dépenser le quota OpenAI à n'importe qui. À corriger dès le jour 0.
2. **Package `live` d'openai-go très jeune,** avec des releases presque quotidiennes. Il faut l'isoler derrière un port `out.LiveProvider`, garder `SendRaw`/`RecvRaw` en repli et écrire des tests de contrat sur des fixtures d'événements.
3. **Affinité de session :** la connexion sideband vit sur un seul pod. Sans verrou de propriété (lease Postgres), `Reconnect` et arrêt propre au redéploiement, des délégations seront perdues ou traitées deux fois.

**Non prouvé, à lever par des spikes**
- **Jetons Gemini :** les SDK disent v1alpha, la doc dit v1beta. Le champ REST s'appelle `bidiGenerateContentSetup`, pas `liveConnectConstraints`.
- **firebase_ai :** rien ne montre qu'il accepte un jeton éphémère. Sinon, il faudra passer par App Check.
- **Mode de délégation `decisions` :** les SDK exposent ce troisième mode, à comparer à `client` avant de figer le choix.
- **Latences :** aucune n'a été mesurée.
- **Couche A2UI en Go :** son coût réel est inconnu.
- **Date d'arrivée du sideband typé dans openai-go :** les deux fact-checks se contredisent (2026-09-10 ou 2026-10-17).

**Fichiers écrits** (je n'ai modifié aucune note existante)
- `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/stack-options.md`
- `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/stack-recommendation.md`
- `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/phase1-plan.md` (plan sorti de la recommandation, 13 étapes numérotées 0 à 12)
- `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-landscape.md` (la matrice) et une note par langage, car le tout dépassait 60 lignes :
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-go.md`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-python.md`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-typescript.md`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-dart.md`
- `/home/bfontaine/github/ai_voice_ui/knowledge/projects/saaster-kit/backend.md`
- Index mis à jour :
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/index.yaml`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/projects/index.yaml`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/index.yaml` : tâche « Concevoir / faire évoluer le backend orchestrateur » et mots-clés « backend, go »
  - `/home/bfontaine/github/ai_voice_ui/knowledge/tags.yaml` : régénéré

J'avais aussi ajouté un entrypoint vers la recommandation, mais je l'ai retiré : le lint en limite le nombre à 15. La nouvelle tâche y mène déjà.

**Sortie du lint**
```
kb_lint : 193 notes, 11 index de domaine, 342 tags, 0 erreur(s), 0 avertissement(s)
```
