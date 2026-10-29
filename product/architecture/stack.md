---
id: p-ar-stack
title: Stack technologique et versions
area: architecture
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p7, knowledge:ma-package-versions, knowledge:genui-overview, knowledge:bloc-packages-versions, knowledge:di-setup-versions, knowledge:ds-widgetbook-versions, knowledge:ds-widgetbook-4-spike, knowledge:ma-backend-sdk-go, knowledge:adr-0003-backend-go]
links: [pdr-0045-app-backend-channel-wss-recommended, proto-a2a-bindings, proto-a2a-dart-sdk, p-ar-overview, p-ar-frontend, p-ar-backend, p-ar-quality, p-rm-open-questions, p-rm-spikes, pdr-0010-pinned-experimental-versions, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, pdr-0002-desktop-platform, ma-package-versions, genui-overview, genui-a2a-connector, genui-a2ui-overview, bloc-packages-versions, di-setup-versions, ds-widgetbook-versions, ds-widgetbook-4-spike, ma-backend-sdk-go, ma-backend-stack-recommendation, proj-sk-backend, rt-gpt-live-overview, proto-a2a-overview, test-bdd-widget-test, test-golden-alchemist, test-very-good-analysis, test-mocktail-essentials, test-coverage-ci, perf-desktop-specifics, rt-flutter-webrtc-overview, adr-0001-initial-constraints, adr-0003-backend-go, adr-0004-ds-visual-base-m3, adr-0005-ds-tokens-style-dictionary, adr-0006-ds-no-widgetbook-cloud, adr-0007-ds-design-tool-claude-design, adr-0008-ds-widgetbook-4-beta, rt-gpt-live-session-config, rt-provider-abstraction, ds-widgetbook-4-beta, ds-widgetbook-4-risks, ds-claude-design-overview, ds-claude-design-workflow, ds-tokens-figma-sources, ds-widgetbook-publish-web, ma-backend-stack-options, p-rm-backend-production-plan, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0028-linux-demo-machine]
tags: [stack, versions, flutter, genui, go, epinglage]
---
# Stack technologique et versions

**En bref.** Toutes les versions ci-dessous sont **reprises de la base `knowledge/`**, avec la date de relevé de la note. Aucune n'est inventée. Les briques expérimentales (Flutter, genui, genui_a2a) doivent être **figées exactement** avec `pubspec.lock` committé (NFR-10, [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md)). « À figer » = version à arrêter au premier commit de code ([Q-25](../roadmap/open-questions.md), [Q-46](../roadmap/open-questions.md)).

> Statut : **draft**. Les versions sont des relevés datés ; les revérifier sur pub.dev / GitHub avant tout ajout ([ma-package-versions]).

Légende statut : **stable** · **bêta** (préversion assumée, cf. talk) · **expérimental** (alpha / pré-1.0 / package jeune).

## Client Flutter desktop

| Technologie | Version | Relevé | Statut | Source |
|---|---|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 (observées au spike) — **à figer** | 2026-10-28 | stable | [ds-widgetbook-4-spike], [perf-desktop-specifics] |
| `genui` | **0.10.4**, épinglage exact ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)) | 2026-10-26 | expérimental (« alpha ») | [genui-overview] |
| `genui_a2a` | 0.10.1 (si le canal A2A est retenu, Q-39) ; appelle `message/stream` (A2A v0.3) ; compatible avec `a2a-go` v2.7.0 via `a2acompat/a2av0` (vérifié en SP-03 le 2026-10-29, [proto-a2a-go-v03-compat]) | 2026-10-26 | expérimental | [genui-a2a-connector], [proto-a2a-bindings], [proto-a2a-dart-sdk], [ma-backend-sdk-go] |
| `a2ui_core` | transitif `^0.1.0` via genui 0.10.4 (ne pas ajouter 0.3.0) | 2026-10-26 | expérimental | [genui-overview] |
| `json_schema_builder` | 0.1.7 | 2026-10-26 | expérimental | [genui-overview] |
| Protocole A2UI | **v0.9**, `"version": "v0.9"` exactement (`a2ui_core` refuse `"v0.9.1"`) ; v0.9.1 stable côté spec, v1.0 en RC ; décidé par [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md) (décision contrainte, tranche Q-03) ; paramètre `a2ui.version` | 2026-10-26 | pré-1.0 | [genui-a2ui-overview] |
| `flutter_webrtc` | 1.6.3 | 2026-10-26 | stable | [ma-package-versions], [rt-flutter-webrtc-overview] |
| `bloc` / `flutter_bloc` | 9.2.1 / 9.1.1 | 2026-10-26 | stable | [bloc-packages-versions] |
| `bloc_concurrency` | 0.3.0 | 2026-10-26 | pré-1.0 | [bloc-packages-versions] |
| `freezed` / `freezed_annotation` | 4.0.3 / 3.1.0 (exacte) | 2026-10-26 | stable | [bloc-packages-versions] |
| `get_it` / `injectable` / `injectable_generator` | 9.3.0 / 3.0.0 / 3.1.3 | 2026-10-26 | stable | [di-setup-versions] |
| `material_ui` | 1.8.0 | 2026-10-20 | stable (nouveau package) | [adr-0004-ds-visual-base-m3] |
| `widgetbook` | **4.0.0-beta.14**, exacte | 2026-10-28 | bêta | [adr-0008-ds-widgetbook-4-beta], [ds-widgetbook-versions] |
| Style Dictionary (Node) | 5.7.1 — **à figer** | 2026-10-28 | stable | [adr-0005-ds-tokens-style-dictionary] |

## Tests et qualité (client)

| Technologie | Version | Relevé | Statut | Source |
|---|---|---|---|---|
| `bdd_widget_test` | 3.0.4 | 2026-10-26 | stable | [test-bdd-widget-test] |
| `bloc_test` / `bloc_lint` | 10.0.0 / 0.4.3 | 2026-10-26 | stable / pré-1.0 | [bloc-packages-versions] |
| `mocktail` | 1.0.5 | — | stable | [test-mocktail-essentials] |
| `alchemist` (goldens) | 0.14.1 | 2026-10-08 | pré-1.0 | [test-golden-alchemist] |
| `very_good_analysis` | 11.0.0 | 2026-10-26 | stable | [test-very-good-analysis] |
| `very_good_cli` | 1.5.0 | — | stable | [test-coverage-ci] |

## Backend orchestrateur (Go)

| Technologie | Version | Relevé | Statut | Source |
|---|---|---|---|---|
| Go | ≥ 1.26.10 — **à figer** | 2026-10-27 | stable | [adr-0003-backend-go] |
| `openai-go/v3` (package `live`) | ≥ v3.86 (v3.88.0 observée) | 2026-10-26 | expérimental (package jeune) | [ma-backend-sdk-go] |
| `a2a-go/v2` | v2.7.0 (spec A2A v1.0) | 2026-10-21 | stable | [ma-backend-sdk-go], [proto-a2a-overview] |
| `google/jsonschema-go` | v0.4.3 (validation A2UI) | 2026-10-27 | pré-1.0 | [ma-backend-sdk-go] |
| OpenTelemetry Go | ≥ v1.47 | 2026-10-27 | stable (conventions `gen_ai.*` en Development) | [adr-0003-backend-go] |
| Godog / testcontainers-go | v0.13.0 / v0.37.0 (versions du kit) | 2026-10-27 | stable | [proj-sk-backend] |
| Temporal sdk-go | v1.50 — non requis pour le MVP (proposition) | 2026-10-27 | stable | [ma-backend-stack-recommendation] |
| MCP `go-sdk` | v1.8.0 — non requis pour le MVP (aucun outil MCP prévu) | 2026-10-27 | stable | [ma-backend-sdk-go] |
| `google.golang.org/genai` | v1.76.0 — seulement si Gemini est retenu | 2026-10-22 | expérimental (jetons) | [ma-backend-sdk-go] |

## Services externes

| Service | Version / modèle | Statut | Source |
|---|---|---|---|
| OpenAI GPT-Live | `gpt-live-1` (seul snapshot), 0,05 $/min, voix FR `brise` / `sillage` | **proposé** ([pdr-0012](../decisions/pdr-0012-voice-provider-openai.md)) | [rt-gpt-live-overview], [rt-gpt-live-session-config] |
| LLM texte de composition A2UI | **à figer** ([Q-17](../roadmap/open-questions.md)) | ouvert | — |
| Gemini Live | alternative documentée, non retenue | ouvert | [rt-provider-abstraction] |

## Outillage de conception

| Outil | Usage | Source |
|---|---|---|
| Claude Design | maquettes, prototypes, slides du talk | [adr-0007-ds-design-tool-claude-design] |
| Widgetbook (sans Cloud) | catalogue publié en web statique, goldens locaux | [adr-0006-ds-no-widgetbook-cloud] |

### Contexte repris de `knowledge/` (transféré le 2026-10-28)

| Origine (knowledge) | Contenu |
|---|---|
| [adr-0008-ds-widgetbook-4-beta] (contexte d'origine), [ds-widgetbook-4-beta], [ds-widgetbook-versions] | `widgetbook: 4.0.0-beta.14` adopté le 2026-10-28, épinglé en version exacte (sans `^`), contre la recommandation de l'assistant (attendre la stable). Raison du porteur : démo pour un talk Flutter GenUI, avance de phase assumée ; argument fort pour le talk : la doc v4 a une section GenUI (`CatalogItem` ↔ composant, rejeu de surfaces A2UI en cache). Les notes Widgetbook 3.x restent une référence mais ne s'appliquent pas au code du projet |
| [adr-0008-ds-widgetbook-4-beta], [ds-widgetbook-4-risks] | Issue #1797 (pas de stratégie d'URL `path` ni de liens profonds fiables) : pour la démo, on navigue depuis l'accueil. Issue #1984 (état qui fuit entre stories) : impact direct, le projet étant en Bloc uniquement ; non reproduit par le spike ([ds-widgetbook-4-spike]). Repli : retour à la 3.25.0 stable (avec les notes 3.x) si une bêta casse la démo sans contournement avant la date du talk ; point à suivre dans [spikes.md](../roadmap/spikes.md) |
| [adr-0007-ds-design-tool-claude-design], [ds-claude-design-overview], [ds-claude-design-workflow], [ds-tokens-figma-sources] | Claude Design sert aussi aux slides du talk ; raison complémentaire : cohérent pour un talk, tout l'outillage IA venant du même écosystème. Le projet n'utilise pas Figma. Synchronisation code → design uniquement, décidée et confirmée par le porteur le 2026-10-28 |
| [ds-widgetbook-publish-web] | Build, hébergement et CI de publication du catalogue à la charge de l'équipe (pas de Cloud, [adr-0006-ds-no-widgetbook-cloud]) ; pour une démo en Wasm multi-thread, préférer Firebase Hosting à GitHub Pages (opinion) |
| [ma-backend-stack-options] | Score du panel backend et lentille « Équipe » pour ce projet : [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) § « Socle de production d'origine » |

## Plateformes

| Plateforme | Rôle | Vérification connue |
|---|---|---|
| Linux (x86_64) | **seule cible** ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md), remplace pdr-0002) | `flutter_webrtc` 1.6.3 vérifié sur la machine de démo ([rt-flutter-webrtc-overview]) ; `genui` 0.10.4 : build Linux exige les en-têtes GStreamer (via `audioplayers_linux`), rendu à confirmer par SP-10 ([genui-overview]) ; spike Widgetbook validé sous Linux ([ds-widgetbook-4-spike]) |
| macOS, Windows | plus des cibles ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)) | — |

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- Versions exactes à figer : Flutter, Go, Style Dictionary, LLM texte → Q-25, Q-46, Q-17.
- Rendu effectif de `genui` sous Linux : ✅ confirmé par SP-10 le 2026-10-29 (en-têtes GStreamer requis) ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)). Q-45 (Windows) sans objet.
- Inclusion ou non de `genui_a2a` (dépend du canal app ↔ backend ; compatibilité A2A v0.3 avec a2a-go vérifiée en SP-03 : reste l'arbitrage, [pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md) proposée) → Q-39.
- ~~Version du protocole A2UI montrée par la démo~~ → tranchée : A2UI v0.9 avec genui 0.10.4 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)).
- Montée éventuelle vers genui 0.10.6 (non publiée, `a2ui_core` embarqué) avant le talk : interdite sans PR dédiée → Q-46.
