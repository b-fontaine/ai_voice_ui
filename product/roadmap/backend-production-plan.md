---
id: p-rm-backend-production-plan
title: Plan de construction du backend orchestrateur Go (profil production)
area: roadmap
status: draft
updated: 2026-10-29
sources: [git:d8c66bd:knowledge/multi-agent/backend/phase1-plan.md, https://github.com/openai/openai-go/tree/main/live, https://github.com/modelcontextprotocol/go-sdk/releases/tag/v1.7.0, https://a2ui.org/specification/v1.0-a2ui/, https://developers.openai.com/api/docs/guides/live-delegation]
links: [p-ar-backend, p-rm-roadmap, p-rm-beyond, p-rm-open-questions, p-rm-spikes, p-ar-quality, pdr-0001-conference-demo-deliverable, pdr-0005-frozen-fictional-dataset, adr-0003-backend-go, ma-backend-stack-recommendation, ma-backend-sdk-go, proj-sk-backend, rt-gemini-ephemeral-tokens, rt-gpt-live-delegation, ma-real-tool-results, ma-filler-acknowledgements, genui-a2ui-security, ma-mcp-security, test-tdd-red-green-refactor, ma-backend-stack-options, pdr-0012-voice-provider-openai, p-ar-stack, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0029-local-docker-compose-hosting, pdr-0031-github-actions-ci-linux, pdr-0048-session-log-only-no-otel-signoz, pdr-0050-gpt-live-client-delegation-recommended]
tags: [backend, go, plan, bdd, tdd, orchestrateur, deploiement]
---
# Plan de construction du backend orchestrateur Go (profil production)

**En bref.** Plan ordonné en 13 étapes (0 à 12) pour construire le backend orchestrateur Go décidé par [adr-0003-backend-go]. Il était la note `ma-backend-phase1-plan` de `knowledge/` (« décision du 2026-10-27 », statut `opinion`), transférée ici le 2026-10-28 lors du nettoyage de `knowledge/` car propre à ce projet. Le texte du plan est repris **sans modification** ci-dessous.

> **Non appliqué à la démo** (2026-10-29) : remplacé par le déploiement local de [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) — `docker compose`, backend Go et un processus par agent (un conteneur chacun : choix de conception), `127.0.0.1` recommandé (Q-48), sans Keycloak, Kong, Postgres, Temporal ni Azure Pipelines (CI : GitHub Actions, [pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md)). Le plan reste une référence technique et la base de la piste « Réutilisation dans les projets Septeo » ([beyond.md](beyond.md)).
>
> Écart d'origine, tranché pour l'hébergement (Q-15) ; l'emplacement du code (Q-27) est tranché : ce dépôt ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)). Ce plan est pensé pour une **infrastructure de production Septeo** (module dans `septeo_saaster_kit`, Keycloak, Kong, Postgres, Temporal, SigNoz, multi-tenant, quotas, Azure Pipelines). Or [pdr-0001](../decisions/pdr-0001-conference-demo-deliverable.md) fixe comme livrable une **démo de conférence** et [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) des données fictives figées. Le sous-ensemble utile à la démo et l'emplacement du code étaient ouverts : [Q-15](open-questions.md), tranchée par pdr-0029, et [Q-27](open-questions.md), rouverte (reco : ce dépôt, à confirmer). Lecture actuelle de la roadmap, non décisionnelle : étapes 0 à 8 utiles en J1-J5, étapes 9 à 12 dans l'[Au-delà](beyond.md) ([roadmap.md](roadmap.md)). Profil minimal proposé : [p-ar-backend](../architecture/backend.md) § « Profil de déploiement pour la démo ».

## Plan (texte d'origine, stack validée le 2026-10-27 ; les spikes peuvent encore ajuster les étapes)

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

## Socle de production d'origine

Origine : knowledge `ma-backend-stack-recommendation` (passages propres au projet retirés le 2026-10-28 ; le patron générique reste dans la note). Texte d'origine :

- Titre : « Backend orchestrateur : tout-Go (DÉCISION validée et reconfirmée le 2026-10-27, voir [adr-0003-backend-go]) ».
- **Stack.** Nouveau module `backend/agent_orchestrator` dans le saaster kit, **Go ≥ 1.26.10**, hexagonal comme `customer_service` ([proj-sk-backend]). Outils : MCP `go-sdk` v1.8 ; A2A `a2a-go/v2` en phase 2 ; ADK Go v2 optionnel (routeur LLM). Socle : Temporal sdk-go v1.50, OTel ≥ v1.47 → SigNoz, Postgres, Keycloak (JWT vérifié par JWKS), Kong.
- **Pourquoi.** Meilleur cumul du panel (24,5/30, [ma-backend-stack-options]). Un seul langage backend (l'équipe maîtrise tous les langages, confirmé le 2026-10-27 : Go l'emporte sur ses SDK, pas sur les compétences) ; SDK officiels pour toute la plomberie temps réel ; goroutine par sideband ; pas de saut réseau dans la boucle voix. Le seul trou vérifié (pas de SDK A2UI agent en Go) est couvert par les JSON Schemas publiés.
- **Greffe de l'option hybride.** Implémentation phase 1 en Go, in-process.
- **Frontières.** App ↔ backend : 2 routes Kong (HTTP relais, WSS canal app) ; aucune clé LLM dans l'app.
- **Risque 1 d'origine — sécurité héritée** : `ParseUnverified` + CORS `*` avec credentials ; copiés tels quels, le relais SDP brûle le quota OpenAI. Correctif dès le jour 0.
- **Lentille « Équipe » du panel** (origine : `ma-backend-stack-options`, inchangée dans knowledge) : pour ce projet, les scores du panel du 2026-10-27 (Go 24,5/30) s'appliquent avec le scénario A, le porteur ayant confirmé la maîtrise de tous les langages ; la lentille intègre la continuité avec le saaster kit Septeo.

```text
Flutter app ──HTTPS POST /voice/sessions (offre SDP)──► Kong ─► agent_orchestrator (Go)
     │  ◄──────────── answer SDP / jeton Gemini ──────────────────┤ voice-session
     │══WebRTC média══► OpenAI GPT-Live ◄══WSS sideband /attach═══╡ sideband-supervisor
     │                                                            │   │ delegation.created
     │◄══WSS app-channel (A2UI v0.9, actions, delegate Gemini)════╡ orchestrator (routeur)
                                                                  │   ├─► out.AgentRuntime (GenUI, valide A2UI)
                                                                  │   ├─► mcp-gateway ──HTTP──► serveurs MCP (Go)
                                                                  │   └─► Temporal (tâches longues)
                                                                  └─ Keycloak JWKS · Postgres · OTel→SigNoz
```

## Notes de lecture (2026-10-28)

| Point | Remarque | Renvoi |
|---|---|---|
| Fournisseur voix | Les étapes 0 et 10 (Gemini) n'ont d'objet que si Gemini est retenu ; [pdr-0012](../decisions/pdr-0012-voice-provider-openai.md) propose OpenAI seul | Q-11 |
| Mode de délégation | L'étape 4 fixe `delegation.type=client` ; mode `client` retenu, `responses` mesuré en SP-02 et écarté ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md)) | Tranchée : Q-47 |
| Version A2UI | L'étape 2 épingle v0.9, conforme à la décision | Tranchée : [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md) (Q-03) |
| MCP | L'étape 9 suppose des outils métier Septeo ; aucun outil MCP n'est prévu pour la démo ([stack.md](../architecture/stack.md)) | [beyond.md](beyond.md) |
| Observabilité | L'étape 12 suppose SigNoz | Q-55 tranchée : journal de session seul ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md)) |
| Authentification | Étapes 1 et 8 (JWKS Keycloak, JWT) ; la fiche exclut l'authentification utilisateur | Q-48 tranchée : 127.0.0.1 sans authentification ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)) |

Patron générique de la stack (sans contexte projet) : [ma-backend-stack-recommendation] ; SDK Go : [ma-backend-sdk-go] ; dettes du kit : [proj-sk-backend].
