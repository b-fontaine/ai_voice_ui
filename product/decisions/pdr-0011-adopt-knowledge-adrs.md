---
id: pdr-0011-adopt-knowledge-adrs
title: "PDR-0011 — Genesis Canvas applique les ADR génériques adr-0001 à adr-0008"
area: decisions
status: validated
updated: 2026-10-31
sources: [knowledge/decisions/index.yaml, knowledge:adr-0001-initial-constraints, knowledge:adr-0002-orchestrator-backend, knowledge:adr-0003-backend-go, knowledge:adr-0004-ds-visual-base-m3, knowledge:adr-0005-ds-tokens-style-dictionary, knowledge:adr-0006-ds-no-widgetbook-cloud, knowledge:adr-0007-ds-design-tool-claude-design, knowledge:adr-0008-ds-widgetbook-4-beta, AGENTS.md]
links: [pdr-0079-013-tokens-exception-to-adr-0005, p-ar-overview, p-ar-frontend, p-ar-backend, p-ar-stack, p-ar-security, p-ar-quality, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0002-desktop-platform, pdr-0007-closed-catalog-stage-theme, pdr-0010-pinned-experimental-versions, adr-0001-initial-constraints, adr-0002-orchestrator-backend, adr-0003-backend-go, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0006-ds-no-widgetbook-cloud, adr-0007-ds-design-tool-claude-design, adr-0008-ds-widgetbook-4-beta, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0033-optional-shortcuts-mouse-first, pdr-0036-real-a2a-agents-produce-a2ui]
tags: [pdr, decision, adr, inheritance, architecture]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via les ADR adr-0001 à adr-0008 de knowledge/ et AGENTS.md § 2 ; application au produit mise en forme par l'assistant le 2026-10-28"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0011 — Application des ADR génériques de knowledge/

> **En bref.** Les décisions technologiques déjà prises dans `knowledge/decisions/` (adr-0001 à adr-0008) gouvernent Genesis Canvas. Ce PDR dit ce que chacune impose concrètement au produit. Les ADR restent la référence : on ne les recopie pas, on les applique.

Part de l'assistant : mise en forme et traduction de chaque ADR en conséquences produit.

## Contexte
- AGENTS.md § 2 et § 4 : les règles du projet découlent des ADR de `knowledge/decisions/`, qui doivent être lus avant tout choix technologique.
- Distinction voulue par le porteur : `knowledge/` porte le savoir et les décisions réutilisables ; `product/` porte ce qui est propre à Genesis Canvas.

## Hypothèses
- ✅ Les 8 ADR sont au statut « acceptée » au 2026-10-28 (`knowledge/decisions/index.yaml`).
- ⚠️ Hypothèse non confirmée : le module backend vit dans `septeo_saaster_kit` ([adr-0003-backend-go]) pour une démo de talk ; le dépôt d'accueil du backend de Genesis Canvas n'est pas confirmé → [p-rm-open-questions](../roadmap/open-questions.md) (Q-27).

## Options
Aucune alternative documentée dans la source.

## Décision
| ADR | Ce qu'il impose à Genesis Canvas | Doc produit |
|---|---|---|
| [adr-0001-initial-constraints] | Flutter ; Clean Architecture + FSD (barrels, imports vers le bas) ; `get_it`/`injectable` par constructeur, jamais `getIt` dans un widget ou un Bloc ; Bloc uniquement, events/states `sealed`/`freezed` ; TDD, et BDD `bdd_widget_test` à partir des `.feature` de la fiche ; mocks aux frontières seulement (runner voix, réseau, plateforme) | [p-ar-frontend](../architecture/frontend.md), [p-ar-quality](../architecture/quality.md) |
| [adr-0002-orchestrator-backend] | Orchestrateur et agents côté backend dès le départ ; l'app ne garde que l'audio et WebRTC, le rendu A2UI et les outils locaux sans secret ; aucun secret MCP/A2A ni clé LLM dans l'app (NFR-09) | [p-ar-overview](../architecture/overview.md), [p-ar-security](../architecture/security.md) |
| [adr-0003-backend-go] | Backend Go, module `backend/agent_orchestrator`, hexagonal ; fournisseurs (Live, A2UI) derrière des ports ; JWT vérifiés par JWKS (jamais `ParseUnverified`), CORS restreint ; couche A2UI interne derrière `out.AgentRuntime` ; `a2a-go/v2` prévu en phase 2 | [p-ar-backend](../architecture/backend.md), [p-ar-stack](../architecture/stack.md) |
| [adr-0004-ds-visual-base-m3] | Design system `Ds*` sur Material 3 via `material_ui` ; conventions desktop (Cmd/Ctrl, `PlatformMenuBar` macOS, F6) ; les `CatalogItem` du catalogue enveloppent ces `Ds*` | [p-ar-frontend](../architecture/frontend.md), [pdr-0007-closed-catalog-stage-theme](pdr-0007-closed-catalog-stage-theme.md) |
| [adr-0005-ds-tokens-style-dictionary] | Le thème de scène (24 px mini, contraste AA) est décrit en tokens DTCG dans Git et généré en Dart par Style Dictionary ; code généré committé, vérifié en CI | [p-ar-frontend](../architecture/frontend.md), [p-ar-quality](../architecture/quality.md) |
| [adr-0006-ds-no-widgetbook-cloud] | Pas de Widgetbook Cloud ; non-régression visuelle par goldens locaux (alchemist) en CI ; catalogue publié en web statique | [p-ar-quality](../architecture/quality.md) |
| [adr-0007-ds-design-tool-claude-design] | Maquettes, prototypes de surfaces et slides du talk dans Claude Design ; le handoff sert de spécification, pas de code ; DTCG reste la source de vérité ; pas de Figma | [p-fn-mockups](../functional/mockups.md) |
| [adr-0008-ds-widgetbook-4-beta] | `widgetbook: 4.0.0-beta.14` exact ; une story par composant du catalogue, surfaces A2UI rejouées en cache ; 5 contournements du spike à appliquer | [p-ar-stack](../architecture/stack.md), [p-ar-quality](../architecture/quality.md) |

## Raisons
- Ces décisions ont été prises par le porteur pour ce projet (AGENTS.md § 2) ; les rejouer au niveau produit créerait des doublons divergents.

## Options écartées
Aucune alternative documentée dans la source.

## Conséquences
Points de friction entre les ADR génériques et la fiche, **non tranchés**, à suivre dans [p-rm-open-questions](../roadmap/open-questions.md) :
- **Plateforme** : [adr-0001-initial-constraints] et [adr-0004-ds-visual-base-m3] visent aussi le web ; le produit est desktop seul ([pdr-0002-desktop-platform](pdr-0002-desktop-platform.md)). Pas de conflit : le produit restreint.
- **Authentification** : [adr-0003-backend-go] et AGENTS.md exigent des JWT vérifiés par JWKS ; la fiche exclut l'authentification utilisateur (Q-48 pour l'authentification de la route de relais SDP, Q-15 pour l'hébergement ; [pdr-0001-conference-demo-deliverable](pdr-0001-conference-demo-deliverable.md)).
- **A2A** : [adr-0003-backend-go] place `a2a-go/v2` en phase 2, alors que la démo montre des agents A2A dès l'acte 1 (Q-16) → [p-rm-roadmap](../roadmap/roadmap.md).
- **Raccourcis** : touches seules dans la fiche § 6, conventions Cmd/Ctrl dans [adr-0004-ds-visual-base-m3] (Q-05).
- **Versions** : [adr-0008-ds-widgetbook-4-beta] et [pdr-0010-pinned-experimental-versions](pdr-0010-pinned-experimental-versions.md) partagent la même politique d'épinglage.

Toute nouvelle ADR générique (`adr-0009`…) qui touche le produit doit être ajoutée au bloc `inherited` de [index.yaml](index.yaml) et à ce tableau.

## Réexaminer si
- Un ADR de `knowledge/decisions/` est remplacé : mettre à jour la ligne correspondante et `inherited`.
- Une contrainte propre à la démo exige de déroger à un ADR : créer un PDR de dérogation, sans modifier l'ADR.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-26 → 2026-10-28 | ADR adr-0001 à adr-0008 acceptés dans knowledge/ | Benoît FONTAINE (porteur) |
| 2026-10-28 | Application au produit consignée en PDR | Assistant (mise en forme) |
| 2026-10-29 | Reconfirmée ; frictions levées : dépôt d'accueil = ce dépôt et pas d'auth (`127.0.0.1`) ([pdr-0029](pdr-0029-local-docker-compose-hosting.md), Q-27, Q-48) ; agents A2A réels dès le MVP ([pdr-0036](pdr-0036-real-a2a-agents-produce-a2ui.md), Q-16) ; raccourcis facultatifs ([pdr-0033](pdr-0033-optional-shortcuts-mouse-first.md), Q-05) ; cible desktop Linux ([pdr-0028](pdr-0028-linux-demo-machine.md)) | Assistant, sur parole du porteur (conversation du 2026-10-29) |
| 2026-10-29 | Correction de la ligne précédente : dépôt d'accueil (Q-27) et absence d'auth (Q-48) **non levés** ; rouverts comme recommandations de l'assistant à confirmer par le porteur (écart à AGENTS.md § 2) | Assistant |
| 2026-10-31 | Exception confirmée par le porteur (Q-86) : pour la démo, les tokens de 013 sont des constantes contrôlées par empreinte et non régénérées par Style Dictionary à chaque porte ; adr-0005 inchangé ([pdr-0079](pdr-0079-013-tokens-exception-to-adr-0005.md), [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D4). | Benoît FONTAINE (porteur) |

Archives des ADR : `knowledge/decisions/_archive/`.
