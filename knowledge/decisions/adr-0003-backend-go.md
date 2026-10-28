---
id: adr-0003-backend-go
title: "ADR-0003 — Backend orchestrateur en Go (module agent_orchestrator)"
tags: [adr, decision, backend, go, rust, python]
status: opinion
updated: 2026-10-28
sources: []
links: [adr-0002-orchestrator-backend, ma-backend-stack-options, ma-backend-stack-recommendation, ma-backend-sdk-landscape, ma-backend-sdk-go, ma-backend-sdk-rust, proj-sk-backend]
---
# ADR-0003 — Backend en Go

- **Statut :** acceptée le 2026-10-27, puis reconfirmée le même jour.
- **Décideur :** porteur du projet, sur recommandation de l'assistant.
- **Portée :** générique, avec contexte d'origine propre au projet (voir « Contexte d'origine (non générique) »).

## Historique (2026-10-27)
1. **Panel de 5 stacks.** Propositions, vérifications adverses, puis notation selon 3 lentilles. Le contexte donné aux agents disait « équipe Flutter + Go » : **hypothèse de l'assistant, non confirmée**. Résultat : Go 24,5, hybride 21, Python 16, TS 14,5, Dart 12.
2. **Le porteur valide Go** (« Valider et commiter »).
3. **Le porteur demande qui a décidé et pourquoi.** L'assistant reconnaît l'hypothèse non confirmée.
4. **Le porteur demande l'avis de l'assistant sur Rust.** Évaluation sur deux scénarios : si l'équipe maîtrise Rust, Go 23, Rust 19,5, hybride 19,5 ; sinon, Go 23,5, hybride 20, Rust 10.
5. **Le porteur précise** : « L'équipe maîtrise tous les langages, y compris Rust, Go et Python », et « Flutter + Go me paraît être la meilleure option ». **Décision confirmée**, avec le scénario A comme référence.
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur) ; lien vers le plan de construction propre au projet d'origine retiré des `links`, ce plan ayant quitté knowledge/ (décision inchangée).

## Contexte d'origine (non générique)
Le choix réutilisable est « Go, architecture hexagonale, fournisseurs derrière des ports », avec les raisons tirées des SDK. Sont propres au projet d'origine :
- **Emplacement** (module `backend/agent_orchestrator` dans `septeo_saaster_kit`, dépôt de l'organisation) et **« phase 2 »** (phasage du projet).
- **Compétences de l'équipe** (historique, points 1 à 5, et la raison « équipe qui maîtrise tous les langages ») : confirmées pour l'équipe d'origine seulement.
- **`ParseUnverified` et CORS `*`** : dettes du saaster kit ([[proj-sk-backend]]), pas du langage.
- **Plan de construction par étapes** associé à cette décision (socle, contrat UI, Gherkin d'abord, modules…) : propre au projet d'origine, il n'est plus dans cette base.

## Décision
- Module `backend/agent_orchestrator` dans `septeo_saaster_kit`, architecture hexagonale.
- Go ≥ 1.26.10, OTel ≥ v1.47.
- SDK : `openai-go/v3` ≥ v3.86 (Live et sideband), `genai`, MCP `go-sdk`, `a2a-go/v2` en phase 2.
- Couche A2UI écrite en interne, derrière le port `out.AgentRuntime`. Détails : [[ma-backend-stack-recommendation]].

## Raisons
- **SDK officiels sur tout le chemin critique :** relais GPT-Live et sideband (`SidebandService.Connect`), jetons Gemini, MCP 2026-07-28, A2A v1.0, Temporal.
- **Avec une équipe qui maîtrise tous les langages, c'est l'écosystème qui tranche, pas les compétences.**
- **La performance n'est pas discriminante** : la latence vient du LLM et du réseau.

## Options écartées
- **Hybride Go + Python** : préféré par la lentille « risque », car Python a le seul SDK A2UI agent mûr.
  - Son argument principal, « le sideband serait à écrire à la main en Go », est **réfuté**.
  - Sa frontière est conservée sous forme de port.
- **Rust** : premier dans aucune lentille. Pas de SDK OpenAI officiel ; `oai-rt-rs` (un seul mainteneur) couvre `/live`. Surcoût estimé à 3,5–7 semaines-personne.
- **Python** : conflits de dépendances (`mcp<2`, `openai<3`). **TS** et **Dart** : voir [[ma-backend-stack-options]].

## Risques retenus
- Le kit vérifie les JWT avec `ParseUnverified` et ouvre CORS à `*` : à corriger dès le jour 0.
- Le package `live` d'`openai-go` est jeune : l'isoler derrière un port et ajouter des tests de contrat.
- La connexion sideband vit sur un seul pod : prévoir un verrou de propriété et la reconnexion.
- **Non prouvé** : version d'API des jetons Gemini, mode de délégation `decisions`, latences réelles.

## Quand réexaminer
- **Couche A2UI trop coûteuse en Go** : sidecar Python en A2A (issu des synthèses).
- **Goulot de performance mesuré** : ce composant en Rust, derrière un port (issu des synthèses).
- **`openai-go` cesse de suivre GPT-Live** : critère ajouté par l'assistant, non issu des panels.

**Archives :** `_archive/2026-10-27-backend-stack-panel.md` et `_archive/2026-10-27-backend-rust-eval.md`.
