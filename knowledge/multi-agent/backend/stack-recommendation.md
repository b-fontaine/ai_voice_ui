---
id: ma-backend-stack-recommendation
title: "DÉCISION — backend orchestrateur en Go (module agent_orchestrator)"
tags: [multi-agent, backend, decision, go, architecture, orchestrator]
status: opinion
updated: 2026-10-27
sources: [https://github.com/openai/openai-go/tree/main/live, https://github.com/modelcontextprotocol/go-sdk/releases, https://github.com/a2aproject/a2a-go, https://github.com/google/adk-go/blob/main/go.mod, https://github.com/a2ui-project/a2ui, https://developers.openai.com/api/docs/guides/live-delegation]
links: [ma-backend-stack-options, ma-backend-sdk-landscape, ma-backend-sdk-go, ma-backend-phase1-plan, proj-sk-backend, proj-sk-overview, ma-target-architecture, ma-where-to-run-agents, proto-stack-recommendation, rt-gpt-live-sideband, rt-ephemeral-keys, genui-a2ui-security, ma-otel-genai-spans]
---
# Backend orchestrateur : tout-Go (DÉCISION validée le 2026-10-27)

**Stack.** Nouveau module `backend/agent_orchestrator` dans le saaster kit, **Go ≥ 1.26.10**, hexagonal comme `customer_service` ([[proj-sk-backend]]) :
- voix : `openai-go/v3` **épinglé ≥ v3.86** (`Live.New`, `Live.Sideband.Connect`) ; `google.golang.org/genai` (`AuthTokens.Create`) ;
- outils : MCP `go-sdk` v1.8 ; A2A `a2a-go/v2` en phase 2 ; ADK Go v2 optionnel (routeur LLM) ;
- A2UI : couche maison = catalogue JSON Schema + validation (`google/jsonschema-go`) + suite `conformance/` ;
- socle : Temporal sdk-go v1.50, OTel ≥ v1.47 → SigNoz, Postgres, Keycloak (JWT vérifié par JWKS), Kong.

**Pourquoi.** Meilleur cumul du panel (24,5/30, [[ma-backend-stack-options]]). Un seul langage backend pour une équipe Flutter + Go ; SDK officiels pour toute la plomberie temps réel ; goroutine par sideband ; pas de saut réseau dans la boucle voix. Le seul trou vérifié (pas de SDK A2UI agent en Go) est couvert par les JSON Schemas publiés.

**Greffe de l'option hybride.** L'agent GenUI est derrière un port `out.AgentRuntime`. Implémentation phase 1 en Go, in-process. Si la couche A2UI maison coûte trop, on la remplace par un sidecar Python `a2ui-agent-sdk` joint en A2A v1.0 (a2a-go/v2), sans toucher au reste.

```
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

**Frontières.** App ↔ backend : 2 routes Kong (HTTP relais, WSS canal app) ; aucune clé LLM dans l'app. Backend ↔ OpenAI : REST + sideband WSS (clé projet serveur). Backend ↔ métier : MCP Streamable HTTP (serveurs `Stateless=true`). Un seul propriétaire par `delegation.id` : le supervisor qui détient la WS.

**Plan phase 1** : [[ma-backend-phase1-plan]].

**Top 3 risques**
1. **Sécurité héritée** : `ParseUnverified` + CORS `*` avec credentials ; copiés tels quels, le relais SDP brûle le quota OpenAI. Correctif dès le jour 0.
2. **Jeunesse du package `live`** (openai-go, releases quasi quotidiennes) : isoler derrière `out.LiveProvider`, repli `SendRaw/RecvRaw`, tests de contrat sur fixtures d'événements.
3. **Affinité de session** : la WS sideband vit sur un pod ; il faut un lease Postgres, `Reconnect`, un drain au redéploiement, sinon délégations perdues ou traitées deux fois.

**Non prouvé (à lever par spike)**
- Version d'API des jetons Gemini (v1alpha selon SDK, v1beta selon doc) et acceptation d'un jeton éphémère par `firebase_ai` (sinon App Check).
- Intérêt du mode de délégation `decisions` face à `client`.
- Latences (saut interne, 1er `commentary.append`) : aucune mesurée.
- Coût réel d'une génération A2UI maison en Go.
