---
id: p-ar-quality
title: Qualité, tests et mesure des NFR
area: architecture
status: draft
updated: 2026-10-30
sources: [specs/006-j3-act1-backend/status.md, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p12, knowledge:test-tdd-red-green-refactor, knowledge:test-bdd-widget-test, knowledge:test-realtime-fake-runner, knowledge:ma-voice-agent-evals, knowledge:ma-otel-genai-spans]
links: [p-ar-agents-protocols, p-ar-app-channel-contract, p-ar-overview, p-ar-frontend, p-ar-backend, p-ar-replay, p-ar-stage-runtime, p-ar-stack, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-rm-open-questions, pdr-0010-pinned-experimental-versions, test-tdd-red-green-refactor, test-bdd-widget-test, test-bdd-app-running-fixture, test-realtime-fake-runner, test-mock-boundaries-only, test-bloc-test, test-golden-alchemist, test-very-good-analysis, test-coverage-ci, bloc-no-cubit, bloc-observer, ma-voice-agent-evals, ma-otel-genai-spans, p-rm-backend-production-plan, ds-widgetbook-4-testing, ds-a11y-wcag-contrast, perf-audio-visualizer-60hz, perf-repaint-boundary, genui-test-surface-controller, genui-a2ui-security, proj-avw-risks, test-bdd-gherkin-practices, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0030-llm-budget-20-eur, pdr-0031-github-actions-ci-linux, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0038-latency-measured-on-app-clock, pdr-0048-session-log-only-no-otel-signoz, pdr-0049-sheet-gherkin-scenarios-only]
tags: [qualite, tdd, bdd, gherkin, ci, nfr, mesure, observabilite]
---
# Qualité, tests et mesure des NFR

**En bref.** Les scénarios Gherkin de la fiche (§4 : 9, dont S-04 retiré, 8 actifs, [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md) et [pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md)) sont écrits **avant** le code et exécutés en automatique avec `bdd_widget_test` (client) et Godog (backend). Le TDD part de ces scénarios (outside-in). On ne double que les frontières (voix, réseau, plateforme). Les NFR sont mesurés à partir du **journal de session** sur 10 répétitions, au p90 (fiche §8, Definition of Done).

> Statut : **draft**. Stratégie proposée par l'assistant sur la base des règles d'AGENTS.md §2.

## Pyramide de tests

| Niveau | Outil | Ce qui est testé | Doublures | Source |
|---|---|---|---|---|
| Scénarios BDD client | `bdd_widget_test` 3.0.4 | les 8 scénarios actifs de [voice-screen-generation.feature](../functional/features/voice-screen-generation.feature) et [barge-in.feature](../functional/features/barge-in.feature) | `FakeVoiceSession`, `FakeSessionEventSource` (rejoue un journal) | [test-bdd-widget-test], [test-bdd-app-running-fixture] |
| Blocs | `bloc_test` | transitions des 7 Blocs (orbe, transcript tronqué, phases de surface, rejeu) | fakes de ports | [test-bloc-test] |
| Catalogue | tests de `CatalogItem` + Widgetbook `testWidgetbook` | schéma, état squelette, état neutre sur données incomplètes, a11y | — | [genui-test-surface-controller], [ds-widgetbook-4-testing] |
| Goldens | `alchemist` | composants au thème de scène | — | [test-golden-alchemist] |
| Backend BDD | Godog + testcontainers | relais SDP, délégation → commentary + A2UI valide, A2UI hors catalogue → rejet, annulation (« Stop »), révision de tâche | faux serveur Live rejouant des fixtures sideband | [p-rm-backend-production-plan](../roadmap/backend-production-plan.md) étape 3 |
| Contrat A2UI | validation JSON Schema | tout message émis respecte le catalogue `genesis` et la version A2UI configurée (`a2ui.version`, `v0.9`, [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)) ; **006** : contrat exécutable `contracts/a2ui/genesis/v1/` (fixtures comparées aux messages des agents, exemples passés au validateur configuré comme dans le compose, `check-compose.sh`) | — | [genui-a2ui-security] |
| Évaluations voix | CRAWL en CI, WALK/RUN en répétition | délégation, action backend, restitution du vrai résultat | TTS / enregistrements | [ma-voice-agent-evals] |

Règles : rouge → vert → refactor ([test-tdd-red-green-refactor]) ; pas de mock de classes internes ([test-mock-boundaries-only]) ; WebRTC hors des tests unitaires ([test-realtime-fake-runner]) ; les bugs de [proj-avw-risks] deviennent des tests de régression écrits d'abord.

Rédaction des `.feature` (origine : knowledge [test-bdd-gherkin-practices], section d'origine « Pour le projet multi-agents », transféré le 2026-10-28) : point de vue utilisateur, sans nommer le modèle, A2UI ni WebRTC ; la règle reste dans la note et s'applique aux scénarios de [features/](../functional/features/).

## Traçabilité scénario → exigence

Chaque scénario est étiqueté avec ses exigences (`@FR-01 @NFR-02`…) dans les fichiers `.feature` ([p-fn-requirements](../functional/requirements.md)). Un rapport CI liste les FR/NFR Must sans scénario vert.

## Mesure des NFR

| NFR | Mesure (fiche §5) | Instrumentation proposée |
|---|---|---|
| NFR-01 voix < 1 s | chronométré, 10 répétitions, p90 | fin de phrase reçue par l'app → 1er delta de transcript IA reçu, sur l'horloge de l'app (pdr-0038) |
| NFR-02 squelette < 1,5 s | horodatage du journal A2UI | `marker` fin de phrase → premier message de création de surface rendu (`createSurface`, A2UI v0.9) |
| NFR-03 acte 1 < 8 s | horodatage du journal A2UI | `marker` fin de phrase → dernière mise à jour de données de la 4e surface (`updateDataModel`, A2UI v0.9) |
| NFR-04 60 i/s | DevTools Performance | profil `--profile` pendant l'acte 1 ; orbe isolé sous `RepaintBoundary` ([perf-audio-visualizer-60hz], [perf-repaint-boundary]) |
| NFR-05 lisibilité | vidéoprojecteur réel | tokens scène ≥ 24 px ; contraste AA vérifié par Widgetbook ([ds-a11y-wcag-contrast]) |
| NFR-06 ≤ 6 surfaces | revue visuelle | assertion dans `CanvasBloc` ; aucun scénario de la fiche ne la couvre et aucun n'est ajouté ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md), Q-63) : l'assertion unitaire suffit (la limite porte sur les surfaces : [pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md)) |
| ~~NFR-07 secours < 2 s~~ | retirée ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | — |
| NFR-08 déterminisme | snapshot des réponses d'agents | comparaison des Artifacts A2A par acte en CI |
| NFR-09 aucune clé | revue de code | scan de secrets en CI sur l'app et les assets |
| NFR-10 reproductibilité | build propre sur machine vierge | job CI « clean build » depuis `pubspec.lock` ([pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md)) |
| NFR-11 coût | tableau de bord OpenAI | `usage.seconds` de `session.closed` journalisé par répétition ; plafond total 20 € ([pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) |
| NFR-12 raccourcis | checklist de répétition | test widget par contrôle cliquable, et par raccourci s'il existe ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |

Script de répétition (proposition) : lit les 10 journaux, calcule p50/p90 et taille d'échantillon ([ma-voice-agent-evals]).

**Premières mesures de l'acte 1 côté backend (006, essai réel unique du 2026-10-30, `gpt-live-1`, coût 0,05 €)** : `delegation` → 1er `createSurface` en 3 ms (NFR-02) et → 4ᵉ `updateDataModel` en 4 ms (NFR-03), lus dans le journal JSONL de la session. Les agents sont déterministes : ces délais ne mesurent que la chaîne orchestrateur / A2A / app-channel ; la **vraie mesure NFR-02/03 attend le petit modèle texte de composition** (Q-17 → pdr-0060, mesure en J3) et le p90 de J8. Vérifié : délégation, `plan` à 3 agents, 4 surfaces, commentaire vocal fondé sur les vrais résultats. **Non vérifié avec le vrai modèle** : la règle de délégation universelle (demande hors catalogue, RG-08), couverte par l'acceptation G2 avec les vrais agents. À surveiller en répétition : la voix a ajouté un mot parasite (« un voici ce que je constate »), paraphrase du modèle.

## CI (GitHub Actions, [pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md))

La CI est mise en place pour la montrer ; la démo tourne en debug sur le poste du porteur.

1. `very_good_analysis` + `bloc_lint` (`prefer_bloc`, aucun Cubit) ([test-very-good-analysis], [bloc-no-cubit]).
2. `build_runner` (injectable, freezed, bdd, widgetbook) puis `git diff --exit-code`.
3. `flutter test --coverage` (unit, bloc, widget, BDD) ([test-coverage-ci]).
4. `testWidgetbook` + goldens.
5. Backend : `go test -race`, Godog, validation A2UI.
6. Build desktop **Linux** depuis le lockfile, avec les dépendances système GStreamer (SP-10).

## Observabilité

- Backend : **journal de session** horodaté (une trace par session, un enregistrement par appel A2A) ; pas de spans OTel `gen_ai.*` pour la démo ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55). Référence si l'observabilité complète revient : [ma-otel-genai-spans].
- Client : `BlocObserver` journalise les events (traçabilité Bloc, [bloc-observer]).
- Pour la scène, le **journal de session** suffit à mesurer ; ni OTel ni SigNoz ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55 tranchée, coupe C2).

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Point de départ des chronos** : tranché ([pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md), Q-54) : horloge monotone de l'app, sans alignement client / serveur.
- ~~Observabilité en scène~~ : tranchée, journal seul ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55).
- **Plateforme de CI** : tranchée ([pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md), Q-56) : GitHub Actions, build Linux.
- **Tests sur vrai micro et sono** (WALK/RUN) : matériel et répétitions gérés par le porteur, hors périmètre de l'assistant (Q-57, Q-24).
