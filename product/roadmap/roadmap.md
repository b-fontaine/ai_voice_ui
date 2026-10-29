---
id: p-rm-roadmap
title: Roadmap de Genesis Canvas, du cadrage au talk et au-delà
area: roadmap
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1-p12, product/sources/design-example.pdf#p1-p3, product/roadmap/backend-production-plan.md, knowledge:ds-widgetbook-4-spike, spikes/widgetbook4/README.md]
links: [pdr-0041-backend-in-this-repo-local-no-auth, pdr-0042-calendar-and-cut-order-validated, pdr-0043-light-spec-kit-sdd-template, rt-ephemeral-keys, p-fn-business-rules, p-rm-backlog, p-rm-spikes, p-rm-open-questions, p-rm-beyond, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-ar-overview, p-ar-replay, p-ar-stage-runtime, pdr-0001-conference-demo-deliverable, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, pdr-0010-pinned-experimental-versions, pdr-0011-adopt-knowledge-adrs, pdr-0012-voice-provider-openai, p-rm-backend-production-plan, adr-0008-ds-widgetbook-4-beta, proto-stack-recommendation, adr-0002-orchestrator-backend, ma-target-architecture, ma-where-to-run-agents, p-ar-backend, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0020-act1-four-surfaces, pdr-0021-mockup-data-not-corrected, pdr-0022-gherkin-steps-no-leading-digit, pdr-0023-example-guided-composition, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0026-desktop-only-target, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0031-github-actions-ci-linux, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0034-app-name-release-copilot, pdr-0035-no-third-party-agent, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0037-voice-brise-delegated-instructions, pdr-0038-latency-measured-on-app-clock, pdr-0039-component-voice-interactions-via-fr07, pdr-0040-reference-dataset-adjusted-by-assistant, pdr-0044-di-deferred-to-j2, pdr-0045-app-backend-channel-wss-recommended, pdr-0046-flutter-3-47-8-pinned, pdr-0047-go-and-tool-versions-pinned, pdr-0048-session-log-only-no-otel-signoz, pdr-0049-sheet-gherkin-scenarios-only, pdr-0050-gpt-live-client-delegation-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended]
tags: [roadmap, jalons, mvp, talk, planification, calendrier, gel, coupe]
---
# Roadmap : de la fiche produit au talk, puis au-delà

**En bref.** Replanification du 2026-10-29 sur la date réelle : talk de 45 min au Meetup Flutter Nantes le **jeudi 2026-11-12** ([pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)), soit **14 jours**. Les jalons J1 à J8 sont **datés** : 12 jours de construction (jeu. 29/10 → lun. 9/11), puis **2 jours de gel** (mar. 10/11 et mer. 11/11). Les spikes sont réduits au strict nécessaire (SP-10 en premier). Le calendrier, la capacité supposée et l'ordre de coupe C1 à C5 sont **validés par le porteur le 2026-10-29** ([pdr-0042](../decisions/pdr-0042-calendar-and-cut-order-validated.md), Q-65 tranchée) ; C6 à C10 restent soumis à sa décision. La logistique et les supports du talk (salle, son, répétitions, vidéo de secours) sont gérés par le porteur, hors périmètre de l'assistant ; slides : sur demande du porteur.

## Point de départ (état du dépôt au 2026-10-29)

| Élément | État | Source |
|---|---|---|
| Base `knowledge/`, ADR adr-0001 à adr-0008, dossier `product/` (PDR 0001-0049) | Présents ; J0 en relecture par le porteur | `knowledge/index.yaml`, [decisions/](../decisions/index.yaml) |
| Spike Widgetbook 4.0.0-beta.14 | Fait, vérifié | [ds-widgetbook-4-spike], `spikes/widgetbook4/` |
| Machine de démo Linux : `flutter_webrtc` 1.6.3 | ✅ vérifié le 2026-10-29 | [pdr-0028](../decisions/pdr-0028-linux-demo-machine.md) |
| Machine de démo Linux : `genui` 0.10.4 | ✅ rendu A2UI v0.9 confirmé le 2026-10-29 après installation de GStreamer (SP-10) | [pdr-0028](../decisions/pdr-0028-linux-demo-machine.md) |
| Code applicatif (app Flutter, backend Go, agents) | **Aucun** | `git log` |

## Calendrier daté (validé par le porteur le 2026-10-29 : pdr-0042)

✅ Calendrier accepté tel quel ([pdr-0042](../decisions/pdr-0042-calendar-and-cut-order-validated.md)) : il compte **tous les jours**, week-ends compris (en jours ouvrés seulement, 8 jours avant le gel, soit 4 de moins). Les fériés n'y changent rien : le 1/11 tombe un dimanche et le 11/11 est dans le gel.

| Jalon | Dates | Jours | Contenu resserré | Critère de sortie (point de contrôle le soir du dernier jour) |
|---|---|---|---|---|
| J1 Spikes réduits | jeu. 29/10 → ven. 30/10 | 2 | 29/10 : **SP-10** (+ SP-01). 30/10 : **SP-03** le matin, **SP-02 réduit** l'après-midi ; les autres spikes sont absorbés dans les jalons ([spikes.md](spikes.md)) | SP-10 ✅ ou décision MacBook du porteur le 30/10 ; SP-03 et SP-02 consignés ; Q-25, Q-39, Q-46 tranchées le 2026-10-29 (pdr-0046, pdr-0045, pdr-0047) ; Q-43 et Q-47 tranchées le 2026-10-29 (pdr-0051, pdr-0050) |
| J2 Walking skeleton | sam. 31/10 → dim. 1/11 | 2 | 31/10 : `app/di` get_it + injectable ([pdr-0044](../decisions/pdr-0044-di-deferred-to-j2.md)), relais SDP Go, orchestrateur, 1 agent A2A, `docker-compose.yaml`, app Linux + orbe + 1 surface. 1/11 : journal horodaté (horloge de l'app, [pdr-0038](../decisions/pdr-0038-latency-measured-on-app-clock.md)), scénario BDD, CI minimale, `pubspec.lock` | « Une phrase → une surface » en réel et en BDD ; `docker compose up` démarre tout ; 1ʳᵉ mesure de latence (ex-SP-04) |
| J3 Acte 1 « Créer » | lun. 2/11 → mer. 4/11 | 3 | Catalogue 6 composants + thème de scène (ex-SP-07), 3 agents réels producteurs d'A2UI ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)), jeu de données ([pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)), rail, panneau protocole, étagère, remise à vide, instructions vocales v1 ([pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)) | Scénario « Acte 1 » vert ; 4 surfaces < 8 s (indicatif) ; RG-08 et RG-10 démontrés |
| J4 Acte 2 « Transformer » | jeu. 5/11 | 1 | Mutation sur place, filtre Android ([pdr-0024](../decisions/pdr-0024-act2-android-only.md)) | Scénario « Acte 2 » vert ; aucune surface recréée dans le journal |
| J5 Acte 3 « Interagir » | ven. 6/11 | 1 | Clic → agent Livraison → vrai résultat → voix | Scénario « Acte 3 » vert ; vrai résultat d'outil dit à la voix |
| J6 Rejeu A2UI (acte 4) | sam. 7/11 | 1 | Enregistrement du flux A2UI seul, lecture 0,25×-2× (ex-SP-05, [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | Rejeu de l'acte 1 identique au direct, Wi-Fi coupé |
| J7 Durcissement | dim. 8/11 → lun. 9/11 | 2 | Barge-in, « stop », AEC sous Linux avec enceinte (ex-SP-06), 60 i/s, lisibilité 24 px ; **fin du développement le 9/11 au soir** | 5 scénarios « Couper la parole » verts ; barge-in 10/10 sur enceinte ; DevTools 60 i/s |
| J8 **Gel** et DoD | mar. 10/11 → mer. 11/11 | 2 | Correctifs bloquants seulement, aucune fonctionnalité ; p90 depuis les journaux ; CI verte ; bilan budget 20 € | DoD côté assistant cochée ; version figée remise au porteur le 11/11 au soir |
| J9 Talk | jeu. 12/11 | — | Démo ; choix direct / vidéo : géré par le porteur | — |

Marge : les **2 jours de gel** (10-11/11) ; aucune marge entre J1 et J7. Tout glissement d'un jour se paie par une coupe (ci-dessous), jamais par le gel.

## Mode de développement : boucle autonome

Le développement est mené par la **boucle autonome** décrite dans `tools/loop/README.md` et `.claude/skills/dev-loop/SKILL.md` ([pdr-0043](../decisions/pdr-0043-light-spec-kit-sdd-template.md)) :
- worktree `../ai_voice_ui-loop`, branche `loop` ; le porteur récupère le travail par `git pull` sur `main` ;
- une fonctionnalité = un dossier `specs/NNN-<slug>/` (spec, plan, tasks, status) ; avancement dans `specs/progress.md` ;
- ordre : `specs/000-loop-harness` (squelette de l'app + mode capture ; **terminée le 2026-10-29**, voir `specs/progress.md`), puis les spikes SP-03 et SP-02 restants, puis J2 ;
- le code du backend vit dans ce dépôt, sous `backend/` ([pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md)).

## Jalons (contenu détaillé et dépendances)

| Jalon | Taille | Objectif | Contenu | Exigences couvertes | Critère de sortie vérifiable | Dépend de | Risques principaux |
|---|---|---|---|---|---|---|---|
| **J0** Cadrage et docs (en cours, relecture porteur en parallèle) | S | Vision partagée | Base `knowledge/`, spike Widgetbook, dossier `product/`, PDR 0001-0049 | — | `product_lint.py` sans erreur ; questions listées | — | Relecture qui rouvre une décision |
| **J1** Spikes réduits — 29-30/10 | S | Lever les seules inconnues bloquantes | SP-10 (+ SP-01), SP-03, SP-02 réduit ; SP-04 à SP-07 absorbés dans J2, J3, J6, J7 ; SP-08 coupé (C1) ; SP-09 sans objet | Prépare NFR-01, NFR-10 | Chaque spike a un résultat écrit (✅/❌/⚠️) ; faits versés dans `knowledge/` | J0 ; aucune question ouverte ; levées : Q-07 (→ pdr-0028), Q-45 (sans objet → pdr-0028), Q-64 (→ pdr-0026) | SP-10 ❌ (MacBook) ; SP-03 ❌ (canal maison, Q-39) |
| **J2** Walking skeleton — 31/10-1/11 | M | Prouver la chaîne complète, au plus mince | App Linux + orbe ; relais SDP backend Go, aucune clé dans l'app ([pdr-0012](../decisions/pdr-0012-voice-provider-openai.md), [rt-ephemeral-keys]) ; orchestrateur → 1 agent A2A → 1 surface ; compose ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)) ; délégation GPT-Live `client` ([pdr-0050](../decisions/pdr-0050-gpt-live-client-delegation-recommended.md)) ; niveau d'orbe = RMS de la copie sideband poussé à 5 Hz par le backend ([pdr-0051](../decisions/pdr-0051-orb-level-from-sideband-rms-recommended.md)) ; journal horodaté ; CI minimale ([pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md)) | FR-01, FR-02 (partiel), FR-04 (1 surface), NFR-09, NFR-10 ; instrumentation NFR-01/02/11 | Scénario « une phrase → une surface » vert en CI (fournisseurs simulés) et en réel ; aucune clé dans l'app ; `pubspec.lock` committé | J1 ; aucune question ouverte ; levées : Q-03, Q-09, Q-11, Q-15, Q-16, Q-25 (→ pdr-0046), Q-27, Q-29, Q-34, Q-37, Q-39 (→ pdr-0045), Q-43 (→ pdr-0051), Q-46 (→ pdr-0047), Q-47 (→ pdr-0050), Q-48, Q-54, Q-55 (→ pdr-0048), Q-56, Q-63 (→ pdr-0049) | `genui_a2a` (A2A v0.3) ↔ `a2a-go` v2 (v1.0) |
| **J3** Acte 1 « Créer » — 2-4/11 | L | « Prépare la release 3.4 » construit le tableau | 3 agents réels, chacun producteur de son A2UI ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md)) ; catalogue ; 4 surfaces ([pdr-0020](../decisions/pdr-0020-act1-four-surfaces.md)) ; rail ; panneau protocole ; étagère ; jeu de données ; remise à vide ; refus hors catalogue (RG-08) ; état neutre (RG-10) ; exemples d'écrans ([pdr-0023](../decisions/pdr-0023-example-guided-composition.md)) | FR-02, FR-03, FR-04, FR-05, FR-06, FR-11, NFR-02, NFR-03, NFR-06, NFR-08 | Scénario « Acte 1 » vert ; 1er squelette < 1,5 s, 4 surfaces < 8 s (indicatif, p90 en J8) ; RG-08 et RG-10 démontrés | J2 ; **ouvertes : Q-17, Q-22, Q-30, Q-31, Q-35, Q-44** ; levées : Q-53 (→ pdr-0052, une session GPT-Live par acte), Q-66 (→ pdr-0044), Q-01, Q-02, Q-04, Q-08, Q-10, Q-23, Q-28, Q-33, Q-38, Q-59, Q-60, Q-61 | Latence de 3 agents LLM ; écran incohérent |
| **J4** Acte 2 « Transformer » — 5/11 | M | Les surfaces mutent sur place | Mise à jour des composants et du data model ; filtre Android ; comparaison 3.3 ↔ 3.4 (coupable, C8) ; correction en cours (coupable, C7) | FR-07, FR-17 | Scénario « Acte 2 » vert (et « Corriger la demande » si non coupé) ; aucune surface recréée | J3 ; **ouvertes : Q-20, Q-21, Q-32** ; levée : Q-58 (→ pdr-0024) | Régénération complète par le LLM |
| **J5** Acte 3 « Interagir » — 6/11 | M | Un clic repart vers l'agent, qui répond à la voix | Action A2UI → orchestrateur → agent Livraison → vrai résultat → voix + checklist | FR-08 | Scénario « Acte 3 » vert ; vrai résultat d'outil ([ma-real-tool-results]) | J3 ; **ouverte : Q-49** ; Q-20 (échéance J4) ; levée : Q-62 (→ pdr-0016) | Faux `{"status":"ok"}` ([proj-avw-risks]) |
| **J6** Rejeu A2UI (acte 4) — 7/11 | S | Rejouer l'acte 1 au ralenti, sans réseau ni LLM | Enregistrement du flux A2UI seul ; lecture, pause, vitesse 0,25×-2× ; panneau protocole synchronisé ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | FR-09 | Rejeu de l'acte 1 identique au direct, Wi-Fi coupé ; vitesse fonctionnelle | J3 ; **ouverte : Q-52** (pas-à-pas, reco : aucun, à confirmer) ; levées : Q-18, Q-36 (→ pdr-0032) ; sans objet : Q-50, Q-51 | Rejeu non déterministe |
| **J7** Durcissement — 8-9/11 | M | Tenir en salle | Barge-in, « stop », faire-taire, micro coupé ; AEC Linux sur enceinte ; 60 i/s ; 24 px ; souris d'abord ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) ; instructions vocales réglées ([pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md)) ; phrases de test des scénarios BDD par acte (parade R5 côté app ; script du speaker : sur demande du porteur) | FR-12 à FR-16, FR-18, FR-19, FR-20, NFR-01, NFR-04, NFR-05, NFR-12 | 5 scénarios « Couper la parole » verts ; barge-in 10/10 sur enceinte ; DevTools 60 i/s | J4, J5, J6 ; **ouvertes : Q-40, Q-41, Q-42, Q-67** (délai d'arrêt de la voix après interruption, FR-13 ; mesure d'abord) ; levées : Q-05 (→ pdr-0033), Q-26 (→ pdr-0037) ; Q-57 gérée par le porteur | Auto-interruption par la sono (test final : porteur) |
| **J8** Gel et DoD — 10-11/11 | S | Figer une version sûre | Correctifs bloquants seulement ; p90 depuis les journaux ; CI verte ; bilan budget. Répétitions : gérées par le porteur, hors périmètre de l'assistant | NFR-11 (20 €, [pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) ; vérification de toutes les exigences | Critères DoD de [p-fn-risks-acceptance](../functional/risks-acceptance.md) côté assistant cochés (D4 retiré, pdr-0032) | J7 ; levées : Q-06 (→ pdr-0027), Q-13 (→ pdr-0030), Q-19 (→ pdr-0032) ; gérées par le porteur : Q-14, Q-24 | Correctif tardif qui casse la démo |
| **J9** Talk — **jeu. 2026-11-12**, Meetup Flutter Nantes, 45 min | S | 3 actes en direct, puis le rejeu (acte 4) | Installation, son, choix direct / vidéo OBS : gérés par le porteur, hors périmètre de l'assistant ; slides : sur demande du porteur | — | Métriques de succès de la fiche § 8 | J8 ; levée : Q-12 (→ pdr-0027) | Réseau de la salle |
| **Au-delà** | — | Prolonger la démo | Voir [beyond.md](beyond.md) | Hors MVP | Un PDR avant tout travail | J9 | Dérive de périmètre avant le talk |

## Ordre de coupe (validé pour C1 à C5 le 2026-10-29 : pdr-0042)

Du **moins** au **plus** essentiel. Déclencheur : un point de contrôle du calendrier manqué → couper dans l'ordre jusqu'à rattraper le retard. **C1 à C5 : validées, à appliquer dans cet ordre sans redemander** ([pdr-0042](../decisions/pdr-0042-calendar-and-cut-order-validated.md)). **C6 à C10** touchent des exigences de la fiche : décision du porteur au cas par cas, par une PDR (`product-decide`), avant d'être appliquées.

| Ordre | Coupe proposée | Gain estimé | Touche |
|---|---|---|---|
| C1 | SP-08 (Widgetbook × GenUI) et stories Widgetbook au-delà d'un état par composant | 0,5 j | outillage |
| C2 | OTel + SigNoz : journal seul (Q-55) — **appliquée d'emblée** ([pdr-0048](../decisions/pdr-0048-session-log-only-no-otel-signoz.md)) | 0,5 j | observabilité |
| C3 | CI réduite à analyse + tests + build Linux (ni goldens ni `testWidgetbook`) | 0,5 j | [pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md) |
| C4 | Pas de scénario Gherkin au-delà des 9 de la fiche (Q-63) ; revue visuelle — **appliquée d'emblée** ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md)) | 0,5 j | Q-63 |
| C5 | Raccourcis clavier : souris seule (déjà facultatifs, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) | 0,5 j | FR-11, FR-20, NFR-12 assouplies |
| C6 | Should de J7 : FR-18 (bruit court) en simple réglage, FR-12 (couper le micro) retirée | 0,5 j | FR-12, FR-18 (Should) |
| C7 | Should : FR-17 (correction en cours de génération) et FR-06 (étagère allumée, étagère statique) | 0,5-1 j | FR-06, FR-17 (Should) |
| C8 | Acte 2 réduit au filtre Android, sans comparaison 3.3 ↔ 3.4 (Q-32) | 0,5 j | FR-07 (Must) gardée |
| C9 | Rejeu réduit : lecture, pause, 0,5× et 1× seulement | 0,5 j | FR-09 (Must) partielle |
| C10 | Acte 3 réduit : « Bloquer » seul, « Valider » affichée inactive ([pdr-0016](../decisions/pdr-0016-validate-release-action.md)) | 0,5 j | FR-08 (Must) gardée |

**Jamais coupés** : acte 1 complet avec agents A2A réels, voix GPT-Live, barge-in et « stop » (FR-13, FR-16), aucune clé dans l'app (NFR-09), versions figées (NFR-10), rejeu de l'acte 1 sous une forme minimale.

## Risques de délai

| Id | Risque | Détecté au plus tard | Effet sur le calendrier | Parade |
|---|---|---|---|---|
| RD-1 | `genui` ne rend pas sous Linux malgré GStreamer (SP-10) | jeu. 29/10 soir | − 1 à 2 j (bascule MacBook) | Levé le 2026-10-29 (SP-10 ✅) |
| RD-2 | `genui_a2a` (A2A v0.3) incompatible avec `a2a-go` v2 (v1.0) (SP-03) | ven. 30/10 midi | + 1 j | Levé le 2026-10-29 (SP-03 ✅) ; canal WSS maison retenu ([pdr-0045](../decisions/pdr-0045-app-backend-channel-wss-recommended.md)) |
| RD-3 | Questions ouvertes non tranchées à temps : 0 avant J2 (Q-43 et Q-47 tranchées le 29/10 : pdr-0051, pdr-0050), 6 avant J3 (2/11 ; Q-53 tranchée : pdr-0052), 3 avant J4 (5/11) | 30/10, 1/11, 4/11 | jalon bloqué (règle 1) | Recommandations de l'assistant prêtes la veille de chaque échéance |
| RD-4 | Capacité : 12 jours consécutifs supposés, week-ends compris (Q-65) | 29/10 | − 4 j si jours ouvrés seulement (8 au lieu de 12) | Couper C1 à C7 d'emblée |
| RD-5 | Latence de 3 agents LLM réels au-delà de NFR-03 (8 s) | 1/11 (1ʳᵉ mesure J2) | + 0,5 à 1 j | LLM rapide (Q-17), exemples d'écrans ([pdr-0023](../decisions/pdr-0023-example-guided-composition.md)) ; réexamen de [pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md) |
| RD-6 | Auto-interruption par l'enceinte découverte tard | 30/10 (essai sur enceinte en SP-02) | + 1 j en J7 | Essai précoce fait le 2026-10-29 (SP-02) : aucune auto-interruption observée sur 60 s dans le navigateur (AEC activée, enceintes du PC) ; limites : `flutter_webrtc` sous Linux et sono de la salle non testés (SP-06 en J7, test sono géré par le porteur) |
| RD-7 | Budget 20 € entamé par le développement | suivi quotidien du journal | arrêt des essais réels | Fournisseurs simulés en tests ; plafond `limits.budget` (proposition) |
| RD-8 | Bogue bloquant d'une bêta (genui 0.10.4, Widgetbook 4) | n'importe quand | + 0,5 à 1 j | Versions figées ([pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md)) ; repli Widgetbook 3.25.0 |

## Règles de pilotage

1. **Pas de jalon commencé avec une question bloquante ouverte.** La source de vérité est l'**échéance** de chaque question dans [open-questions.md](open-questions.md) (« Avant Jn », avec sa date) ; la colonne « Dépend de » la reprend et `product_lint.py` le vérifie. Elles se tranchent via `product-decide`.
2. **TDD + BDD d'abord** : les scénarios de [functional/features/](../functional/features/) sont écrits et rouges avant le code ([test-tdd-red-green-refactor], adr-0001 via [pdr-0011](../decisions/pdr-0011-adopt-knowledge-adrs.md)).
3. **Mesurer tôt** : le journal A2UI horodaté existe dès J2 (fiche § 5).
4. **Gel le 10/11** : après le lun. 9/11 au soir, aucune fonctionnalité ; un retard se règle par l'ordre de coupe, pas en entamant le gel.
5. **Le rejeu reste Must** (FR-09, acte 4, [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) ; le secours vidéo est géré par le porteur, hors périmètre de l'assistant.
6. **Rien de l'Au-delà avant J9**, sauf décision explicite du porteur (agent tiers écarté : pdr-0035).

## Correspondance avec le plan backend de production

Le plan [p-rm-backend-production-plan](backend-production-plan.md) (statut `draft` ; ex-note `ma-backend-phase1-plan` de `knowledge/`, transférée le 2026-10-28) vise un produit Septeo (Keycloak, Kong, Temporal, MCP gateway). Il **n'est pas appliqué à la démo**, remplacée par un déploiement local `docker compose` ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)). Ses étapes restent une référence technique ; les étapes 9 à 12 relèvent de l'[Au-delà](beyond.md).

## Phasage protocolaire d'origine

Origine : knowledge [proto-stack-recommendation] (ex-titre « Stack protocolaire (décision interne, 2026-10-27) », passages propres au projet transférés le 2026-10-28 ; la note garde la version générique). Les « phases » ci-dessous sont celles de la note d'origine, distinctes des jalons J0-J9 :

- La complexité multi-agents va dans un orchestrateur backend **dès la phase 1** (décision du 2026-10-27, [adr-0002-orchestrator-backend] ; [ma-target-architecture], [ma-where-to-run-agents]).
- **Phase 1 : orchestrateur backend minimal** : sessions voix / jetons éphémères, outil vocal unique `delegate`, agent GenUI (A2UI validé contre le catalogue), outils métier en MCP ; WebRTC app ↔ GPT-Live (`flutter_webrtc`) ou WebSocket app ↔ Gemini Live (`firebase_ai`) ; canal app ↔ backend WebSocket/SSE (ou `genui_a2a`) ; outils client locaux et sans secret uniquement ; **pas d'A2A vers des agents tiers ni d'AG-UI en phase 1**.
- **Phase 2 : ouverture** : A2A vers des agents spécialisés (SDK officiel Python, Go ou Java en v1.0) ; AG-UI (`ag_ui`) si le canal doit transporter plus que de l'A2UI ; média vocal toujours en WebRTC direct.
- **Critères de passage en phase 2** : plusieurs clients (web, mobile, desktop) partageant les agents ; secrets ou clés tierces hors de l'app ; tâches longues avec push (FCM) en arrière-plan.

Le produit utilise des agents A2A **réels** dès le MVP ([pdr-0036](../decisions/pdr-0036-real-a2a-agents-produce-a2ui.md), fiche § 1), alors que ce phasage d'origine les plaçait en phase 2 ; pas d'agent d'un autre éditeur ([pdr-0035](../decisions/pdr-0035-no-third-party-agent.md)).
