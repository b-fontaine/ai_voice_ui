---
id: ma-backend-phase1-plan
title: "Plan phase 1 du backend orchestrateur Go (décision du 2026-10-27)"
tags: [multi-agent, backend, plan, go, bdd, tdd]
status: opinion
updated: 2026-10-27
sources: [https://github.com/openai/openai-go/tree/main/live, https://github.com/modelcontextprotocol/go-sdk/releases/tag/v1.7.0, https://a2ui.org/specification/v1.0-a2ui/, https://developers.openai.com/api/docs/guides/live-delegation]
links: [ma-backend-stack-recommendation, proj-sk-backend, rt-gemini-ephemeral-tokens, rt-gpt-live-delegation, ma-real-tool-results, ma-filler-acknowledgements, genui-a2ui-security, ma-mcp-security, test-tdd-red-green-refactor]
---
# Plan phase 1, ordonné (stack validée le 2026-10-27 ; les spikes peuvent encore ajuster les étapes)

0. **Spikes (≤ 3 j)** : jetons Gemini (v1alpha / v1beta, `bidiGenerateContentSetup` vs `liveConnectConstraints`, compatibilité `firebase_ai` ou App Check) ; mode `decisions` vs `client` ; enregistrement de fixtures d'événements sideband réels.
1. **Socle** : module `backend/agent_orchestrator` séparé (Go ≥ 1.26.10, OTel ≥ v1.47, Temporal v1.50) pour ne pas imposer le saut à `customer_service`. Middleware JWKS Keycloak (iss, aud, exp), allowlist d'origines Kong, `go test -race` + Godog dans `azure-pipelines.yml`, Renovate.
2. **Contrat UI** : catalogue A2UI métier en JSON Schema versionné par URI, partagé avec l'app (package `ui_contract`). **A2UI épinglé v0.9** tant que genui 0.10.x dépend de `a2ui_core ^0.1` ; tests `conformance/`.
3. **Gherkin d'abord** (Godog + testcontainers, faux serveur Live httptest + WS rejouant les fixtures) : relais SDP authentifié, délégation → commentary + A2UI valide, A2UI hors catalogue → rejet puis régénération, barge-in → annulation confirmée, quota dépassé. Les devs Flutter peuvent écrire ces scénarios.
4. **voice-session** : `client.Live.New` (gpt-live-1, `delegation.type=client`, `acknowledgement_delay_ms`), table `live_sessions` (session, user, tenant, owner, statut), quotas.
5. **sideband-supervisor** : `Sideband.Connect` par session, tampon des transcripts, lease Postgres, `Reconnect`, `close → closed`. Ne pas décoder l'audio du sideband.
6. **orchestrator** : routeur déterministe puis LLM en repli ; deux sorties (résumé parlable réel, A2UI). Sérialiser les `thinking/commentary.append` (chaque envoi annule tous les accusés en attente).
7. **GenUI** derrière `out.AgentRuntime` : prompt généré depuis le catalogue, élagage, validation, ≤ N régénérations, allowlist https pour `openUrl`/`Image`, pas de secret dans le data model.
8. **app-channel** WSS : JWT, corrélation `session_id` + `delegation_id`, actions typées, `traceparent`. Reçoit aussi l'appel `delegate` de Gemini.
9. **mcp-gateway** : go-sdk, OAuth `client_credentials`, allowlist d'hôtes, audit ; exposer `customer_service` en MCP avec `Stateless=true`.
10. **Gemini** : endpoint de jeton (`uses=1`, contraintes modèle/instructions) selon le résultat du spike 0.
11. **Tâches longues** : au-delà d'un seuil, workflow Temporal, annulation par signal, résultat poussé sur le canal app.
12. **Gate de fin de phase 1** : mesurer dans SigNoz délégation → 1er `commentary.append` et le coût de maintenance de la couche A2UI ; décider du sidecar Python éventuel. Désigner ≥ 2 propriétaires de l'orchestrateur.
