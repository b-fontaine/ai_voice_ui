---
id: p-ar-llm-composer
title: Composition de l'écran par un modèle (012) et passerelle LLM interne
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/012-llm-composer-crashlist/spec.md, specs/012-llm-composer-crashlist/plan.md, specs/012-llm-composer-crashlist/status.md, contracts/a2ui/genesis/v1/README.md, backend/agents/internal/llmcompose, backend/agents/internal/kit, backend/orchestrator/internal/adapter/llmgateway, backend/orchestrator/internal/adapter/openaitext, docker-compose.yaml, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [pdr-0074-012-llm-composer-gateway-crashlist-details, pdr-0070-llm-composer-and-crashlist-012, pdr-0060-small-openai-text-model-guided-a2ui, pdr-0023-example-guided-composition, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0030-llm-budget-20-eur, pdr-0014-six-component-catalog, p-ar-backend, p-ar-security, p-ar-agents-protocols, p-ar-app-channel-contract, p-ar-quality, p-ar-frontend-screen, p-fn-catalog, p-fn-feature-llm-composer-012, p-rm-open-questions, ma-openai-responses-structured-request, ma-openai-responses-structured-response, ma-openai-small-model-structured-latency, rt-ephemeral-keys]
tags: [llm, composition, passerelle, repli, crashlist, 012, a2ui]
---
# Composition par un modèle (012) et passerelle LLM interne

**En bref.** Livrée par la fonctionnalité 012 (2026-10-31), la composition par modèle de [pdr-0060](../decisions/pdr-0060-small-openai-text-model-guided-a2ui.md) tient derrière le port `Composer` de l'agent Qualité : le modèle choisit des composants et des paramètres fermés dans un **plan structuré**, les **valeurs viennent du jeu de données**, et toute erreur retombe sur la composition déterministe. Les agents n'ont ni clé ni sortie réseau : l'appel passe par une **passerelle interne de l'orchestrateur** ([pdr-0074](../decisions/pdr-0074-012-llm-composer-gateway-crashlist-details.md), D1 à D11). Gardes de la passerelle : [p-ar-security](security.md).

## Chaîne d'une demande

```mermaid
sequenceDiagram
  participant O as Orchestrateur
  participant Q as Agent Qualité
  participant G as Passerelle (orchestrateur)
  participant M as Modèle (OpenAI Responses)
  O->>Q: tâche A2A (texte du speaker, activeSurfaces)
  Q->>Q: ParseIntent (juge unique : version, plateforme, comparaison, focus, vue, refus)
  Q-->>O: squelette anticipé des surfaces du plan déterministe (D8)
  Q->>G: POST /v1/complete {instructions, input, schema_name, schema}
  G->>M: Responses, store=false, aucun outil, plafond de jetons
  M-->>G: plan JSON (ou refus)
  G-->>Q: plan, tel quel
  Q->>Q: valider le plan, construire les data models depuis le jeu
  Q-->>O: composants puis données ; sinon repli sans second appel
```

| Point | Livré |
|---|---|
| Branchement | **Qualité seule** (`COMPOSER_LLM_URL`) : trois choix possibles (`KeyIndicator`, `TrendChart`, `CrashList`). Voix du client (`ReviewSentiment`) et Livraison (`ReleaseChecklist`) restent déterministes (T35 non retenue : un seul choix possible, coût divisé par trois). L'acte 3 (clic) reste déterministe |
| Port et assemblage | `kit.Main` prend une fabrique `func(Settings, *slog.Logger) (Composer, error)` ; le décorateur `llmcompose.Composer` est assemblé dans `cmd/agent-quality` seulement (pas de cycle `kit` ↔ `llmcompose`) ; côté orchestrateur, port `out.LlmText`, adaptateurs `openaitext` et `llmgateway` |
| Plan | `{"surfaces":[{"component","params"}]}` ou `{"refusal":{"reason":"view_unavailable"}}` ; paramètres `platform`, `compare`, `count` (1 à 5) ; **la surface se déduit du composant** ; schéma strict, jamais d'`ActionBar` |
| Prompt | instructions statiques (cache de prompt) + écrans d'exemple demande → plan (`examples.json` embarqué, rejoué par les builders contre les fixtures du contrat) ; la demande du speaker n'est que dans `input` |
| Autorité de `ParseIntent` | exécuté **avant** l'appel ; un plan à plateforme ou comparaison contradictoire est `invalid_plan` ; acte 1 = exactement les quatre surfaces de [pdr-0020](../decisions/pdr-0020-act1-four-surfaces.md) (CrashList à l'acte 1 = `invalid_plan`) ; plan valide mais différent du plan attendu : accepté |
| Surfaces actives | toute surface active de l'agent est rafraîchie même si le plan l'omet ; aucun `createSurface` pour une surface active |
| Annulation | « Stop » (parent annulé) : retour `ctx.Err()`, ni repli ni journal ; `COMPOSER_TIMEOUT` : repli `timeout` |

## Repli déterministe (D3)

Toute erreur bascule sur le composeur déterministe **sans second appel** et journalise `composer.fallback{reason}`, motif d'un ensemble fermé : `disabled`, `timeout`, `transport`, `rate_limited`, `invalid_json`, `invalid_plan`, `refused_unknown`. `COMPOSER_MODEL` **vide** désactive le modèle (passerelle 503 `disabled`, repli) : la démo tient sans modèle (C-05). Le repli est assumé devant le public ([pdr-0060](../decisions/pdr-0060-small-openai-text-model-guided-a2ui.md)).

## Squelette anticipé (D8)

La mesure a montré que l'appel seul ne tient pas NFR-02 (p50 1,79 s) : le squelette des surfaces du **plan déterministe** part **avant** l'appel (`kit.SurfaceSkeleton`, `Validator.Expected`). Un plan du modèle à surfaces différentes est `invalid_plan` ; l'agent n'émet jamais de `deleteSurface`. Pendant l'appel (~1,8 s), le public voit les cellules « sans données ». Pour un refus `view_unavailable` du modèle, l'orchestrateur publie lui-même les `deleteSurface` de compensation de la tâche rejetée : les cadres s'affichent brièvement avant leur retrait. Voie intermédiaire entre le modèle et les écrans fixes de pdr-0060, à confirmer : [Q-82](../roadmap/open-questions.md).

## Vue indisponible (D6, D11)

`kit.Intent` porte un champ fermé `View` (`crashlist`, hors de la metadata `genesis/intent` ; la liste ne déplace pas le focus et n'en hérite pas). `ParseIntent` refuse (`ScopeError` `view_unavailable`) un verbe d'affichage suivi d'un nom d'un **lexique fermé** de vues (carte, camembert, histogramme, diagramme, « par pays »…) ; « tableau » n'y figure qu'en formes explicites (« sous forme de tableau »), car « le tableau de release » est le vocabulaire du produit. Un refus du modèle de même motif n'est suivi que si `ParseIntent` n'a reconnu **aucune** vue nommée. Protocole du refus : [p-ar-agents-protocols](agents-protocols.md). La liste des vues refusées est **à valider par le porteur** : [Q-81](../roadmap/open-questions.md).

## Configuration (aucune valeur en dur, AGENTS.md § 2)

| Variable | Où | Valeur du compose |
|---|---|---|
| `COMPOSER_MODEL` | orchestrateur | `gpt-6-luna` (`${VAR-défaut}` : une valeur vide désactive) |
| `COMPOSER_TIMEOUT` / `COMPOSER_AGENT_TIMEOUT` | passerelle (appel amont) / agent (appel à la passerelle + repli) | 4 s / 5 s ; `check-compose.sh` impose agent ≥ passerelle + 500 ms et agent < `AGENT_TIMEOUT` |
| `COMPOSER_MAX_OUTPUT_TOKENS`, `COMPOSER_REASONING_EFFORT` | orchestrateur | 1024 ; effort par défaut du modèle (vide) |
| `COMPOSER_RATE_BURST`, `COMPOSER_RATE_WINDOW` | orchestrateur | 10 appels d'un coup, un jeton rendu toutes les 2 s (le défaut du code est 10 s) |
| `COMPOSER_MAX_*` (requête 64 Kio, instructions 32 Kio, entrée 4 Kio, schéma 8 Kio, profondeur 12) | orchestrateur | défauts du code |
| `LLM_GATEWAY_ADDR`, `LLM_GATEWAY_ALLOWED_SOURCES` | orchestrateur | `172.30.77.10:8081` ; `172.30.77.21,172.30.77.30` |
| `COMPOSER_LLM_URL` | **par agent** | Qualité : `http://172.30.77.10:8081/v1/complete` ; absente : déterministe |

## Mesure (T51, 2026-10-30)

`cmd/composer-bench` (service compose `composer-bench`, profil `bench`), 5 demandes × 5 répétitions, dépense ≈ 0,13 € ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) : **`gpt-6-luna` retenu** (25/25 plans valides, 100 % d'accord avec le plan attendu, p50 1,79 s, p90 2,69 s) ; `gpt-6.1-terra` écarté (24/25, p90 3,06 s). **Hypothèse de pdr-0060 « un petit modèle texte tient NFR-02 et NFR-03 » : NFR-03 tenu, NFR-02 non tenu par l'appel seul**, d'où le squelette anticipé. Faits réutilisables : [ma-openai-small-model-structured-latency], [ma-openai-responses-structured-request], [ma-openai-responses-structured-response]. À remesurer sur l'horloge de l'app en répétition ([pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md)).

## Limites connues

- Seul Qualité est mesuré et branché ; les jetons du banc sont estimés (octets/4), la passerelle ne relaie pas l'usage.
- Un essai vocal de bout en bout avec micro reste à faire en répétition (la campagne du banc a joué « Affiche la liste des crashs » 10 fois sur 10 contre le vrai modèle).
- Le contrôle du compose (`backend/check-compose.sh` et son auto-test `check-compose-selftest.sh`) est lancé par la CI GitHub (`ci.yaml`), **pas par la porte de qualité de la boucle** (`gate.sh`, `verify.sh`) : [Q-84](../roadmap/open-questions.md).
