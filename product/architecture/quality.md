---
id: p-ar-quality
title: Qualité, tests et mesure des NFR
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/013-design-ergonomie/status.md, specs/012-llm-composer-crashlist/status.md, specs/012-llm-composer-crashlist/spec.md, specs/011-voice-interaction/status.md, specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, specs/007-j3-act1-frontend/status.md, specs/007-j3-act1-frontend/plan.md, specs/006-j3-act1-backend/status.md, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p12, knowledge:test-tdd-red-green-refactor, knowledge:test-bdd-widget-test, knowledge:test-realtime-fake-runner, knowledge:ma-voice-agent-evals, knowledge:ma-otel-genai-spans]
links: [p-ar-design-system, p-fn-feature-design-ergonomics-013, pdr-0075-013-design-ergonomics-details-assistant-decided, p-ar-llm-composer, p-fn-feature-llm-composer-012, pdr-0074-012-llm-composer-gateway-crashlist-details, ma-openai-small-model-structured-latency, p-ar-voice-interruption, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, p-fn-dataset-acts, p-ar-frontend-screen, pdr-0053-client-side-a2ui-validation-from-007, p-ar-agents-protocols, p-ar-app-channel-contract, p-ar-overview, p-ar-frontend, p-ar-backend, p-ar-replay, p-ar-stage-runtime, p-ar-stack, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-rm-open-questions, pdr-0010-pinned-experimental-versions, test-tdd-red-green-refactor, test-bdd-widget-test, test-bdd-app-running-fixture, test-realtime-fake-runner, test-mock-boundaries-only, test-bloc-test, test-golden-alchemist, test-very-good-analysis, test-coverage-ci, bloc-no-cubit, bloc-observer, ma-voice-agent-evals, ma-otel-genai-spans, p-rm-backend-production-plan, ds-widgetbook-4-testing, ds-a11y-wcag-contrast, perf-audio-visualizer-60hz, perf-repaint-boundary, genui-test-surface-controller, genui-a2ui-security, proj-avw-risks, test-bdd-gherkin-practices, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0030-llm-budget-20-eur, pdr-0031-github-actions-ci-linux, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0038-latency-measured-on-app-clock, pdr-0048-session-log-only-no-otel-signoz, pdr-0049-sheet-gherkin-scenarios-only]
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
| Contrat A2UI | validation JSON Schema | tout message émis respecte le catalogue `genesis` et la version A2UI configurée (`a2ui.version`, `v0.9`, [pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)) ; **006** : contrat exécutable `contracts/a2ui/genesis/v1/` (fixtures comparées aux messages des agents, exemples passés au validateur configuré comme dans le compose, `check-compose.sh`) ; **007** : les mêmes fixtures passent le validateur Dart et le moteur genui avec le catalogue de l'app (zéro erreur moteur), `GenesisContract` égal à `catalog.json`, et les 9 **fixtures négatives partagées** `invalid/*.jsonl` + `expected.json` sont refusées avec le même code par les validateurs Go et Dart (parité) | — | [genui-a2ui-security] |
| Évaluations voix | CRAWL en CI, WALK/RUN en répétition | délégation, action backend, restitution du vrai résultat | TTS / enregistrements | [ma-voice-agent-evals] |

Règles : rouge → vert → refactor ([test-tdd-red-green-refactor]) ; pas de mock de classes internes ([test-mock-boundaries-only]) ; WebRTC hors des tests unitaires ([test-realtime-fake-runner]) ; les bugs de [proj-avw-risks] deviennent des tests de régression écrits d'abord.

Rédaction des `.feature` (origine : knowledge [test-bdd-gherkin-practices], section d'origine « Pour le projet multi-agents », transféré le 2026-10-28) : point de vue utilisateur, sans nommer le modèle, A2UI ni WebRTC ; la règle reste dans la note et s'applique aux scénarios de [features/](../functional/features/).

## Acceptation Flutter livrée par 007 (2026-10-30)

`flutter test test/acceptance/` : **24 scénarios verts**, sur le faux backend local réel qui rejoue les fixtures du contrat (aucun mock de classe interne, [test-mock-boundaries-only]) :

| Fichier | Scénarios | Vérifie |
|---|---|---|
| `acte1_creer_le_tableau.feature` | S-01 | transcription, trois agents allumés, squelette avant les données, 4 surfaces complètes (seuils 1,5 s et 8 s lus dans le journal, non assertés) |
| `acte1_ecran.feature` | A1 (×2), A2 (×3), A3, A4, A5 | rail et choix des agents, panneau replié/déplié et contour pointillé, étagère « 4 / 6 utilisés », composant hors catalogue refusé, remise à vide (le panneau reste vide malgré les `deleteSurface` du backend), état neutre (FR-03, FR-05, FR-06, FR-11, RG-10) |
| `session_voice.feature`, `loop_harness.feature` | V1 à V5bis, H-01 à H-03 | migrés sur les fixtures `genesis` **sans affaiblir d'assertion** (`findsOneWidget` conservé ; tableau avant/après dans `specs/007-j3-act1-frontend/status.md`) |

A1 à A5 sont propres à 007, hors les scénarios de la fiche, qui restent inchangés ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md)). Côté Go : acceptation G7 de la route `POST /canvas/reset` sous `-race` ([contrat](app-channel-contract.md)). Tests d'architecture du workspace : [p-ar-frontend](frontend.md).

**Test de page à 1920×1080** (`genesis_canvas_page_layout_test`, DPR 1) : quatre fixtures, panneau replié puis déplié, aucune erreur de rendu, tout texte ≥ 24 px, zones aux hauteurs du budget, contraste AA des paires du thème de scène. ⚠️ **Limite** : `flutter_test` rend le texte en police **Ahem** (chaque glyphe est un carré de la taille de la police), bien plus large que la police réelle : le test est sévère mais ne voit pas la taille de la fenêtre ni le rendu réel. La **capture `app-smoke`** (`tools/loop/app-smoke.sh`, rejeu des fixtures en police réelle) reste le contrôle visuel : sa première capture à 1280×720 (fenêtre Linux par défaut) était non conforme, d'où la fenêtre 1920×1080. L'essai réel de bout en bout avec micro reste à faire en répétition.

## Acceptation de l'acte 2 livrée par 008 (2026-10-30)

| Pile | Fichier | Vérifie |
|---|---|---|
| Go (`-tags acceptance -race`) | `backend/orchestrator/acceptance/act2_transform_test.go`, `act2_shared_canvas_test.go` | S-02 (quatre mutations par `updateDataModel` seul), correction iOS, refus honnêtes, deux délégations (Android puis comparaison), canevas partagé entre sessions (seconde session sans recréation, remise à vide sans session ouverte) |
| Go (unitaires) | `kit/scope_test.go` (`ParseIntent`, 50 cas dont les 29 de l'ancienne table), `internal/dataset`, `orchestrate/canvas_shared_test.go` | grammaire, valeurs recalculées, tests (a) à (f) du canevas sous `-race` (panique du planificateur, `Run` pendant une remise à vide, orphelins) |
| Flutter | `acte2_transformer.feature` (S-02, B1, B2, B4 ×3), `demarrage_remise_a_vide.feature` (A3 vivant / rejeu) | mutation sur place, ligne de comparaison neutre ou omise, correction vers iOS, remise à vide de démarrage |
| Contrat | fixtures `act2-*` et `correction-ios-*` | forme, rejeu après l'acte 1, invalides seules (`unknown_surface`), parité Go/Dart |

**S-07 n'est pas encore vert** (il le devient à J7) : « l'IA se tait » et l'annulation en vol sont à J7 ([pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md) D4). Capture `app-smoke act2-replay` (1920×1080) conforme après correction V1 ; **essai réel avec micro non fait**, à faire en répétition avec le porteur. Réserves de la boucle : code de `Canvas` (T14) et correction R1 écrits avant leurs tests (rouge reconstitué par mutation) ; tests de page en police Ahem (limite décrite ci-dessus).

## Acceptation de l'acte 3 livrée par 009 (2026-10-30)

| Pile | Fichier | Vérifie |
|---|---|---|
| Go (`-tags acceptance -race`) | `backend/orchestrator/acceptance/act3_interact_test.go` (+ `act3_helpers_test.go`) ; vrais agents Qualité, Voix du client et Livraison derrière l'orchestrateur, sideband factice | S-03, C1 (valider ; bloquer puis valider), C2 (barre créée dans la tâche de l'acte 2, aucune recréation, échec de `actions`), C3 (refus honnêtes 422/409/400, `busy` pendant une délégation), C4 (vrai résultat : checklist inchangée en cas d'échec, jamais « Bloquée » annoncé), C5 (voix hors délégation : commentaire nul, repli sur refus, consigne, pas de second envoi sur silence, rien après fermeture) |
| Flutter | `acte3_interagir.feature` (10 scénarios : S-03, C1 ×2, C3 ×3, C6 ×3, A1) | clic → `POST /canvas/actions` sur le faux backend, « Bloquée », réessai sur `busy`, trois états et tons de la Barre d'actions, cibles ≥ 48 px, texte ≥ 24 px, barre sous la grille (A1) |
| Contrat | fixtures `act2-actions`, `act3-block`, `act3-validate` ; quatre fixtures négatives `invalid/` (`subpath-other`, `subpath-wrong-type`, `path-empty`, `path-slash`) | forme, rejeu après les actes 1 et 2, `path_not_allowed`, parité Go/Dart |
| Unitaires | `Manager.Act` (atomique, `-race`), route (corps strict), `Announce` (politique de repli), `CanvasActionBloc` (état `Running`, réessai), `ActionBar` ; sonde T05 : mise à jour d'un sous-chemin sur genui 0.10.4 | |

- Les assertions « aucun `createSurface` » de 008 (S-02, B1, B2) sont **restreintes aux quatre surfaces de l'acte 1**, à force égale (la création de `actions` est attendue).
- **Hermétisme des polices** : `cell_height_real_fonts_test.dart` rend les cellules en polices réelles **versionnées** (Noto Sans, DejaVu Sans, ≈ 1,3 Mo ; copyright Debian, texte OFL à ajouter si redistribution), sans dépendre des polices du système ; il rougit si l'on rétablit l'écart vertical de 6 px. Il corrige la limite de la police Ahem, qui avait masqué un débordement de 2 px (capture `app-smoke` non conforme, puis conforme).
- **Porte** : `tools/loop/gate.sh --full` vert, **55 contrôles**, HEAD `ea7b2da` (un premier passage rouge pendant la refactorisation : liste fermée des codes de la fixture négative sans `path_not_allowed`, corrigée). Capture `app-smoke act3-replay` 1920×1080 conforme.
- **Essai réel unique** (2026-10-30, 15 s facturées, dépense consignée 0,03 €) : actes 1 et 2 validés en réel (délégation, `plan` des trois agents, 4 surfaces créées en 10 ms ; acte 2 : quatre `updateDataModel` et création de `actions` dans la même tâche, aucun `createSurface` sur les quatre surfaces existantes). Le clic a reçu **409 `busy`** (défaut du client d'essai : cliqué 0,03 s après la fin des agents, avant la fin du commentaire de la délégation) : **la voix n'a pas été observée, Q-75 reste ouverte**. Le client d'essai est corrigé (attend la fin réelle de la délégation, réessaie sur 409) mais la boucle d'attente de `runAct3` n'est testée que sur journaux simulés ; **non relancé** (un essai payant par fonctionnalité) : à observer en répétition avec le porteur.
- **Réserves de la boucle** : consignes de repli vocal rédigées par la boucle (texte français) ; couleurs de bordure des boutons choisies par la boucle ; libellés très longs tronqués ; limite A8 / Q-76 décrite par `TestDeliveryVoiceRequestAfterActionLosesDecision_KnownLimit`.

## Acceptation de l'interaction vocale livrée par 011 (2026-10-30)

| Pile | Fichier | Vérifie |
|---|---|---|
| Go (`-tags acceptance -race`) | `backend/orchestrator/acceptance/voice_focus_test.go` (K-01, K-02), `voice_stop_test.go` (K-03, K-04) ; agents scriptés bloquants (`startTestAgent`) pour K-03 | comparaison après focus, refus sans focus, remise à vide qui efface le focus, mot à l'offset de la délégation, « Stop » pendant deux surfaces sur quatre (annulation, deux `deleteSurface`, deux complètes intactes, `voice.interrupted`, session ouverte), « stoppé » et « bus stop » sans effet |
| Flutter | `acte_interruption.feature` (11 scénarios : K-05 ×3, K-06 ×5, K-07 ×3) | `voice.interrupted` → piste distante coupée, orbe « Interrompue » puis « Écoute », réplique tronquée, surfaces inchangées ; `canceled` → « interrompu » ; indicateur d'acte monotone ; statut entier à 1366×768 ; bouton « fait » sans nouvelle requête, réactivé après réécriture |
| Unitaires | `StopDetector` (horloge injectée), `Registry.CancelCompensation`, `manager_cancel_test.go` (`-race`, 7 cas), `OrbPhaseBloc`, `StageActReached`, faux `RtcPeer` | règles A1 à A8 de la revue du plan ([p-ar-voice-interruption](voice-interruption.md)) |

- **Porte** : `tools/loop/gate.sh --full` vert, **58 contrôles** ; capture `app-smoke` conforme. Goldens « Acte n/3 » inexistants : assertions de texte (écart acté). Les vrais agents finissent en 0 à 3 ms, donc S-06 n'est pas observable en direct (K-03 le simule).
- **Non couvert** : spike T03 (`track.enabled = false` sous `flutter_webrtc` Linux, Q-79), essai réel avec micro, S-05 sans mot d'arrêt (Q-77).

## Acceptation et mesure livrées par 012 (2026-10-31)

| Pile | Fichier | Vérifie |
|---|---|---|
| Go (`-tags acceptance -race`) | `backend/agents/acceptance/composer_llm_test.go` (le vrai binaire `agent-quality`, passerelle simulée par `httptest`) | C-01 à C-06 : plan valide = composition déterministe (NFR-08), repli à un seul appel, délai/erreur/débit, liste des crashs filtrée, sans modèle, vue indisponible |
| Go | `backend/orchestrator/acceptance/llm_gateway_test.go`, `crashlist_e2e_test.go` | C-07 (passerelle : rejets, source, débit, désactivée, journaux sans clé ni contenu), C-08 (voix → plan `[Qualité]` → `crashes` relayé, phrase `failure_rejected_view`) |
| Flutter | `acte_crashlist.feature` | F-01 (cinquième cellule, `State` conservés, étagère), F-02 (trois états, 24 px, ellipse, deux états neutres) |
| Contrat | `crashlist-global.jsonl`, `crashlist-android.jsonl` | forme, parité Go/Dart (`components` à 6) ; états neutres par tests de rendu et de builders (A8) |
| Mesure | `cmd/composer-bench` (service `composer-bench`, profil `bench`) | p50/p90 par demande, plans valides, **taux d'accord** avec le plan attendu, motifs de repli, coût estimé |

- **Résultats** : `gpt-6-luna` 25/25 plans valides, accord 100 %, p50 1,79 s, p90 2,69 s ; `gpt-6.1-terra` 24/25, p90 3,06 s ([p-ar-llm-composer](llm-composer.md), [ma-openai-small-model-structured-latency]).
- **Porte** : `tools/loop/gate.sh --full` vert, 58 contrôles, arbre propre ; captures `app-smoke` `act1-replay` (acte 1 inchangé) et `crashlist-replay` conformes à 1920×1080. Mutations vérifiées (fixture du contrat, compensation après squelette).
- **Non couvert** : essai vocal avec micro ; `check-compose.sh` et son auto-test hors de `gate.sh`/`verify.sh` (Q-84) ; lisibilité de la grille 3×2 : traitée par 013 (Q-83 tranchée).

## Acceptation, lisibilité et mesure livrées par 013 (2026-10-31)

- **Scénarios** D-01 à D-07 ([p-fn-feature-design-ergonomics-013](../functional/features/design-ergonomie-013.feature)) dans `apps/genesis_canvas/test/acceptance/acte_design_ergonomie.feature`, en **polices réelles** (`testing/real_fonts` : `loadRealFonts`, `paragraphsTruncated`, y compris la coupe verticale) et sous `TargetPlatform.linux` (cibles ≥ 48 px) ; tests unitaires : `canvas_board_rebuild_test` (reconstruction et peinture), `canvas_board_appearance_test`, `text_metrics_test`, `scene_motion_test`, `tokens_hash_test`, `tokens_parity_test`, 61 tests `testWidgetbook` ([p-ar-design-system](design-system.md)). `gate.sh --full` vert (65 contrôles) ; captures `app-smoke` 1920×1080 relues (rail de 96 px, aucun libellé tronqué, texte ≥ 24 px).
- **Mesure NFR-05** : texte ≥ 24 px et contraste AA vérifiés par tests (`scene_theme_test`, paires de la régie et de l'étagère) et captures ; projecteur réel et fond de salle : à J7 / porteur. Non couvert : essai vocal (013 ne touche pas la voix, aucun coût OpenAI).
- **Note de mesure NFR-04 (à J7)** : 013 prouve par test le **périmètre** (l'arrivée d'une surface ne reconstruit ni ne repeint ses voisines) mais **ne mesure pas les 60 i/s**. À faire en répétition : app en `--profile` sur la machine de démo, DevTools Performance pendant l'acte 1 puis la liste des crashs et un rejeu à 2× ; relever les images dépassant 16,7 ms et les images saccadées, fondus de 200 ms et de 150 ms compris.

## Traçabilité scénario → exigence

Chaque scénario est étiqueté avec ses exigences (`@FR-01 @NFR-02`…) dans les fichiers `.feature` ([p-fn-requirements](../functional/requirements.md)). Un rapport CI liste les FR/NFR Must sans scénario vert.

## Mesure des NFR

| NFR | Mesure (fiche §5) | Instrumentation proposée |
|---|---|---|
| NFR-01 voix < 1 s | chronométré, 10 répétitions, p90 | fin de phrase reçue par l'app → 1er delta de transcript IA reçu, sur l'horloge de l'app (pdr-0038) |
| NFR-02 squelette < 1,5 s | horodatage du journal A2UI | `marker` fin de phrase → premier message de création de surface rendu (`createSurface`, A2UI v0.9). **012** : le modèle (p50 1,79 s) ne tient pas ce seuil seul ; le squelette part avant l'appel ([p-ar-llm-composer](llm-composer.md)), à remesurer sur l'horloge de l'app |
| NFR-03 acte 1 < 8 s | horodatage du journal A2UI | `marker` fin de phrase → dernière mise à jour de données de la 4e surface (`updateDataModel`, A2UI v0.9). **012** : tenu (p90 du modèle 2,69 s) |
| NFR-04 60 i/s | DevTools Performance | profil `--profile` pendant l'acte 1 ; orbe isolé sous `RepaintBoundary` ([perf-audio-visualizer-60hz], [perf-repaint-boundary]) ; **013** : périmètre de reconstruction et de peinture prouvé par test, 60 i/s à mesurer à J7 (note ci-dessus) |
| NFR-05 lisibilité | vidéoprojecteur réel | tokens scène ≥ 24 px ; contraste AA vérifié par tests et captures (013) et par Widgetbook ([ds-a11y-wcag-contrast]) ; projecteur : J7 / porteur |
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

## Points ouverts (registre : [p-rm-open-questions](../roadmap/open-questions.md))

- **Point de départ des chronos** : tranché ([pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md), Q-54) : horloge monotone de l'app, sans alignement client / serveur.
- ~~Observabilité en scène~~ : tranchée, journal seul ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md), Q-55, coupe C2) ; **plateforme de CI** : tranchée ([pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md), Q-56), GitHub Actions, build Linux.
- **Tests sur vrai micro et sono** (WALK/RUN) : matériel et répétitions gérés par le porteur, hors périmètre de l'assistant (Q-57, Q-24).
