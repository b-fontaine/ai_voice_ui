# Archive brute — évaluation Rust (2026-10-27)

Sorties intégrales des agents du workflow backend-rust-eval (run wf_188a0103-0fc) : 1 proposition Rust, 2 vérifications adverses, 3 jugements (2 scénarios de compétences), 1 synthèse. Document d'archive, non relu : la référence est adr-0003-backend-go.

## 1. Propositions (1)

### rust

Avis honnête sur Rust (vérifié le 2026-10-27, sur les dépôts et crates publiés). Rust est une option sérieuse pour ce backend, plus que ne le laissait penser l'évaluation précédente qui ne l'avait pas étudié. Les SDK officiels Rust couvrent bien les protocoles : rmcp 3.8.0 (dépôt modelcontextprotocol, spec 2026-07-28, OAuth 2.1 complet), A2A v1 (a2aproject/a2a-rs, crates a2a-lf 0.4.2, encore en 0.x), Temporal (temporalio-sdk, GA en 1.0.0 le 2026-09-04, aujourd'hui 1.1.0) et OTel (opentelemetry 0.33, constantes gen_ai présentes). Le socle (tokio, axum 0.8.9, tokio-tungstenite 0.30, jsonwebtoken 11.1 avec JWK, jsonschema 0.60) est mûr. Le vrai trou se trouve exactement là où le projet est le plus sensible : il n'existe AUCUN SDK OpenAI officiel en Rust (la page Libraries d'OpenAI ne cite qu'async-openai, communautaire). async-openai 0.42.2 ne couvre que l'ancienne API /realtime (calls, client_secrets) : ni /v1/live/sessions, ni sideband /attach, ni délégation. Il n'existe pas non plus de SDK Gemini officiel en Rust (google-cloud-rust ne couvre que Vertex aiplatform, sans auth_tokens), pas de SDK A2UI agent en Rust (le dépôt a2ui contient dart, kotlin, python, swift et typescript) et pas d'ADK Google en Rust (adk-rust est un projet communautaire de zavora-ai). Il faut donc écrire à la main le relais SDP et un client sideband typé, en s'appuyant sur le spec OpenAPI officiel, qui contient bien les schémas Live*. C'est sur l'API la plus jeune et la plus mouvante (openai-go livre presque chaque jour, avec un changement cassant en v3.86) que Rust perd l'avantage décisif de Go. Mon avis : Rust seul est faisable si l'équipe maîtrise déjà Rust (non confirmé, comme Go d'ailleurs). Il coûte environ 4 à 7 semaines-personne de plomberie en plus de Go, puis une maintenance continue du client Live. La variante la plus défendable est une passerelle voix en Rust, ou un tout-Rust avec un client Live généré depuis l'OpenAPI et isolé derrière un port. Il faut dans tous les cas un spike de 1 à 2 semaines avant de décider.

**Composants**
- voice-session (relais SDP + jetons Gemini) — POST /voice/sessions : relaie l'offre SDP vers POST /v1/live/sessions (clé projet serveur) et renvoie la réponse SDP ; crée les jetons Gemini éphémères via POST v1beta/auth_tokens ; quotas par utilisateur (axum 0.8 + reqwest ; client OpenAI Live maison (types générés depuis openai-openapi : LiveSidebandServerEvent/ClientEvent) ; client REST auth_tokens maison)
- sideband-supervisor — Une tâche tokio par session : WSS /v1/live/sessions/{id}/attach, tampon des transcripts, réception de session.delegation.created, envoi de commentary/thinking.append (500 tokens max), response.item.create + response.create, lease Postgres, reconnexion et drain (tokio-tungstenite 0.30 + serde (enums taggés générés) ; sqlx pour le lease)
- orchestrator / routeur — Outil vocal delegate vers routeur LLM ou règles, puis choix de l'agent ; un seul propriétaire par delegation.id ; annulation (Rust pur (traits = ports hexagonaux) ; éventuellement rig-core 0.45 ou async-openai (Responses) pour les appels LLM)
- genui-agent (port AgentRuntime) — LLM qui produit des messages A2UI v0.9/v0.9.1, validés contre le catalogue JSON Schema et assainis (URL, tailles) avant envoi (crate jsonschema 0.60 + schémas a2ui specification/v0_9_1 + suite conformance/ ; option : sidecar Python a2ui-agent-sdk joint en A2A (a2a-client-lf))
- mcp-gateway — Client MCP Streamable HTTP vers les serveurs métier, OAuth 2.1 (PRM, CIMD, refresh), négociation 2026-07-28 (rmcp 3.8.0 (features auth, transport-streamable-http-client-reqwest))
- a2a (phase 2) — Appeler ou exposer des agents A2A v1.0 (JSON-RPC, REST, gRPC, SSE) (a2a-lf 0.4.2 / a2a-client-lf 0.2.9 / a2a-server-lf 0.5.3 (axum, tonic))
- app-channel — WSS ou SSE vers l'app Flutter : flux A2UI, actions utilisateur, état des délégations (axum WebSocket / axum::response::Sse)
- auth — Vérifier les JWT Keycloak par JWKS (cache et rotation des kid), audience et rôles ; CORS strict (jsonwebtoken 11.1 (module jwk) + cache maison, ou openidconnect 4.0.1 ; tower-http CORS)
- long-running — Tâches longues et durables, chaque appel LLM ou outil long devient une Activity (temporalio-sdk 1.1.0 (GA) ou worker Go existant appelé par task queue (Temporal est polyglotte))
- observabilité — Spans OTel GenAI (gen_ai.*) vers SigNoz, propagation du contexte jusqu'au sideband et à MCP (opentelemetry 0.33 + opentelemetry-otlp + tracing-opentelemetry ; constantes opentelemetry-semantic-conventions)

**Affirmations SDK**
- GPT-Live relay : Aucun SDK OpenAI officiel en Rust : la liste officielle compte JS/TS, Python, .NET, Ruby, Java (bêta) et Go (bêta) ; Rust n'apparaît qu'en communautaire (async-openai, non vérifié par OpenAI). — https://developers.openai.com/api/docs/libraries
- GPT-Live relay : async-openai 0.42.2 (2026-10-10, communautaire) : le module realtime.rs ne couvre que /realtime/calls (create, accept, hangup, refer, reject) et /realtime/client_secrets ; rien sur /v1/live/sessions, et zéro occurrence de « delegation » dans le dépôt. — https://github.com/64bit/async-openai/blob/main/async-openai/src/realtime.rs
- GPT-Live sideband : Le spec OpenAPI officiel décrit /live/sessions (et accept, fork, hangup, refer, reject, content) ainsi que les schémas LiveSidebandClientEvent, LiveSidebandServerEvent, LiveDelegationCreated et LiveClientDelegationParam (188 schémas Live*). On peut donc générer les types Rust plutôt que les écrire. — https://github.com/openai/openai-openapi/blob/main/openapi.yaml
- GPT-Live sideband : Comparaison : le package live d'openai-go pèse environ 550 Ko de code (live.go 338 Ko, sideband.go 46 Ko, transcript*.go) avec des tests de contrat. Cela donne l'ordre de grandeur de ce qu'il faudrait reproduire ou générer en Rust. — https://github.com/openai/openai-go/tree/main/live
- Gemini tokens : Les jetons éphémères se créent par POST https://generativelanguage.googleapis.com/v1beta/auth_tokens (v1beta seulement), avec uses, expireTime, newSessionExpireTime et liveConnectConstraints. La doc montre Python, JS et curl, pas Rust. — https://ai.google.dev/gemini-api/docs/ephemeral-tokens
- Gemini tokens : Pas de SDK Gemini Developer API officiel en Rust. google-cloud-rust (officiel) publie google-cloud-aiplatform-v1 1.18.0 (Vertex), sans auth_tokens. Les crates gemini-rust 2.1.0, gemini-live 0.1.9 et genai 0.7.1 sont communautaires ; gemini-rust n'a aucune occurrence d'auth_tokens. — https://crates.io/crates/google-cloud-aiplatform-v1
- MCP : rmcp 3.8.0 (2026-10-26), SDK Rust officiel : implémente la spec stable 2026-07-28 (server discovery, tasks, multi-round-trip, en-têtes de routage HTTP) et reste compatible 2025-11-25. — https://github.com/modelcontextprotocol/rust-sdk
- MCP : OAuth client de rmcp (feature auth) : OAuth 2.1 avec PKCE, RFC 8707, PRM (RFC 9728), métadonnées AS (RFC 8414 et OIDC), DCR, CIMD, montée de scope sur 403 et refresh automatique. — https://github.com/modelcontextprotocol/rust-sdk/blob/main/docs/OAUTH_SUPPORT.md
- A2A : SDK A2A Rust officiel a2aproject/a2a-rs pour « A2A v1 protocol » : JSON-RPC, REST, gRPC (tonic), SLIMRPC et SSE, serveur sur axum. Crates a2a-lf 0.4.2, a2a-client-lf 0.2.9 et a2a-server-lf 0.5.3 (2026-10-16), encore en 0.x, MSRV 1.85. — https://github.com/a2aproject/a2a-rs
- A2UI : Le dépôt officiel a2ui-project/a2ui contient dart, kotlin, python, swift et typescript, mais pas de Rust. Les schémas specification/v0_9, v0_9_1, v1_0 et conformance/ sont publiés et utilisables pour valider. — https://github.com/a2ui-project/a2ui
- A2UI : adk-rust 2.3.0 (zavora-ai, communautaire, pas Google) déclare un profil a2ui « draft-compatible A2UI v0.9 » (createSurface, updateComponents, v0.9.1) ; rmcp 3.1 est intégré. Il ne gère pas GPT-Live /live (0 occurrence de live/sessions). — https://github.com/zavora-ai/adk-rust
- Temporal : Temporal Rust SDK GA : v1.0.0 le 2026-09-04 (« now considered stable »), v1.1.0 le 2026-10-06. Macros #[activities] et #[activity]. — https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0
- OTel : opentelemetry-rust 0.33.1 : Logs et Metrics sont Stable, Traces API/SDK encore Beta, Context Beta. opentelemetry-semantic-conventions contient GEN_AI_OPERATION_NAME (dans trace.rs). — https://github.com/open-telemetry/opentelemetry-rust
- WebSocket/HTTP : Socle mûr : axum 0.8.9, tokio-tungstenite 0.30.0 (2026-07-11), reqwest, plus de 300 M téléchargements chacun. — https://crates.io/crates/tokio-tungstenite
- Keycloak/JWKS : jsonwebtoken 11.1.0 (2026-09-16) sait décoder avec une JWK (module jwk) ; le cache et la rotation JWKS restent à écrire. openidconnect 4.0.1 (2025-07-06) assure la découverte OIDC. — https://crates.io/crates/jsonwebtoken
- autre : Frameworks d'agents Rust, tous communautaires : rig-core 0.45.0 stable (0.46.0-rc.1 le 2026-10-23, environ 9 000 étoiles) ; adk-rust 2.3.0. Il n'existe ni ADK Google ni OpenAI Agents SDK en Rust. — https://github.com/0xPlaygrounds/rig
- autre : jsonschema 0.60.2 (2026-10-26) valide des documents JSON Schema 2020-12 ; il sert à la validation A2UI contre le catalogue. — https://crates.io/crates/jsonschema

**Forces**
- Les protocoles sont couverts par des SDK officiels : MCP (rmcp 3.8, spec 2026-07-28, OAuth le plus complet de l'écosystème), A2A v1 (a2aproject/a2a-rs, avec gRPC et SSE) et Temporal (GA depuis le 2026-09-04).
- Fiabilité des connexions longues : une tâche tokio par sideband, une mémoire et une latence prévisibles sans GC, et l'annulation structurée (CancellationToken, select!) se prête bien à l'interruption vocale et à l'annulation des délégations.
- Le typage fort par enums serde taggés rend exhaustive la gestion des événements sideband : le compilateur force à traiter chaque variante. C'est un atout réel sur un protocole à états (un seul propriétaire par delegation.id).
- Le spec OpenAPI officiel contient les schémas Live et sideband : un client généré est possible, ce qui réduit l'écart avec un SDK officiel.
- Le socle web et WebSocket (axum, tower, tokio-tungstenite, reqwest, sqlx) est très mûr et performant, et il fournit un binaire statique avec une petite image Docker.
- Mêmes trous que Go côté A2UI : Rust ne perd rien sur ce point, puisque seul Python a un SDK agent mûr.
- Temporal est polyglotte : un worker Rust peut cohabiter avec les workflows Go existants du kit via des task queues séparées.

**Faiblesses**
- Pas de SDK OpenAI officiel en Rust, et async-openai ne gère pas /v1/live : le relais SDP, le sideband et la délégation, c'est-à-dire le cœur du produit, sont à écrire et à maintenir à la main sur l'API la plus instable du projet.
- Pas de SDK Gemini officiel (Developer API) en Rust, auth_tokens compris (simple, mais à maintenir, et l'API reste en v1beta).
- Pas d'ADK ni d'OpenAI Agents SDK en Rust : les frameworks (rig, adk-rust) sont communautaires, avec un bus factor et des versions 0.x ou des RC.
- A2A Rust en 0.x (a2a-lf 0.4.2) : le protocole est v1, mais l'API Rust n'est pas stabilisée, contrairement à a2a-go/v2.
- Traces OTel Rust encore Beta, et opentelemetry reste en 0.x avec des montées de version cassantes fréquentes.
- Aucune réutilisation du saaster kit Go (code, tests Godog, adaptateurs) : on ajoute un 2ᵉ langage backend, ou un 3ᵉ avec Dart, si le kit reste en Go.
- Vélocité : compilation plus lente et courbe d'apprentissage async plus raide. Les gains de performance de Rust ne pèsent guère ici, car le goulot est la latence LLM et réseau, pas le CPU.
- Sur les événements Live, les retours d'information viennent d'abord des SDK officiels (Go, Python, TS) : en Rust, on découvre les changements cassants plus tard.

**Trous à coder**
- Client GPT-Live, partie relais : POST /v1/live/sessions (offre SDP vers réponse SDP, Transport.Sdp), plus hangup, accept et reject. Environ 2 à 3 jours, ou 1 jour en générant le client avec progenitor sur le sous-ensemble /live de l'OpenAPI.
- Client GPT-Live, partie sideband typée : connexion WSS /attach (Bearer, même projet), enums serde taggés pour LiveSidebandServerEvent et ClientEvent (types générés par typify depuis l'OpenAPI, puis retouches), Reconnect, Abort, close/closed, tampon input/output_transcript.delta, gestion des événements inconnus (variante Unknown), plafond de 500 tokens et accusés automatiques. Environ 6 à 10 jours au départ, puis une maintenance récurrente de l'ordre d'une demi-journée à une journée par mois : l'API bouge très vite, avec un mode decisions et des changements cassants en octobre 2026.
- Tests de contrat sur des fixtures d'événements Live, enregistrées en réel et comparées aux tests d'openai-go : environ 2 à 3 jours.
- Jetons Gemini éphémères : appel REST v1beta/auth_tokens avec liveConnectConstraints. Environ 0,5 à 1 jour ; il faut aussi vérifier que firebase_ai accepte ces jetons, sinon passer par App Check (le même spike que pour Go).
- Couche A2UI agent : chargement du catalogue, validation jsonschema, assainissement (URL d'images, tailles, profondeur), boucle LLM de réparation en cas d'erreur de validation, exécution de conformance/. Environ 5 à 8 jours, comme en Go, car aucun langage sauf Python n'a de SDK agent mûr.
- Appels LLM pour le routeur et GenUI : la Responses API OpenAI via async-openai (communautaire) ou rig. Environ 1 à 2 jours, plus le risque de suivre une crate non officielle.
- Auth Keycloak : cache JWKS avec rotation des kid et refetch sur kid inconnu, middleware tower pour l'audience, les rôles et le tenant ; corriger au passage le ParseUnverified et le CORS * de l'existant. Environ 1,5 à 2 jours.
- OTel GenAI : spans manuels gen_ai.* via tracing plus opentelemetry, propagation dans les tâches sideband et dans rmcp. Environ 2 à 3 jours, avec un risque lié au statut Beta des Traces.
- Lease et affinité de session (Postgres via sqlx), drain au redéploiement, reprise de délégation : environ 3 à 4 jours. Ce coût est le même dans tous les langages.
- Réintégration au saaster kit : aucune réutilisation du code Go (hexagonal, adaptateurs OTel et Temporal, BDD Godog). Il faut une nouvelle CI cargo, une nouvelle image Docker et des tests BDD (cucumber-rs plus testcontainers-rs). Environ 3 à 5 jours.
- Montée en compétence Rust (async, lifetimes, Send/Sync dans tokio) si l'équipe ne pratique pas le langage : non chiffrable sans connaître l'équipe, probablement plusieurs semaines avant une productivité correcte. C'est le facteur dominant.
- Total indicatif de plomberie en plus d'une stack Go avec SDK officiels : environ 4 à 7 semaines-personne, hors apprentissage.

**Variantes**
- Rust seul : orchestrateur complet en Rust (axum, tokio, rmcp, a2a-lf, temporalio-sdk, client Live généré depuis l'OpenAPI derrière un trait LiveProvider). Pertinent seulement si l'équipe maîtrise déjà Rust et accepte de maintenir le client GPT-Live. C'est le coût le plus élevé, pour une homogénéité maximale côté backend IA.
- Passerelle voix en Rust, avec le reste en Go (kit existant) : Rust gère le relais SDP, les jetons Gemini, le supervisor sideband et le canal WebSocket vers l'app, puis appelle par gRPC (tonic) un orchestrateur Go qui garde MCP go-sdk, Temporal, ADK Go et A2UI. Cela isole la partie la plus sensible aux connexions longues, mais c'est justement celle où Go a le SDK officiel et Rust non : l'intérêt est discutable sauf exigence forte de performance ou de sûreté.
- Rust (orchestrateur et protocoles) avec un sidecar Python pour GenUI : la plomberie et MCP/A2A en Rust, l'agent GenUI en Python avec a2ui-agent-sdk 0.9 et ADK, joint en A2A v1 (a2a-client-lf vers a2a-sdk Python). Cela supprime le trou A2UI, mais il faut tenir trois langages en comptant Dart.
- Rust en option ultérieure, derrière le port AgentRuntime/LiveProvider : démarrer dans la stack retenue et ne réécrire en Rust qu'un composant mesuré comme goulot (par exemple le supervisor sideband) une fois les latences mesurées. Le risque est le plus faible, et la décision repose sur des données.
- Spike préalable recommandé dans tous les cas (1 à 2 semaines) : générer avec typify les types Live depuis openapi.yaml, connecter un sideband réel, traiter une délégation de bout en bout, puis appeler un serveur MCP rmcp sans état. Ce spike mesure le vrai coût du trou OpenAI avant tout engagement.

**Intégration saaster kit** : Faible côté code, bon côté infrastructure. Le backend existant (/home/bfontaine/septeo/septeo_saaster_kit/backend/customer_service) est en Go hexagonal : aucun de ses adaptateurs (otel_facade, client Temporal, repositories) ni ses tests Godog et testcontainers-go ne sont réutilisables en Rust. Seule l'architecture se transpose (ports = traits, DI manuelle dans main.rs). Restent en revanche réutilisables : docker-compose (Postgres, Keycloak, Temporal server, collecteur SigNoz), Kong (deux routes, avec un plugin jwt ou oidc à ajouter), les migrations SQL (sqlx peut lire le même schéma) et le contrat gRPC proto/customer.proto (tonic sait le consommer). Temporal étant polyglotte, un worker Rust peut coexister avec les workflows Go. Un module agent_orchestrator en Rust ferait de toute façon un service séparé. Les failles héritées (ParseUnverified, CORS * avec credentials) doivent être corrigées quel que soit le langage.

## 2. Vérifications adverses (2)

### Vérification 1

## Vérification n°2 : proposition « backend Rust » (au 2026-10-27)

Sources consultées : API crates.io, API GitHub (READMEs, releases, code), clones superficiels de adk-rust, gemini-rust, opentelemetry-rust et rig, le fichier openapi.yaml officiel d'OpenAI (4,0 Mo, branche main), la page Libraries d'OpenAI et la doc Gemini sur les jetons éphémères. Aucune affirmation n'est réfutée. Deux sont nuancées et trois restent non prouvées, faute d'avoir été cherchées.

### Affirmations

1. **Pas de SDK OpenAI officiel en Rust ; async-openai est seulement communautaire.**
   - Verdict : **confirmé**.
   - Preuve : la section « Install an official SDK » liste JavaScript, Python, .NET, Java, Go, Ruby et CLI. Java et Go y sont « currently in beta ». « Rust async-openai by 64bit » n'apparaît que sous « Community libraries ».
   - URL : https://developers.openai.com/api/docs/libraries

2. **async-openai 0.42.2 ne couvre que /realtime/calls (create, accept, hangup, refer, reject) et /realtime/client_secrets ; rien sur /live ni sur la délégation.**
   - Verdict : **confirmé**.
   - Preuve : version 0.42.2 publiée le 2026-10-10. realtime.rs ne contient que /realtime/calls/*, /realtime/client_secrets et /realtime/translations/client_secrets. La recherche de code GitHub renvoie 0 résultat pour « delegation » et 0 pour « live/sessions ».
   - URL : https://github.com/64bit/async-openai/blob/main/async-openai/src/realtime.rs

3. **Le spec OpenAPI officiel décrit /live/sessions et ses sous-routes, ainsi que 188 schémas Live\*, dont les schémas sideband et délégation.**
   - Verdict : **confirmé, avec une nuance**.
   - Preuve : les chemins /live/sessions, /accept, /fork, /hangup, /refer, /reject et /content sont présents. On compte exactement 188 schémas Live\*, dont LiveSidebandClientEvent, LiveSidebandServerEvent, LiveDelegationCreated et LiveClientDelegationParam.
   - Nuance : /v1/live/sessions/{id}/attach n'est pas un chemin de l'OpenAPI. Il n'est cité que dans une description (ligne 10148). progenitor ne générera donc pas la connexion WSS sideband : seuls les types sont générables (avec typify), le transport WebSocket reste à écrire à la main.
   - URL : https://github.com/openai/openai-openapi/blob/main/openapi.yaml

4. **Le package live d'openai-go pèse environ 550 Ko, avec des tests de contrat.**
   - Verdict : **confirmé**.
   - Preuve : live.go fait 338 457 octets, sideband.go 45 705, fork.go 50 473, aliases.go 53 748, session.go 20 892, transcript.go plus transcript_grouping.go 31 758. Cela fait environ 560 Ko hors tests. Les tests decisions_contract_test, transport_contract_test et sideband_unknown_event_test existent.
   - URL : https://github.com/openai/openai-go/tree/main/live

5. **Jetons Gemini éphémères via POST v1beta/auth_tokens (uses, expireTime, newSessionExpireTime, liveConnectConstraints) ; la doc montre Python, JS et curl, pas Rust.**
   - Verdict : **confirmé**.
   - Preuve : l'URL generativelanguage.googleapis.com/v1beta/auth_tokens est citée deux fois. Les champs liveConnectConstraints et newSessionExpireTime sont présents, aucune mention de v1alpha. La page montre Python, JavaScript et REST, et ne contient aucune occurrence de « Rust ».
   - URL : https://ai.google.dev/gemini-api/docs/ephemeral-tokens

6. **Pas de SDK Gemini Developer API officiel en Rust ; google-cloud-aiplatform-v1 1.18.0 (Vertex) n'a pas auth_tokens ; gemini-rust 2.1.0, gemini-live 0.1.9 et genai 0.7.1 sont communautaires ; gemini-rust ne contient pas auth_tokens.**
   - Verdict : **confirmé**.
   - Preuve : google-cloud-aiplatform-v1 1.18.0 a été publiée le 2026-10-21, dépôt googleapis/google-cloud-rust. La recherche de code n'y trouve aucun fichier generativelanguage, et les 16 occurrences de « auth_tokens » concernent memorystore et redis. Les trois crates communautaires ont bien ces versions. Le clone de gemini-rust contient 0 occurrence de auth_tokens ou authTokens.
   - Ajout : des crates communautaires générées depuis les protos existent (googleapis-tonic-google-ai-generativelanguage-v1beta 0.42.0, de bouzuya). Je n'ai pas vérifié qu'elles exposent auth_tokens.
   - URL : https://crates.io/crates/google-cloud-aiplatform-v1

7. **rmcp 3.8.0 (2026-10-26) est le SDK officiel et implémente la spec 2026-07-28, compatible 2025-11-25.**
   - Verdict : **confirmé**.
   - Preuve : la version 3.8.0 date du 2026-10-26, dépôt modelcontextprotocol/rust-sdk. Le README dit : « implements the stable MCP 2026-07-28 specification while remaining fully compatible with the 2025-11-25 release ».
   - URL : https://github.com/modelcontextprotocol/rust-sdk

8. **OAuth de rmcp : OAuth 2.1, PKCE, RFC 8707, PRM, RFC 8414/OIDC, DCR, CIMD, montée de scope sur 403, refresh automatique.**
   - Verdict : **confirmé**.
   - Preuve : chaque point figure mot pour mot dans OAUTH_SUPPORT.md, lignes 7 à 15 (dont SEP-991 pour CIMD et SEP-835 pour la montée de scope sur 403).
   - URL : https://github.com/modelcontextprotocol/rust-sdk/blob/main/docs/OAUTH_SUPPORT.md

9. **SDK A2A Rust officiel a2aproject/a2a-rs (A2A v1, JSON-RPC, REST, gRPC/tonic, SLIMRPC, axum) ; crates a2a-lf 0.4.2, a2a-client-lf 0.2.9 et a2a-server-lf 0.5.3 du 2026-10-16 ; MSRV 1.85.**
   - Verdict : **confirmé**.
   - Preuve : le README dit « Rust workspace for the A2A v1 protocol » et liste ces protocoles et « Rust 1.85 or newer ». Les trois versions ont été publiées le 2026-10-16 et pointent vers ce dépôt.
   - Précision : le README ne mentionne pas SSE explicitement (non vérifié). Le dépôt compte 98 étoiles et sert environ 133 000 téléchargements, ce qui reste jeune. À comparer avec a2a-go, qui en est à v2.7.0 (2026-10-21).
   - URL : https://github.com/a2aproject/a2a-rs

10. **Le dépôt a2ui contient dart, kotlin, python, swift et typescript, sans Rust ; specification/ contient v0_9, v0_9_1 et v1_0, et conformance/ existe.**
    - Verdict : **confirmé**.
    - Preuve : la racine liste dart, kotlin, python, swift, typescript et conformance. specification/ contient v0_8, v0_9, v0_9_1 et v1_0. Il n'y a pas de dossier rust.
    - URL : https://github.com/a2ui-project/a2ui

11. **adk-rust 2.3.0 (zavora-ai, communautaire) a un profil a2ui « draft-compatible A2UI v0.9 » (createSurface, updateComponents, v0.9.1), intègre rmcp 3.1 et ne gère pas /live.**
    - Verdict : **confirmé, avec une nuance**.
    - Preuve : la version 2.3.0 date du 2026-10-09. adk-server/README dit « draft-compatible with A2UI v0.9 (createSurface, … ». quickstart-a2ui.md utilise "version":"v0.9.1". Les Cargo.toml déclarent rmcp = "3.1". On trouve 0 fichier contenant live/sessions.
    - Nuance : la branche main est déjà en version 3.0.0 et le README propose un guide de migration « 2.x to 3.0 ». Un changement d'API cassant est donc imminent, ce qui aggrave le risque lié au bus factor.
    - URL : https://github.com/zavora-ai/adk-rust

12. **Le SDK Temporal Rust est GA en v1.0.0 (2026-09-04), puis en v1.1.0 (2026-10-06).**
    - Verdict : **confirmé**.
    - Preuve : la release v1.0.0 a été publiée le 2026-09-04T19:44Z avec la mention « Temporal Rust SDK Generally Available… now considered stable ». La v1.1.0 date du 2026-10-06. La crate temporalio-sdk a dépassé 3,4 M téléchargements.
    - URL : https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0

13. **Temporal Rust : macros #[activities] et #[activity].**
    - Verdict : **non prouvé** (pas cherché).
    - URL : https://github.com/temporalio/sdk-rust

14. **opentelemetry 0.33.1 : Logs et Metrics Stable, Traces et Context Beta ; GEN_AI_OPERATION_NAME présent dans trace.rs.**
    - Verdict : **confirmé**.
    - Preuve : le tableau du README indique Logs et Metrics API, SDK et OTLP en Stable, et Traces API, SDK et OTLP, Context et Propagators en Beta. trace.rs:403 contient `pub use crate::attribute::GEN_AI_OPERATION_NAME`. La version 0.33.1 date du 2026-10-09.
    - URL : https://github.com/open-telemetry/opentelemetry-rust

15. **axum 0.8.9, tokio-tungstenite 0.30.0 (2026-07-11) et reqwest dépassent chacun 300 M téléchargements.**
    - Verdict : **confirmé**.
    - Preuve : axum 0.8.9 en est à 547 M, tokio-tungstenite 0.30.0 (2026-07-11) à 329 M, reqwest 0.13.5 à 842 M.
    - URL : https://crates.io/crates/tokio-tungstenite

16. **jsonwebtoken 11.1.0 (2026-09-16) avec module jwk ; openidconnect 4.0.1 (2025-07-06).**
    - Verdict : **confirmé pour les versions et les dates**. Le module jwk n'a pas été vérifié dans le code (**non prouvé**, bien que très probable).
    - URL : https://crates.io/crates/jsonwebtoken

17. **rig-core 0.45.0 stable, 0.46.0-rc.1 (2026-10-23), environ 9 000 étoiles ; pas d'ADK Google ni d'OpenAI Agents SDK en Rust.**
    - Verdict : **confirmé**.
    - Preuve : 0.45.0 date du 2026-10-19 et 0.46.0-rc.1 du 2026-10-23. Le dépôt compte 8 990 étoiles. Aucune crate officielle Google ou OpenAI n'apparaît sur crates.io.
    - URL : https://github.com/0xPlaygrounds/rig

18. **jsonschema 0.60.2 (2026-10-26) valide JSON Schema 2020-12.**
    - Verdict : **version confirmée**. Le support 2020-12 n'a pas été revérifié ici (**non prouvé**).
    - URL : https://crates.io/crates/jsonschema

19. **openai-go livre presque chaque jour, avec un changement cassant en v3.86.**
    - Verdict : **confirmé**.
    - Preuve : v3.85.1 (10-22), v3.86.0 (10-23), v3.87.0 et v3.88.0 (10-26). La v3.86.0 annonce « Breaking change in a minor release » : les champs Instructions de Decisions et des questions Live passent en union typée.
    - URL : https://github.com/openai/openai-go/releases/tag/v3.86.0

20. **Aucun crate Rust ne gère GPT-Live (/v1/live/sessions et sideband /attach).**
    - Verdict : **confirmé pour les crates examinées** : async-openai, adk-rust, gemini-rust, genai, rig. Une absence totale sur crates.io n'est pas démontrable.

### Liste corrigée des trous à écrire à la main

1. **Relais GPT-Live** : POST /v1/live/sessions (SDP en entrée et en sortie), accept, hangup, reject. Il peut être généré en partie avec progenitor sur le sous-ensemble /live de l'OpenAPI. Environ 1 à 3 jours.
2. **Transport sideband WSS /v1/live/sessions/{id}/attach**, entièrement à la main car absent des chemins OpenAPI : authentification Bearer, reconnexion, abort, close/closed, drain. Les types d'événements (LiveSidebandServerEvent et ClientEvent) sont générables avec typify puis à retoucher, avec une variante Unknown. Il faut aussi le tampon des transcripts, le plafond de 500 tokens et les accusés. Environ 6 à 10 jours, puis une maintenance continue : l'API a déjà cassé en octobre 2026.
3. **Tests de contrat** sur des fixtures Live, en reprenant les cas des tests d'openai-go (decisions_contract, transport_contract, sideband_unknown_event). Environ 2 à 3 jours.
4. **Jetons Gemini éphémères** : appel REST v1beta/auth_tokens. Aucune crate officielle ; les crates googleapis-tonic générées depuis les protos ne sont pas vérifiées. Environ 0,5 à 1 jour, plus un spike pour vérifier que firebase_ai accepte ces jetons.
5. **Couche agent A2UI** : validation par jsonschema contre specification/v0_9_1, assainissement, boucle de réparation par LLM, exécution de conformance/. Environ 5 à 8 jours. adk-rust n'est pas un appui fiable : il est communautaire, seulement « draft-compatible », et la 3.0 cassante est en préparation.
6. **Appels LLM** (Responses API) via async-openai ou rig, deux crates communautaires. Environ 1 à 2 jours, plus le risque de dépendre de crates non officielles.
7. **Auth Keycloak** : cache JWKS avec rotation des kid et middleware tower. Il faut aussi corriger ParseUnverified et le CORS * hérités. Environ 1,5 à 2 jours.
8. **OTel GenAI** : spans gen_ai.* manuels et propagation du contexte. Les constantes existent, mais les traces restent en Beta. Environ 2 à 3 jours.
9. **Lease et affinité de session** (sqlx), drain, reprise de délégation : environ 3 à 4 jours, identiques dans tous les langages.
10. **Réintégration au saaster kit** : CI cargo, image Docker, tests BDD avec cucumber-rs et testcontainers-rs. Environ 3 à 5 jours.
11. **Montée en compétence Rust async** : c'est le facteur dominant, et il n'est pas chiffrable sans connaître l'équipe.

Le total indicatif de 4 à 7 semaines-personne de plomberie de plus qu'en Go (hors apprentissage) reste plausible. Le point 2 en est le principal contributeur et le principal risque.

### Vérification 2

# Vérification des affirmations de la proposition Rust (vérificateur sceptique n°1, 2026-10-27)

**Conclusion :** la proposition affirme qu'aucune crate Rust ne gère GPT-Live (`/v1/live/sessions`, le sideband `/attach` et la délégation). C'est **réfuté**. La crate communautaire `oai-rt-rs` 0.5.1 couvre ce périmètre. Elle n'est pas officielle et a un seul mainteneur, mais elle change le chiffrage de l'écart. Les autres affirmations sont confirmées dans l'ensemble, avec quelques nuances.

Méthode : API crates.io, code source des crates téléchargées, dépôts et releases GitHub, spec OpenAPI officielle d'OpenAI, pages de documentation. Le quota de l'API de recherche GitHub a été épuisé en cours de route, ce qui explique les points marqués non prouvés.

## 1. Verdicts par affirmation

1. **Aucun SDK OpenAI officiel en Rust.** Verdict : **confirmé**.
   - La page Libraries d'OpenAI ne cite Rust que dans « Community libraries » : `async-openai` par 64bit, avec la mention « OpenAI does not verify the correctness or security ».
   - Les SDK officiels sont JS, Python, .NET, Ruby, Java (bêta) et Go (bêta).
   - URL : https://developers.openai.com/api/docs/libraries

2. **`async-openai` 0.42.2 (2026-10-10) ne couvre que `/realtime/calls` et `client_secrets`, sans `/live` ni délégation.** Verdict : **confirmé**.
   - Le fichier `realtime.rs` ne contient que `/realtime/calls`, ses variantes (accept, hangup, refer, reject), `/realtime/client_secrets` et `/realtime/translations/client_secrets`.
   - La recherche de code GitHub renvoie 0 résultat pour « delegation » et pour « live/sessions ».
   - URL : https://github.com/64bit/async-openai/blob/main/async-openai/src/realtime.rs

3. **Implicite : aucune crate Rust ne gère `/v1/live/sessions`, l'attach sideband ni la délégation, donc tout est à écrire à la main.** Verdict : **réfuté**.
   - La crate `oai-rt-rs` 0.5.1 (2026-09-14, communautaire, MIT, un seul publieur lukacf, environ 28 700 lignes, environ 27 800 téléchargements) contient un module `oai_rt_rs::live`.
   - Ce module couvre le protocole public `gpt-live-1` :
     - `LiveClient::create_webrtc` (offre SDP, réponse SDP) ;
     - `client.attach(session_id)` (sideband) ;
     - fork, SIP, hangup ;
     - les événements `session.delegation.created`, `thinking.append`, `commentary.append` et `response.item.create` ;
     - la délégation Responses.
   - Il contient aussi des tests de codec et de WebSocket (`live_ws_options.rs` teste `live/sessions/live_s/attach`).
   - Limites :
     - il est calé sur la spec OpenAPI du 2026-09-11 (commit `38170fd`), il ne suit donc probablement pas les changements cassants d'octobre ;
     - le changement cassant de la v3.86 d'openai-go (`Instructions` devenu une union typée) n'est pas suivi ;
     - le mode `decisions` n'est pas suivi ;
     - le facteur bus est de 1.
   - URL : https://crates.io/crates/oai-rt-rs (dépôt https://github.com/lukacf/oai-rt-rs)

4. **La spec OpenAPI officielle décrit `/live/sessions` (accept, fork, hangup, refer, reject, content) et 188 schémas `Live*`.** Verdict : **confirmé, avec une nuance**.
   - Les chemins sont présents, et le décompte donne exactement 188 schémas `Live*`.
   - `LiveSidebandClientEvent`, `LiveSidebandServerEvent`, `LiveDelegationCreated` et `LiveClientDelegationParam` sont présents.
   - Nuance : `/attach` n'est pas un chemin de la spec. C'est un WebSocket, cité seulement dans une description (ligne 10148). La génération de code ne produit donc que les types, pas le transport.
   - URL : https://github.com/openai/openai-openapi/blob/main/openapi.yaml

5. **Le package `live` d'openai-go pèse environ 550 Ko, dont `live.go` 338 Ko et `sideband.go` 46 Ko.** Verdict : **confirmé**.
   - `live.go` fait 338 457 octets et `sideband.go` 45 705 octets.
   - L'ensemble des fichiers `.go` fait 655 Ko tests compris, soit environ 580 Ko hors tests.
   - Des tests de contrat existent (`decisions_contract_test.go`).
   - Les releases sont quasi quotidiennes (v3.81 à v3.88 entre le 17 et le 26 octobre).
   - La v3.86 contient bien un « Breaking change in a minor release ».
   - URL : https://github.com/openai/openai-go/tree/main/live

6. **Les jetons Gemini éphémères se créent par `POST v1beta/auth_tokens` (uses, expireTime, newSessionExpireTime, liveConnectConstraints), sans exemple Rust.** Verdict : **confirmé**.
   - La page contient `https://generativelanguage.googleapis.com/v1beta/auth_tokens`, `newSessionExpireTime` et `liveConnectConstraints`.
   - Les exemples sont en Python, JS et REST.
   - URL : https://ai.google.dev/gemini-api/docs/ephemeral-tokens

7. **Pas de SDK Gemini Developer API officiel en Rust.** Verdict : **confirmé**.
   - `google-cloud-aiplatform-v1` 1.18.0 (Vertex, googleapis officiel) : 0 occurrence de `auth_tokens` ou `AuthToken` dans le code source.
   - `gemini-rust` 2.1.0 : 0 occurrence.
   - Les crates `googleapis-tonic-google-ai-generativelanguage-v1beta` et `-v1alpha` (communautaires, bouzuya) n'ont pas non plus de service AuthToken.
   - URL : https://crates.io/crates/google-cloud-aiplatform-v1

8. **`rmcp` 3.8.0 (2026-10-26) implémente la spec stable 2026-07-28 et reste compatible 2025-11-25.** Verdict : **confirmé**.
   - Le README dit : « implements the stable MCP 2026-07-28 specification while remaining fully compatible with the 2025-11-25 release ».
   - Le dépôt est officiel (`modelcontextprotocol/rust-sdk`).
   - URL : https://github.com/modelcontextprotocol/rust-sdk

9. **OAuth de `rmcp` : PKCE, RFC 8707, RFC 9728, RFC 8414 + OIDC, DCR, CIMD, montée de scope sur 403, refresh.** Verdict : **confirmé**.
   - `OAUTH_SUPPORT.md` cite chacun de ces points (lignes 7 à 15).
   - URL : https://github.com/modelcontextprotocol/rust-sdk/blob/main/docs/OAUTH_SUPPORT.md

10. **SDK A2A Rust officiel (`a2aproject/a2a-rs`) pour A2A v1, avec les crates `a2a-lf` 0.4.2, `a2a-client-lf` 0.2.9 et `a2a-server-lf` 0.5.3.** Verdict : **confirmé**.
    - Le README annonce « Rust workspace for the A2A v1 protocol » : JSON-RPC, REST, gRPC via tonic, SLIMRPC, SSE, serveur sur axum.
    - Le `Cargo.toml` fixe `rust-version = 1.85`.
    - Les trois crates sont datées du 2026-10-16 et restent toutes en 0.x.
    - URL : https://github.com/a2aproject/a2a-rs

11. **Le dépôt a2ui contient dart, kotlin, python, swift et typescript, sans Rust, et publie les specs v0_9, v0_9_1, v1_0 ainsi que `conformance/`.** Verdict : **confirmé**.
    - Le listing du dépôt le montre. `specification/` contient aussi v0_8.
    - URL : https://github.com/a2ui-project/a2ui

12. **`adk-rust` 2.3.0 (zavora-ai, communautaire) a un profil A2UI « draft-compatible v0.9 », intègre `rmcp` 3.1 et ignore `/live`.** Verdict : **en partie réfuté**.
    - `rmcp` 3.1 est bien cité dans le README.
    - Aucune occurrence de `live/sessions`.
    - En revanche, le README de `adk-ui` 2.2.0 annonce « a2ui v0.9.1 stable + v1.0 release candidate », pas une version « draft ».
    - `adk-realtime` 2.3.0 gère OpenAI Realtime (l'ancienne API `/v1/realtime` avec WebRTC) et Gemini Live (BidiGenerateContent), mais pas GPT-Live `/live`.
    - URL : https://github.com/zavora-ai/adk-rust

13. **SDK Temporal Rust GA en v1.0.0 (2026-09-04), puis v1.1.0 (2026-10-06), avec les macros `#[activities]` et `#[activity]`.** Verdict : **confirmé**.
    - La release v1.0.0 dit : « Temporal Rust SDK Generally Available… now considered stable ».
    - La v1.1.0 date du 2026-10-06.
    - Les macros apparaissent dans `src/testing.rs` de `temporalio-sdk` 1.1.0.
    - URL : https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0

14. **opentelemetry-rust 0.33.1 : Logs et Metrics Stable, Traces Beta, Context Beta, constante `GEN_AI_OPERATION_NAME` présente.** Verdict : **confirmé**.
    - Le tableau du README donne Traces API, SDK et OTLP en Beta, Context et Propagators en Beta, Logs et Metrics en Stable.
    - `GEN_AI_OPERATION_NAME` est dans `opentelemetry-semantic-conventions/src/trace.rs`.
    - URL : https://github.com/open-telemetry/opentelemetry-rust

15. **Socle mûr : axum 0.8.9, tokio-tungstenite 0.30.0 (2026-07-11), chacun à plus de 300 M de téléchargements.** Verdict : **confirmé**.
    - axum : 547 M de téléchargements ; tokio-tungstenite : 329 M.
    - URL : https://crates.io/crates/tokio-tungstenite

16. **`jsonwebtoken` 11.1.0 (2026-09-16) avec un module jwk, et `openidconnect` 4.0.1 (2025-07-06).** Verdict : **confirmé** pour les versions et les dates.
    - Le module jwk n'a pas été vérifié dans le code.
    - À noter : `openidconnect` n'a pas eu de release depuis 15 mois.
    - URL : https://crates.io/crates/jsonwebtoken

17. **`rig-core` 0.45.0 stable, 0.46.0-rc.1 (2026-10-23), environ 9 000 étoiles ; pas d'ADK Google ni d'OpenAI Agents SDK en Rust.** Verdict : **confirmé pour les versions, non prouvé pour le reste**.
    - Les versions et dates sont confirmées.
    - Le nombre d'étoiles n'a pas pu être vérifié (quota GitHub épuisé).
    - L'absence d'ADK officiel est cohérente avec ce qui a été trouvé : seul `adk-rust` (communautaire) existe.
    - URL : https://github.com/0xPlaygrounds/rig

18. **`jsonschema` 0.60.2 (2026-10-26).** Verdict : **confirmé** pour la version et la date.
    - Le support de JSON Schema 2020-12 n'a pas été revérifié dans le code.
    - URL : https://crates.io/crates/jsonschema

19. **`gemini-live` 0.1.9 et `genai` 0.7.1 sont communautaires.** Verdict : **confirmé**.
    - Dépôts : jacoblincool/gemini-live-rs et jeremychone/rust-genai.
    - URL : https://crates.io/crates/genai

20. **openai-go a livré un changement cassant en v3.86.** Verdict : **confirmé**.
    - Les champs `Instructions` des modes Decisions et Live sont devenus des unions typées.
    - URL : https://github.com/openai/openai-go/releases/tag/v3.86.0

## 2. Trous à écrire à la main (liste corrigée)

1. **Client GPT-Live, relais et sideband.** Ce n'est plus forcément à écrire de zéro : il faut d'abord évaluer `oai-rt-rs` 0.5.1 (communautaire, un seul mainteneur, spec figée au 2026-09-11). Deux voies possibles :
   - **Voie A :** adopter `oai-rt-rs` derrière un trait `LiveProvider`, auditer la crate et la rattraper sur les changements d'octobre (unions `Instructions`, mode decisions), en vendorisant ou en forkant si besoin. Environ 3 à 5 jours.
   - **Voie B :** écrire notre propre client, avec des types générés par typify depuis les schémas `Live*` de l'OpenAPI et un transport WSS `/attach` écrit à la main (il n'est pas dans l'OpenAPI). Environ 6 à 10 jours.

   Dans les deux cas, il faut ensuite une maintenance d'environ une demi-journée à une journée par mois.
2. **Tests de contrat sur des fixtures Live** enregistrées en réel, comparées aux tests d'openai-go et aux tests de `oai-rt-rs` : environ 2 à 3 jours. C'est indispensable si on dépend d'une crate tierce.
3. **Jetons Gemini éphémères** (REST `v1beta/auth_tokens` avec `liveConnectConstraints`) : environ 0,5 à 1 jour. Aucune crate Rust, officielle ou communautaire, ne le gère. Il faut aussi vérifier la compatibilité avec `firebase_ai`.
4. **Couche agent A2UI** (catalogue, validation `jsonschema`, assainissement, boucle de réparation, conformance) : environ 5 à 8 jours. On peut s'inspirer de `adk-ui` (communautaire, v0.9.1 et v1.0 en RC).
5. **Appels LLM pour le routeur et GenUI** (Responses API via `async-openai` ou `rig`, tous deux communautaires) : environ 1 à 2 jours.
6. **Auth Keycloak** (cache JWKS avec rotation des `kid`, middleware tower), plus la correction de `ParseUnverified` et du `CORS *` de l'existant : environ 1,5 à 2 jours.
7. **OTel GenAI** (spans `gen_ai.*`, propagation vers le sideband et `rmcp`) : environ 2 à 3 jours, avec un risque lié aux Traces encore en Beta.
8. **Lease et affinité de session, drain, reprise de délégation** (sqlx) : environ 3 à 4 jours. Le coût est le même quel que soit le langage.
9. **Intégration au saaster kit** (CI cargo, image Docker, BDD avec cucumber-rs et testcontainers-rs) : environ 3 à 5 jours.
10. **Montée en compétence Rust** : non chiffrable sans connaître l'équipe. C'est le facteur dominant.
11. **Total indicatif de plomberie en plus de Go** : environ 3,5 à 6,5 semaines-personne avec la voie A, environ 4 à 7 semaines-personne avec la voie B, hors apprentissage.

Le spike de 1 à 2 semaines doit maintenant comparer `oai-rt-rs` avec un client généré, sur une délégation de bout en bout avec les événements d'octobre.

Les fichiers téléchargés pour la vérification sont dans /tmp/claude-1000/-home-bfontaine-github-ai-voice-ui/4c090190-d378-4c58-84ec-7e52cf30a8ed/scratchpad/v.

## 3. Jugements (3)

### Lentille : Technique temps réel & protocoles : maturité réelle des SDK selon les fact-checks (sideband GPT-Live, Gemini, MCP, A2A, A2UI, Temporal), volume de code maison sur le chemin critique de la voix, et question de savoir si la performance, la latence ou la mémoire avec des milliers de WebSockets constituent ici un vrai goulot.

**scenarioTeamKnowsRust**
- **rust : 6.5/10** — Points forts confirmés par les deux vérifications : rmcp 3.8 (spec 2026-07-28, l'OAuth le plus complet de l'écosystème), a2a-rs officiel A2A v1 (mais en 0.x, 98 étoiles, contre a2a-go v2.7), Temporal Rust GA depuis le 2026-09-04, et un socle tokio/axum/tungstenite très mûr. Le trou se situe sur le chemin critique. Il n'y a pas de SDK OpenAI officiel, et async-openai ne gère pas /live. Le relais SDP et le sideband /attach (absent des chemins OpenAPI, donc transport à écrire à la main, seuls les types sont générables avec typify) relèvent du code maison sur l'API la plus instable du projet : openai-go livre presque chaque jour, avec un changement cassant en v3.86 le 2026-10-23. L'affirmation « tout est à écrire à la main » est réfutée par le premier vérificateur : oai-rt-rs 0.5.1 couvre live, attach et la délégation. Mais cette crate a un seul mainteneur, est figée sur la spec du 2026-09-11 et ne suit ni les unions Instructions ni le mode decisions. Le gain se limite donc à un point de départ à auditer et à forker. Pas de SDK Gemini (auth_tokens à la main, et l'API v1alpha ou v1beta reste non tranchée). Traces OTel encore en Beta. Le gain de performance n'est pas un vrai goulot : quelques milliers de WebSockets restent négligeables pour Go comme pour Rust, et la latence est dominée par le LLM et le réseau. Une équipe Rust exploite bien l'exhaustivité des enums serde et l'annulation structurée, mais elle doit maintenir environ 3,5 à 7 semaines-personne de plomberie en plus, sur le maillon le plus mouvant.
- **go : 8.5/10** — Seule option dont le chemin critique voix repose entièrement sur des SDK officiels typés et vérifiés dans le code : openai-go v3.88 (Live.New, SidebandService.Connect avec Reconnect, Abort, SendRaw et RecvRaw, événements de délégation), genai AuthTokens.Create, MCP go-sdk v1.8 (2026-07-28), a2a-go/v2 v2.7 (A2A 1.0), Temporal sdk-go, ainsi que la réutilisation des adaptateurs du kit. Une goroutine par sideband suffit largement pour quelques milliers de connexions. Les risques réels, déjà connus : package live jeune (épingler ≥ v3.86, tests de contrat), OAuth MCP client encore expérimental, jetons Gemini marqués expérimentaux, pas de SDK A2UI agent (couche maison de 5 à 8 jours, comme en Rust). Même pour une équipe Rust, la marche vers Go est courte, et ce sont les SDK officiels qui suivent l'API la plus mouvante au rythme du fournisseur.
- **hybrid-go-python : 7/10** — La passerelle Go garde l'avantage des SDK officiels sur la voix. Python apporte le seul SDK A2UI agent mûr (a2ui-agent-sdk 0.9) et ADK 2.13, ce qui supprime la couche A2UI maison. Mais l'installation de Python est fragile (conflits vérifiés mcp<2 et openai<3 avec les extras temporalio et ADK, fenêtre OTel 1.43–1.44), il faut un saut A2A interne dans la boucle de délégation (pas dans l'audio) et maintenir deux runtimes. L'argument « sideband à écrire à la main en Go », sur lequel reposait l'hybride, est réfuté. Pour une équipe Rust, cette option n'apporte rien sur le plan technique : elle ajoute deux langages qu'elle ne maîtrise pas.
**scenarioTeamDoesNotKnowRust**
- **rust : 4/10** — Mêmes trous que dans le scénario A (client GPT-Live relais et sideband, jetons Gemini, A2UI, appels LLM via des crates communautaires), mais cette fois écrits par des débutants en Rust async, précisément sur la partie la plus délicate : WebSocket longue avec reconnexion, drain, annulation (CancellationToken, select!), et bornes Send/Sync et 'static dans tokio. Hériter d'oai-rt-rs (un seul mainteneur, spec en retard d'un mois) exige justement la compétence nécessaire pour l'auditer et le forker. Le risque de bugs de concurrence ou de blocages subtils dans le supervisor sideband l'emporte sur les garanties du compilateur tant que l'équipe ne maîtrise pas le langage. Les avantages de performance de Rust ne valent rien ici, puisqu'il n'y a pas de goulot CPU ni mémoire. Les protocoles officiels (rmcp, a2a-rs, Temporal) restent de bonne qualité, d'où une note qui ne descend pas plus bas.
- **go : 8/10** — Mêmes atouts techniques : SDK officiels sur toute la plomberie temps réel, et presque aucun code maison sur le chemin voix. Je retire un demi-point par rapport à l'évaluation précédente, car la maîtrise de Go par l'équipe n'a jamais été confirmée. La courbe d'apprentissage de Go est cependant courte, le modèle goroutines et context se prête naturellement au supervisor sideband, et l'existant du saaster kit sert de référence. Les risques restants sont les mêmes que dans le scénario A : package live jeune, OAuth MCP client expérimental, couche A2UI maison.
- **hybrid-go-python : 6.5/10** — La voix reste sur Go avec les SDK officiels, et A2UI et ADK restent en Python avec les SDK officiels. C'est solide sur les protocoles, mais une équipe Flutter qui découvre le backend doit tenir deux runtimes, un contrat A2A interne et la gestion fragile des dépendances Python (conflits vérifiés). La frontière A2A interne est réversible, mais elle ajoute un saut réseau et une surface d'observabilité (propagation OTel entre langages) sans bénéfice de performance.

**Verdict** : Sous l'angle temps réel et protocoles, Rust est une option techniquement honnête, mais il n'est jamais la meilleure. Ses SDK officiels couvrent bien les protocoles « stables » : MCP via rmcp 3.8, A2A v1 via a2a-rs (encore en 0.x), Temporal GA. En revanche, le seul composant où le code maison fait vraiment mal, le client GPT-Live (relais SDP et sideband /attach avec délégation), n'a pas de SDK officiel en Rust. Or c'est la partie la plus mouvante : releases openai-go quasi quotidiennes, changement cassant en v3.86. La découverte d'oai-rt-rs 0.5.1 réfute « tout à écrire à la main », mais cette crate à mainteneur unique, figée sur la spec du 2026-09-11, ne fait que réduire l'écart (voie A : environ 3,5 à 6,5 semaines-personne en plus) sans le combler. Le transport /attach n'est pas dans l'OpenAPI, donc la génération ne produit que les types. Les jetons Gemini restent à faire à la main. L'argument de performance ne tient pas : quelques milliers de WebSockets majoritairement inactives sont triviales en Go comme en Rust, et la latence perçue est dominée par le modèle et le réseau. Aucune mesure n'existe d'ailleurs pour le contredire. Classement : Go devant dans les deux scénarios (8,5 si l'équipe maîtrise Rust, 8 sinon), puis l'hybride (7 et 6,5), puis Rust (6,5 et 4). Si l'équipe maîtrise Rust, celui-ci reste défendable à condition d'isoler le client Live derrière un trait LiveProvider, de forker ou d'auditer oai-rt-rs, de prévoir des tests de contrat sur des fixtures réelles et de faire passer un spike de délégation de bout en bout avec les événements d'octobre avant tout engagement. Si l'équipe ne connaît pas Rust, le cumul « apprentissage de l'async Rust » et « client sideband maison sur une API instable » place le risque exactement sur le chemin critique de la voix. Je le déconseille dans ce cas. La variante « réécrire en Rust un composant mesuré comme goulot, plus tard, derrière un port » est la seule forme de Rust que cette lentille soutient sans réserve.

### Lentille : ÉQUIPE & EXPLOITATION : compétences, nombre de langages à tenir, réutilisation du saaster kit Go, temps de compilation et vélocité, recrutement, testabilité TDD/BDD (cucumber-rs contre Godog), charge de maintenance continue. Point de départ : l'hypothèse « équipe Flutter + Go » n'est pas confirmée. Le kit Go lui-même n'impose pas grand-chose : il est en go 1.23 alors qu'ADK et openai-go exigent Go 1.26 (il faut de toute façon un module séparé), et sa CI (azure-pipelines.yml) ne lance ni go test ni Godog. Ce qu'on en réutilise vraiment, ce sont des motifs (hexagonal, otel_facade, client Temporal, testcontainers) et l'infrastructure (docker-compose, Kong, Keycloak, SigNoz). L'infrastructure reste réutilisable quel que soit le langage.

**scenarioTeamKnowsRust**
- **rust : 7/10** — Pas d'apprentissage, donc le facteur dominant de la proposition disparaît. Les points d'exploitation sont réels : une tâche tokio par sideband, pas de GC, CancellationToken pour annuler les délégations, binaire statique et petite image Docker. Les enums serde exhaustives aident le TDD sur le protocole sideband. Le BDD est possible avec cucumber-rs et testcontainers-rs (non vérifié par les fact-checks, mais ce sont des crates connues). Plusieurs coûts pèsent contre. (1) Le code Go du kit ne sert à rien : il faut une nouvelle CI cargo, de nouveaux adaptateurs OTel et Temporal et réécrire les steps BDD, soit environ 3 à 5 jours. (2) Le client GPT-Live est à maintenir soi-même, environ une demi-journée à une journée par mois, sur une API qui casse en version mineure (openai-go v3.86, confirmé). Le fact-check n°1 réfute « tout à écrire à la main » : oai-rt-rs 0.5.1 couvre /live, /attach et la délégation, ce qui réduit l'écart (voie A, 3 à 5 jours). Mais cette crate a un seul mainteneur et reste figée sur la spec du 2026-09-11 : c'est une dette d'exploitation, pas un SDK. (3) Les Traces OTel sont en Beta et opentelemetry reste en 0.x : montées de version cassantes. Il faut aussi suivre rig, adk-rust (une 3.0 cassante arrive) et a2a-lf en 0.x. (4) Les compilations sont plus longues et le recrutement est plus étroit que pour Go ou Python. (5) L'organisation tient au moins trois langages (Dart, Rust, Go du kit) si le kit reste en Go. Le surcoût de plomberie, environ 3,5 à 7 semaines-personne de plus qu'en Go, reste plausible selon les deux fact-checks.
- **go : 8/10** — Même pour une équipe Rust, Go s'apprend en quelques semaines au plus, et un développeur Rust y est vite productif. Côté exploitation, Go garde l'avantage : des SDK officiels (openai-go live et SidebandService, genai AuthTokens, go-sdk MCP, a2a-go v2.7, Temporal) font que le suivi des changements cassants de GPT-Live est assuré par OpenAI, pas par l'équipe. La compilation est rapide. Le BDD Godog et testcontainers-go existent déjà dans le kit, même s'ils ne sont pas branchés en CI. Les adaptateurs OTel et Temporal se transposent, et le recrutement est facile. Deux points pèsent contre : une équipe Rust peut vivre Go comme un recul (moins de garanties de typage, pas d'enums exhaustives pour le sideband), et il faut un module séparé en Go 1.26 avec OTel ≥ v1.47, donc la réutilisation du kit reste partielle.
- **hybrid-go-python : 5.5/10** — Si l'équipe connaît Rust, il faut tout de même tenir Go et Python, soit trois langages de plus avec Dart. Python apporte le seul SDK A2UI agent mûr (a2ui-agent-sdk 0.9) et ADK, et le recrutement Python est facile. Mais l'exploitation est la plus lourde : conflits de dépendances bloquants confirmés (mcp<2 et openai<3 avec ADK et temporalio), fenêtre OTel 1.43–1.44, deux chaînes CI, deux images Docker, deux suites BDD (Godog plus behave ou pytest-bdd), et un saut A2A interne à tester et à observer. L'avantage Rust de l'équipe n'y sert à rien.
**scenarioTeamDoesNotKnowRust**
- **rust : 3/10** — Rust async (Send/Sync, lifetimes dans tokio, pinning, select!) est la courbe d'apprentissage la plus raide des options, et elle porte justement sur la partie la plus délicate : les connexions WSS longues et la reconnexion du sideband. Une équipe Flutter, éventuellement Go, mettra probablement plusieurs semaines avant d'être correctement productive. Il faut ajouter les 3,5 à 7 semaines-personne de plomberie en plus de Go, puis l'entretien d'un client Live maison ou d'une crate tierce à un seul mainteneur (oai-rt-rs), que personne dans l'équipe ne saurait auditer sereinement. Le reste pèse aussi contre : compilation plus lente qui freine la boucle TDD, recrutement Rust plus rare et plus cher, aucune réutilisation du code Go ni de Godog (réécriture en cucumber-rs), et un langage de plus pour l'organisation. Le gain de performance n'y change rien, car le goulot est la latence LLM et réseau. Rust ne vaut ici qu'en option tardive derrière un port, par exemple pour le supervisor sideband une fois mesuré.
- **go : 8.5/10** — Si l'équipe connaît déjà Go (hypothèse non confirmée), la note monte à 9 : continuité directe avec le kit hexagonal, Godog et testcontainers-go, otel_facade et le client Temporal. Si elle ne le connaît pas, Go reste le langage le plus rapide à prendre en main pour des développeurs Dart : syntaxe simple, compilation rapide, outils intégrés (go test, race detector). Les SDK officiels pour GPT-Live, le sideband, Gemini, MCP, A2A et Temporal évitent à l'équipe de maintenir un client de protocole, ce qui compte beaucoup pour une équipe débutante côté backend. Le recrutement est large. Il reste deux réserves : un module séparé en Go 1.26.10 et OTel ≥ v1.47 (le kit est en 1.23), et une CI à créer de toute façon, puisque la CI actuelle ne lance aucun test.
- **hybrid-go-python : 6/10** — Python est facile à apprendre et à recruter, et il offre la couche A2UI et ADK la plus mûre, ce qui réduit le code GenUI à écrire. Mais l'équipe doit tenir deux langages backend en plus de Dart, avec deux pipelines, deux suites BDD et une frontière A2A interne à tester et à tracer. Les conflits de dépendances Python confirmés (mcp<2, openai<3, fenêtre OTel étroite) font une charge d'exploitation réelle pour une équipe sans expérience Python en production. C'est quand même nettement préférable à Rust pour une équipe qui ne connaît pas Rust.

**Verdict** : Pour cette lentille, le choix de Rust dépend entièrement de l'équipe, et même une équipe Rust ne lui donne pas la première place. (A) Si l'équipe maîtrise Rust, la note est de 7, contre 8 pour Go et 5,5 pour l'hybride. Rust devient défendable, mais Go garde l'avantage d'exploitation : des SDK officiels suivent pour l'équipe une API GPT-Live qui casse en version mineure, la compilation est rapide, les motifs et l'outillage BDD du kit se réutilisent, et le recrutement est plus large. Le fact-check qui réfute « aucune crate Rust pour /live » (oai-rt-rs 0.5.1) réduit l'écart, sans l'annuler : la crate a un seul mainteneur et elle est figée avant les changements cassants d'octobre. (B) Si l'équipe ne connaît pas Rust, la note tombe à 3, contre 8,5 pour Go et 6 pour l'hybride. L'apprentissage de Rust async arrive sur la partie la plus délicate (le sideband), s'ajoute à 3,5 à 7 semaines-personne de plomberie et à une maintenance continue d'un client non officiel, sans bénéfice de performance utile puisque le goulot est la latence LLM et réseau. Recommandation sous cette lentille : il faut d'abord confirmer les compétences réelles de l'équipe. Si elle maîtrise Rust, faire le spike de 1 à 2 semaines (oai-rt-rs contre un client généré, délégation de bout en bout avec les événements d'octobre, BDD cucumber-rs) avant de trancher. Sinon, rester sur Go et garder Rust comme réécriture ciblée derrière le port LiveProvider, une fois les latences mesurées. Réserve : le BDD avec cucumber-rs et testcontainers-rs n'a été vérifié par aucun des deux fact-checks. Godog et testcontainers-go existent dans le kit, mais la CI ne les exécute pas.

### Lentille : Risque et évolutivité : sécurité mémoire face au risque des crates communautaires, délai d'arrivée des nouveautés IA dans l'écosystème, réversibilité, préparation de la phase 2 (A2A v1.0, AG-UI). Les affirmations réfutées ou non prouvées comptent contre l'option. Aucune hypothèse n'est faite sur les langages que l'équipe maîtrise, en dehors de ce que fixe chaque scénario.

**scenarioTeamKnowsRust**
- **rust : 6/10** — Points forts confirmés par les deux fact-checks : SDK officiels pour MCP (rmcp 3.8, spec 2026-07-28, OAuth le plus complet), A2A v1 (a2aproject/a2a-rs) et Temporal (GA 1.0 le 2026-09-04, aujourd'hui 1.1). Le socle tokio/axum est très mûr. Les enums serde exhaustives et l'absence de data races à la compilation sont un vrai plus sur un protocole à états comme le sideband et la règle d'un seul propriétaire par delegation.id. En revanche, la sécurité mémoire ne rapporte presque rien par rapport à Go, qui est déjà sûr en mémoire : le goulot est le réseau et le LLM, pas le CPU. Le risque principal touche l'API la plus mouvante du produit. Il n'y a pas de SDK OpenAI officiel. Le seul client GPT-Live, oai-rt-rs 0.5.1, n'a qu'un mainteneur et s'arrête à la spec du 2026-09-11 : il ignore le changement cassant de la v3.86 (Instructions en union typée) et le mode decisions. Le transport /attach ne figure pas dans l'OpenAPI, donc on ne peut générer que les types et le transport reste à écrire à la main. En Rust, on découvre les changements cassants après les SDK officiels. A2A en Rust reste en 0.x (a2a-lf 0.4.2, 98 étoiles), alors qu'a2a-go est en v2.7. Les Traces OTel sont en Beta. adk-rust annonce une 3.0 cassante, et rig est en RC. Aucun SDK Gemini ni A2UI agent officiel. Pour AG-UI, aucune preuve d'un SDK Rust (non vérifié, donc compté contre). Côté proposition, l'affirmation « aucune crate ne gère /live » est réfutée par oai-rt-rs, et la mention « draft » d'adk-rust est nuancée. L'inventaire était incomplet, mais l'écart réel de risque est presque inchangé, puisque la crate trouvée a un bus factor de 1. Réversibilité correcte à condition d'isoler LiveProvider et AgentRuntime derrière des traits. Le service serait de toute façon séparé du kit Go.
- **go : 6.5/10** — Le SDK officiel openai-go/live suit au jour près les nouveautés et les changements cassants de GPT-Live : c'est le meilleur délai d'arrivée sur la couche la plus risquée. Gemini AuthTokens, MCP go-sdk v1.8 et a2a-go v2.7 (1.x+) sont officiels, et ADK Go v2 existe. Restent les risques connus : package live jeune avec des releases quotidiennes, OAuth client MCP expérimental, pas de SDK A2UI agent, planchers de version Go et OTel tirés par adk/v2, et réutilisation directe du kit Go existant. Dans ce scénario, l'équipe connaît Rust mais pas forcément Go, ce qui crée un petit risque d'adoption. Il reste faible, car Go s'apprend vite, d'où une note un peu plus basse que dans le scénario B.
- **hybrid-go-python : 7/10** — Selon cette lentille, c'est l'option la plus évolutive : la couche qui bouge le plus (ADK 2.13, a2ui-agent-sdk 0.9, ag-ui-protocol 1.0 et ag-ui-adk) reste dans Python, l'écosystème où les nouveautés arrivent en premier. La plomberie temps réel garde les SDK officiels Go. La frontière A2A v1.0 est réversible et prépare directement la phase 2 (A2A et AG-UI). Contre : deux langages backend que l'équipe ne connaît pas forcément ici, un saut réseau dans la boucle de délégation, et des conflits de dépendances Python vérifiés (mcp<2, openai<3 via les extras ADK et Temporal) à épingler avec soin. L'argument de départ de l'hybride (« pas de helper sideband en Go ») a été réfuté et compte contre lui.
**scenarioTeamDoesNotKnowRust**
- **rust : 3/10** — Aux risques techniques du scénario A s'ajoute un risque humain dominant. Le client GPT-Live, cœur du produit, devrait être audité, forké ou écrit (de 3,5 à 7 semaines-personne de plomberie de plus que Go, hors apprentissage) par une équipe qui découvre l'async Rust (Send/Sync, lifetimes, tokio). Il faudrait ensuite le maintenir chaque mois sur une API qui a cassé en octobre 2026. Dépendre d'oai-rt-rs (bus factor 1) sans savoir l'auditer revient à confier le cœur du produit à un tiers inconnu. Réversibilité faible en pratique : le code n'est repris ni par le kit Go ni par les compétences Flutter, et un abandon en cours de route coûte l'intégralité du service. Un troisième langage (Dart, Go du kit, Rust) augmente aussi le risque d'exploitation. Les avantages de Rust (sûreté, exhaustivité, latence sans GC) ne compensent pas ce coût sur un service limité par le réseau.
- **go : 7/10** — Note de la lentille précédente maintenue. Les SDK officiels couvrent toute la plomberie, avec le meilleur délai pour GPT-Live et Gemini. Le kit hexagonal Go se réutilise, et la courbe d'apprentissage est courte, même si l'équipe ne connaît pas encore Go (ce point n'est pas confirmé non plus). Risques restants : jeunesse du package live (à isoler derrière LiveProvider, avec des tests de contrat), A2UI maison et affinité de session. Pour la phase 2, A2A est bien couvert (a2a-go v2.7). AG-UI est moins sûr en Go (non vérifié).
- **hybrid-go-python : 7.5/10** — La lentille garde sa préférence de principe. Python est l'écosystème où ADK, A2UI agent et AG-UI arrivent en premier, Go garde les SDK officiels temps réel, et la frontière A2A est réversible. Pour une équipe Flutter, Python reste plus abordable que Rust. Le coût du second langage et du saut réseau tempère la note, de même que les conflits de dépendances vérifiés (mcp<2, openai<3) et la réfutation de l'argument « sideband à la main en Go ». L'avance sur Go est donc mince.

**Verdict** : Sous la lentille risque et évolutivité, Rust n'arrive premier dans aucun scénario. Il est à 6/10 si l'équipe maîtrise Rust (contre 6,5 pour Go et 7 pour l'hybride) et à 3/10 sinon (contre 7 pour Go et 7,5 pour l'hybride). La raison est structurelle : en Rust, le risque se concentre sur la couche la plus jeune et la plus instable du produit, GPT-Live (sideband et délégation). Il n'y a pas de SDK OpenAI officiel. La seule crate qui couvre /live, oai-rt-rs 0.5.1, a un seul mainteneur et s'arrête à la spec du 2026-09-11, sans le changement cassant v3.86 ni le mode decisions. Le transport /attach n'est pas dans l'OpenAPI, donc il ne se génère pas. En Rust, les changements arriveront toujours après Go, Python et TypeScript. Les vrais atouts de Rust (rmcp le plus complet, Temporal GA, absence de data races, enums exhaustives) portent sur des couches où Go est déjà couvert par des SDK officiels. La sécurité mémoire n'apporte presque rien face à Go, qui est déjà sûr en mémoire, sur un service limité par le réseau. La phase 2 penche aussi contre Rust : A2A Rust est en 0.x (contre a2a-go v2.7), et aucun SDK AG-UI Rust n'a été prouvé. Le fact-check a réfuté l'affirmation « aucune crate /live » de la proposition, ce qui montre un inventaire incomplet. Cela ne réduit pas sensiblement le risque, puisque la crate trouvée a un bus factor de 1. Recommandation de la lentille : ne pas choisir Rust en premier. Garder Go (ou l'hybride, si l'évolutivité de la couche agents prime) avec LiveProvider et AgentRuntime isolés derrière des ports, puis envisager Rust plus tard, composant par composant, sur un goulot mesuré (par exemple le sideband-supervisor). Si l'équipe maîtrise vraiment Rust et y tient, il faut d'abord un spike de 1 à 2 semaines qui compare oai-rt-rs à un client généré, sur une délégation de bout en bout avec les événements d'octobre. Il faut aussi prévoir un fork vendorisé et des tests de contrat repris d'openai-go. La variante Rust avec un sidecar Python GenUI est la moins risquée des variantes Rust. Hypothèse à confirmer : la note de Go dans le scénario A dépend du fait que l'équipe connaisse aussi Go, ce qui n'est confirmé dans aucun scénario.

## 4. Synthèse (1)

**Mon avis sur Rust.** Rust est une option sérieuse, mais il n'arrive premier dans aucune des trois lentilles d'évaluation. Ses points forts sont MCP (rmcp 3.8, client OAuth le plus complet), A2A v1 (a2a-rs), Temporal (stable depuis la 1.0) et un socle tokio/axum très mûr. Mais Go couvre déjà ces mêmes couches avec des SDK officiels. La performance ne compte pas ici : le délai vient du LLM et du réseau, pas du processeur.

- **Bon choix si** l'équipe maîtrise déjà Rust, accepte de maintenir elle-même le client GPT-Live et fait d'abord un essai court (spike) de 1 à 2 semaines.
- **Mauvais choix si** l'équipe ne connaît pas Rust. Elle apprendrait l'async Rust sur la partie la plus délicate : la connexion WebSocket longue de supervision (sideband) et la délégation.

**Scores (somme des 3 lentilles, sur 30)**

| Scénario | Rust | Go | Hybride Go+Python |
|---|---|---|---|
| L'équipe maîtrise Rust | 19,5 | **23** | 19,5 |
| L'équipe ne connaît pas Rust | 10 | **23,5** | 20 |

**Ce qu'il faudrait coder à la main en Rust (confirmé)**
- **Client GPT-Live.** Il n'y a pas de SDK OpenAI officiel en Rust, et async-openai 0.42.2 ne couvre que l'ancien `/realtime`.
  - Une crate communautaire, `oai-rt-rs` 0.5.1, couvre bien `/live`, la connexion `/attach` et la délégation : l'affirmation « rien n'existe » est donc réfutée.
  - Mais elle n'a qu'un mainteneur, s'arrête à la spec du 2026-09-11 et ne suit ni le changement cassant de la v3.86 d'openai-go ni le mode `decisions`.
  - `/attach` n'est pas un chemin de l'OpenAPI : on peut en générer les types, pas la connexion WebSocket.
- **Jetons Gemini éphémères** : appel REST `v1beta/auth_tokens`, aucune crate ne le gère.
- **Couche A2UI côté agent** : validation par `jsonschema`, assainissement, boucle de réparation (comme en Go).
- **Cache JWKS Keycloak, spans OTel GenAI** (les traces OTel Rust sont encore en Beta), **tests de contrat** sur des événements Live enregistrés.
- **Intégration au saaster kit** : rien du code Go n'est réutilisable.
- **Coût en plus de Go** : environ 3,5 à 7 semaines-personne, hors apprentissage.

**Non prouvé**
- Le module `jwk` de jsonwebtoken et le support JSON Schema 2020-12 de `jsonschema`.
- SSE dans a2a-rs : les deux vérifications ne sont pas d'accord.
- Les crates `googleapis-tonic-*` exposant `auth_tokens`.
- cucumber-rs avec testcontainers-rs pour le BDD.
- L'existence d'un SDK AG-UI en Rust.
- `oai-rt-rs` n'a été trouvée que par l'un des deux vérificateurs.

**Variantes intéressantes**
1. **Rust plus tard** : réécrire en Rust un seul composant derrière un port (par exemple le superviseur de sideband), une fois un goulot mesuré. C'est la seule forme de Rust que toutes les lentilles soutiennent.
2. **Si l'équipe maîtrise Rust** : un essai de 1 à 2 semaines qui compare `oai-rt-rs` à un client généré depuis l'OpenAPI, sur une délégation complète avec les événements d'octobre.
3. **Rust avec un service Python à côté pour la GenUI** : c'est la variante Rust la moins risquée.

Avant de trancher, il faut confirmer ce que l'équipe maîtrise vraiment : ni Rust ni Go ne l'est à ce jour.

**Fichiers**
- Nouveau : `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-rust.md` (37 lignes)
- Mis à jour :
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/stack-options.md` : avertissement « équipe Flutter + Go non confirmée » en tête et section « Option Rust » (59 lignes)
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/backend/sdk-landscape.md` : colonne Rust dans la matrice
  - `/home/bfontaine/github/ai_voice_ui/knowledge/multi-agent/index.yaml`
  - `/home/bfontaine/github/ai_voice_ui/knowledge/index.yaml` : mot-clé `rust` et ajout de la note à la tâche backend
  - `tags.yaml`, régénéré
- `stack-recommendation.md` et `AGENTS.md` ne sont pas modifiés.

**Lint**
```
kb_lint : 194 notes, 11 index de domaine, 343 tags, 0 erreur(s), 0 avertissement(s)
```
