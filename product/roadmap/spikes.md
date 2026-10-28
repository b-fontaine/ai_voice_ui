---
id: p-rm-spikes
title: Spikes de levée de risque (J1)
area: roadmap
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p6-p7, product/sources/product-description.pdf#p11, product/sources/design-example.pdf#p1-p3, spikes/widgetbook4/README.md, knowledge:ds-widgetbook-4-spike, knowledge:ma-package-versions, knowledge:genui-a2ui-messages, product/roadmap/backend-production-plan.md]
links: [proto-a2a-bindings, proto-a2a-dart-sdk, pdr-0002-desktop-platform, genui-overview, p-rm-roadmap, p-rm-open-questions, p-ar-stack, p-ar-agents-protocols, p-ar-replay, p-ar-stage-runtime, p-fn-nfr, pdr-0010-pinned-experimental-versions, pdr-0012-voice-provider-openai, adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-spike, ma-package-versions, genui-a2ui-overview, genui-a2ui-messages, genui-a2a-connector, rt-gpt-live-delegation, rt-barge-in, rt-echo-cancellation, rt-latency, ma-backend-sdk-go, perf-desktop-specifics, p-rm-backend-production-plan]
tags: [spike, risques, j1, versions, latence, audio, a2ui]
---
# Spikes : répondre aux inconnues avant d'écrire le produit

**En bref.** Un spike fait (Widgetbook 4) et huit spikes à mener (SP-01 à SP-07, SP-09) au jalon J1 de [roadmap.md](roadmap.md). Chacun pose **une** question, fixe un critère de succès mesurable et une durée cible (en jours de travail, pas en dates). Le code de spike est jetable et va dans `spikes/<nom>/` ; les faits appris vont dans `knowledge/` (skill `kb-curate`) ; une décision produit qui en découle passe par `product-decide`.

## Spike fait

| Id | Question | Résultat | Sources |
|---|---|---|---|
| SP-00 Widgetbook 4 | Widgetbook 4.0.0-beta.14 tient-il sous Flutter 3.47.8 avec un DS `material_ui`, dans un pub workspace ? | ✅ Oui, avec cinq contournements obligatoires (`appBuilder` material_ui, imports dans `*.stories.dart`, marge de 8 px, règles a11y desktop 24 px, scénarios Light/Dark explicites). `testWidgetbook` ne tourne que sur la VM. **Non testé :** GenUI (`CachedSurface`), macOS, Windows. | `spikes/widgetbook4/`, [ds-widgetbook-4-spike], [adr-0008-ds-widgetbook-4-beta] |

Suivi de SP-00 (origine : knowledge [adr-0008-ds-widgetbook-4-beta], contexte d'origine, transféré le 2026-10-28) : surveiller la sortie de la 4.0.0 stable, ou une bêta bloquante avant la date du talk ; repli prévu sur la 3.25.0 ([stack.md](../architecture/stack.md)).

## Spikes à mener (J1)

| Id | Question | Critère de succès | Durée cible | Exigences / questions | Notes knowledge |
|---|---|---|---|---|---|
| **SP-01** Versions genui / A2UI | Quelles versions de `genui`, `genui_a2a` et `a2ui_core` sont réellement publiées et compatibles **aujourd'hui** ? Quelle version d'A2UI parlent-elles ? Que deviennent les messages v0.8 des maquettes (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`) ? | Un projet Flutter desktop vide résout les versions retenues ; une surface reçoit un flux A2UI écrit à la main et s'affiche ; tableau « message de la maquette → message réellement accepté » produit pour alimenter Q-03 (sans trancher) | 1 j | NFR-10 ; Q-03, Q-25 | [ma-package-versions], [genui-a2ui-overview], [genui-a2ui-messages], [genui-a2ui-v1-rc], [genui-catalog-ids] |
| **SP-02** gpt-live-1 : barge-in et délégation | Avec `gpt-live-1` en WebRTC sur desktop, en français : le barge-in est-il immédiat, la délégation `client` permet-elle de commenter pendant la construction, et comment annuler le travail backend après « stop » ? | Mesures sur 10 essais : coupure de la voix perçue immédiate ; `commentary.append` dit pendant une délégation ; annulation confirmée avant annonce ; transcription tronquée exploitable (FR-19) ; compréhension du français jugée correcte | 2 j | FR-13, FR-14, FR-16, FR-19, NFR-01, NFR-09 ; Q-11, Q-26 | [rt-gpt-live-overview], [rt-gpt-live-delegation], [rt-gpt-live-sideband], [rt-barge-in], [rt-ephemeral-keys], [ma-filler-acknowledgements] |
| **SP-03** A2A en Go ↔ `genui_a2a` | Un agent écrit avec `a2a-go` v2 peut-il streamer des parts A2UI vers `genui_a2a` (JSON-RPC `message/stream` sur SSE, en-tête `X-A2A-Extensions`) ? | Un agent Go minimal renvoie une surface rendue par l'app ; une action utilisateur revient à l'agent ; ordre des messages garanti ; **version A2A parlée par `genui_a2a` établie** (`message/stream` = nommage v0.3, alors qu'a2a-go v2 implémente la v1.0 en PascalCase, `SendStreamingMessage`) et recours à la couche `a2acompat` d'a2a-go vérifié si besoin | 1,5 j | FR-03, FR-08 ; Q-15, Q-16, Q-39 | [ma-backend-sdk-go], [genui-a2a-connector], [proto-a2a-overview], [proto-a2a-streaming-push], [genui-user-actions], [proto-a2a-bindings], [proto-a2a-dart-sdk] |
| **SP-04** Latence de la chaîne complète | La chaîne voix → délégation → orchestrateur → agents → A2UI → rendu peut-elle tenir NFR-02 (squelette < 1,5 s) et NFR-03 (acte 1 < 8 s) ? Quel LLM pour les agents ? | Journal horodaté de bout en bout ; p50 et p90 sur 10 essais ; décomposition par saut ; seuils tenus ou écart chiffré | 2 j | NFR-01, NFR-02, NFR-03, NFR-11 ; Q-15, Q-17 | [rt-latency], [ma-filler-acknowledgements], [ma-otel-genai-spans], [ma-voice-agent-evals], [ma-workflow-patterns] |
| **SP-05** Enregistrement et rejeu du flux A2UI | Peut-on enregistrer le flux A2UI horodaté (et ce qu'il faut de voix et de transcription) puis le rejouer de 0,25× à 2× dans le même `SurfaceController`, hors réseau ? | Rejeu de l'acte 1 identique au direct (comparaison de captures) ; changement de vitesse et recul ; bascule < 2 s sans redémarrer l'app | 1,5 j | FR-09, FR-10, NFR-07, NFR-08 ; Q-18 | [genui-architecture], [genui-a2ui-messages], [genui-test-surface-controller], [test-realtime-fake-runner] |
| **SP-06** Routage audio, sono et AEC sur macOS | Sur la machine de démo, avec micro-casque et sortie vers la sono, l'IA s'auto-interrompt-elle ? Quel réglage (AEC WebRTC, seuil, périphériques) donne un barge-in 10/10 ? | 10 coupures sur 10 sono allumée ; aucune auto-interruption sur 5 min de parole de l'IA ; applaudissements d'1 s sans effet (FR-18) | 1,5 j | FR-13, FR-18, FR-20 ; Q-07, Q-14 | [rt-echo-cancellation], [rt-flutter-webrtc-audio-routing], [rt-barge-in], [perf-desktop-specifics], [proj-avw-risks] |
| **SP-07** Rendu desktop 1920×1080 | Un écran en 6 zones tient-il en 1920×1080 avec du texte ≥ 24 px, un contraste WCAG AA et 60 i/s pendant les apparitions ? | Maquette Flutter des 6 zones avec 6 surfaces factices ; DevTools en mode profile sans jank ; lecture validée sur un vrai projecteur | 1,5 j | NFR-04, NFR-05, NFR-06 ; Q-02, Q-04, Q-07 | [perf-desktop-specifics], [perf-repaint-boundary], [ds-a11y-wcag-contrast], [ds-typography], [ux-desktop-adaptive-layout] |
| **SP-09** Secours Windows desktop | La chaîne cliente tient-elle sous Windows (secours prévu par [pdr-0002](../decisions/pdr-0002-desktop-platform.md)) alors que pub.dev ne liste pas Windows pour `genui` et `genui_a2a` ? | Sur une machine Windows : build release propre ; une surface A2UI rendue par `genui` (et `genui_a2a` si retenu, Q-39) ; session WebRTC `flutter_webrtc` établie ; barge-in 10/10 avec AEC, sortie vers enceinte ; résultat écrit ✅/❌/⚠️ versé dans Q-45 | 1,5 j | NFR-04, NFR-10, FR-13 ; Q-07, Q-45 | [genui-overview], [proto-a2a-dart-sdk], [rt-echo-cancellation], [rt-flutter-webrtc-audio-routing], [perf-desktop-specifics] |

Total cible : environ 12,5 jours de travail, parallélisables en partie (SP-01 et SP-03 d'un côté, SP-02 et SP-06 de l'autre ; SP-09 après SP-01).

## Spike optionnel

| Id | Question | Critère de succès | Durée cible | Notes |
|---|---|---|---|---|
| SP-08 Widgetbook × GenUI | Les composants du catalogue s'affichent-ils dans Widgetbook 4 avec leurs états (squelette, données incomplètes, complet) ? | Une story par état pour un composant du catalogue | 0,5 j | Point « non testé » de [ds-widgetbook-4-spike] ; [ds-widgetbook-4-genui] |

## Règles

- Un spike sans critère de succès chiffré n'est pas lancé.
- Un résultat négatif est un résultat : il est consigné, puis la question ouverte correspondante est mise à jour dans [open-questions.md](open-questions.md).
- Les versions trouvées en SP-01 alimentent le pinning de [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md) et le tableau de [p-ar-stack](../architecture/stack.md).
- SP-02 ne confirme pas à lui seul [pdr-0012](../decisions/pdr-0012-voice-provider-openai.md) : la décision reste au porteur (Q-11).
