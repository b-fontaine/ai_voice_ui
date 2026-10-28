---
id: p-ar-quality
title: Qualité, tests et mesure des NFR
area: architecture
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p12, knowledge:test-tdd-red-green-refactor, knowledge:test-bdd-widget-test, knowledge:test-realtime-fake-runner, knowledge:ma-voice-agent-evals, knowledge:ma-otel-genai-spans]
links: [p-ar-overview, p-ar-frontend, p-ar-backend, p-ar-replay, p-ar-stage-runtime, p-ar-stack, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-rm-open-questions, pdr-0010-pinned-experimental-versions, test-tdd-red-green-refactor, test-bdd-widget-test, test-bdd-app-running-fixture, test-realtime-fake-runner, test-mock-boundaries-only, test-bloc-test, test-golden-alchemist, test-very-good-analysis, test-coverage-ci, bloc-no-cubit, bloc-observer, ma-voice-agent-evals, ma-otel-genai-spans, p-rm-backend-production-plan, ds-widgetbook-4-testing, ds-a11y-wcag-contrast, perf-audio-visualizer-60hz, perf-repaint-boundary, genui-test-surface-controller, genui-a2ui-security, proj-avw-risks, test-bdd-gherkin-practices]
tags: [qualite, tdd, bdd, gherkin, ci, nfr, mesure, observabilite]
---
# Qualité, tests et mesure des NFR

**En bref.** Les 9 scénarios Gherkin de la fiche (§4) sont écrits **avant** le code et exécutés en automatique avec `bdd_widget_test` (client) et Godog (backend). Le TDD part de ces scénarios (outside-in). On ne double que les frontières (voix, réseau, plateforme). Les NFR sont mesurés à partir du **journal de session** sur 10 répétitions, au p90 (fiche §8, Definition of Done).

> Statut : **draft**. Stratégie proposée par l'assistant sur la base des règles d'AGENTS.md §2.

## Pyramide de tests

| Niveau | Outil | Ce qui est testé | Doublures | Source |
|---|---|---|---|---|
| Scénarios BDD client | `bdd_widget_test` 3.0.4 | les 9 scénarios de [voice-screen-generation.feature](../functional/features/voice-screen-generation.feature) et [barge-in.feature](../functional/features/barge-in.feature) | `FakeVoiceSession`, `FakeSessionEventSource` (rejoue un journal) | [test-bdd-widget-test], [test-bdd-app-running-fixture] |
| Blocs | `bloc_test` | transitions des 7 Blocs (orbe, transcript tronqué, phases de surface, rejeu) | fakes de ports | [test-bloc-test] |
| Catalogue | tests de `CatalogItem` + Widgetbook `testWidgetbook` | schéma, état squelette, état neutre sur données incomplètes, a11y | — | [genui-test-surface-controller], [ds-widgetbook-4-testing] |
| Goldens | `alchemist` | composants au thème de scène | — | [test-golden-alchemist] |
| Backend BDD | Godog + testcontainers | relais SDP, délégation → commentary + A2UI valide, A2UI hors catalogue → rejet, annulation (« Stop »), révision de tâche | faux serveur Live rejouant des fixtures sideband | [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 3 |
| Contrat A2UI | validation JSON Schema | tout message émis respecte le catalogue `genesis` et la version A2UI configurée (`a2ui.version`, `v0.9` ⚠️ selon Q-03 / E3) | — | [genui-a2ui-security] |
| Évaluations voix | CRAWL en CI, WALK/RUN en répétition | délégation, action backend, restitution du vrai résultat | TTS / enregistrements | [ma-voice-agent-evals] |

Règles : rouge → vert → refactor ([test-tdd-red-green-refactor]) ; pas de mock de classes internes ([test-mock-boundaries-only]) ; WebRTC hors des tests unitaires ([test-realtime-fake-runner]) ; les bugs de [proj-avw-risks] deviennent des tests de régression écrits d'abord.

Rédaction des `.feature` (origine : knowledge [test-bdd-gherkin-practices], section d'origine « Pour le projet multi-agents », transféré le 2026-10-28) : point de vue utilisateur, sans nommer le modèle, A2UI ni WebRTC ; la règle reste dans la note et s'applique aux scénarios de [features/](../functional/features/).

## Traçabilité scénario → exigence

Chaque scénario est étiqueté avec ses exigences (`@FR-01 @NFR-02`…) dans les fichiers `.feature` ([p-fn-requirements](../functional/requirements.md)). Un rapport CI liste les FR/NFR Must sans scénario vert.

## Mesure des NFR

| NFR | Mesure (fiche §5) | Instrumentation proposée |
|---|---|---|
| NFR-01 voix < 1 s | chronométré, 10 répétitions, p90 | fin de phrase (`end_ms` du transcript speaker) → 1er delta de transcript IA ; enregistrement audio de la salle pour contrôle |
| NFR-02 squelette < 1,5 s | horodatage du journal A2UI | `marker` fin de phrase → premier message de création de surface rendu (`createSurface` en v0.9, selon Q-03) |
| NFR-03 acte 1 < 8 s | horodatage du journal A2UI | `marker` fin de phrase → dernière mise à jour de données de la 4e surface (`updateDataModel` en v0.9, selon Q-03) |
| NFR-04 60 i/s | DevTools Performance | profil `--profile` pendant l'acte 1 ; orbe isolé sous `RepaintBoundary` ([perf-audio-visualizer-60hz], [perf-repaint-boundary]) |
| NFR-05 lisibilité | vidéoprojecteur réel | tokens scène ≥ 24 px ; contraste AA vérifié par Widgetbook ([ds-a11y-wcag-contrast]) |
| NFR-06 ≤ 6 surfaces | revue visuelle | assertion dans `CanvasBloc` ; aucun scénario de la fiche ne la couvre : scénario à ajouter si Q-63 le décide (portée de la limite : Q-04) |
| NFR-07 secours < 2 s | Wi-Fi coupé | horodatage `FallbackRequested` → 1er événement rejoué |
| NFR-08 déterminisme | snapshot des réponses d'agents | comparaison des Artifacts A2A par acte en CI |
| NFR-09 aucune clé | revue de code | scan de secrets en CI sur l'app et les assets |
| NFR-10 reproductibilité | build propre sur machine vierge | job CI « clean build » depuis `pubspec.lock` ([pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md)) |
| NFR-11 coût | tableau de bord OpenAI | `usage.seconds` de `session.closed` journalisé par répétition |
| NFR-12 raccourcis | checklist de répétition | test widget par raccourci |

Script de répétition (proposition) : lit les 10 journaux, calcule p50/p90 et taille d'échantillon ([ma-voice-agent-evals]).

## CI (proposition)

1. `very_good_analysis` + `bloc_lint` (`prefer_bloc`, aucun Cubit) ([test-very-good-analysis], [bloc-no-cubit]).
2. `build_runner` (injectable, freezed, bdd, widgetbook) puis `git diff --exit-code`.
3. `flutter test --coverage` (unit, bloc, widget, BDD) ([test-coverage-ci]).
4. `testWidgetbook` + goldens.
5. Backend : `go test -race`, Godog, validation A2UI.
6. Build desktop macOS (et Windows si le secours est confirmé) depuis le lockfile.

## Observabilité

- Backend : spans OTel `gen_ai.*` — une trace par session, `invoke_agent orchestrator` puis `execute_tool` par appel A2A ([ma-otel-genai-spans]).
- Client : `BlocObserver` journalise les events (traçabilité Bloc, [bloc-observer]).
- Pour la scène, le **journal de session** suffit à mesurer ; une stack OTel complète est optionnelle ([Q-55](../roadmap/open-questions.md)).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Point de départ des chronos** : fin de phrase vue par GPT-Live (`end_ms`) ou par l'app ; alignement des horloges client / serveur → Q-54.
- **Observabilité en scène** : OTel + SigNoz, ou journal seul → Q-55.
- **Plateforme de CI** pour le build macOS → Q-56.
- **Tests sur vrai micro et sono** (WALK/RUN) : protocole de répétition et matériel → Q-57, Q-24.
