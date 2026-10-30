---
id: p-rm-backlog
title: Backlog par epics et couverture des exigences
area: roadmap
status: draft
updated: 2026-10-30
sources: [specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, specs/007-j3-act1-frontend/status.md, specs/006-j3-act1-backend/status.md, specs/005-j2-app-voice-orb/status.md, product/sources/product-description.pdf#p3-p7, product/sources/product-description.pdf#p11-p12]
links: [pdr-0069-voice-interruption-hybrid-stop-011, pdr-0070-llm-composer-and-crashlist-012, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0072-design-ergonomics-013, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0058-backend-canvas-registry-survives-voice-sessions, p-fn-dataset-acts, pdr-0041-backend-in-this-repo-local-no-auth, pdr-0042-calendar-and-cut-order-validated, pdr-0043-light-spec-kit-sdd-template, pdr-0027-talk-context-meetup-flutter-nantes, p-fn-business-rules, pdr-0012-voice-provider-openai, rt-ephemeral-keys, p-rm-roadmap, p-rm-open-questions, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-dataset, p-ar-overview, p-ar-replay, p-ar-quality, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0031-github-actions-ci-linux, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0037-voice-brise-delegated-instructions, pdr-0040-reference-dataset-adjusted-by-assistant, pdr-0045-app-backend-channel-wss-recommended, pdr-0046-flutter-3-47-8-pinned, pdr-0047-go-and-tool-versions-pinned, pdr-0048-session-log-only-no-otel-signoz, pdr-0049-sheet-gherkin-scenarios-only, pdr-0050-gpt-live-client-delegation-recommended, pdr-0051-orb-level-from-sideband-rms-recommended, pdr-0052-one-gpt-live-session-per-act-recommended]
tags: [backlog, epics, moscow, couverture, exigences]
---
# Backlog : epics → exigences → jalons

**En bref.** Dix epics regroupent les 20 exigences fonctionnelles et les 12 exigences non fonctionnelles de la fiche. FR-10 et NFR-07 sont **retirées par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)** (secours = vidéo gérée par le porteur) ; elles restent listées, barrées. Chaque exigence a **un** epic porteur. Les priorités MoSCoW des FR sont celles de la fiche (§ 4) ; la fiche ne priorise pas les NFR (« cibles de conception à valider en répétition », § 5). La matrice finale relie chaque exigence au jalon de [roadmap.md](roadmap.md) qui la livre ; depuis le 2026-10-29, les jalons sont datés (J1 29/10 → J7 9/11, gel J8 10-11/11, talk 12/11) et un **ordre de coupe** (C1 à C10, proposition à valider, Q-65) désigne ce qui saute en premier si le temps manque.

## Epics

| Epic | Intitulé | Exigences portées | Jalons |
|---|---|---|---|
| EP-01 | Socle, sécurité et reproductibilité (app desktop Linux, backend Go, session voix créée par relais SDP backend sans clé dans l'app, versions figées) ; livrables de l'assistant : `docker-compose.yaml` ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)) et CI GitHub Actions ([pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md)) ; **Livré partiellement par la fonctionnalité 003 (2026-10-29)** : relais SDP, sideband, app-channel, journal, compose, CI minimale ; reste : app voix + orbe (005) ; **livré partiellement par 004 (2026-10-29)** : orchestrateur (délégation `client`, file par session), commentaire vocal fondé sur le résultat réel ; reste : annulation « Stop » (J7). **Livré par 005 (terminée le 2026-10-30)** : app Flutter avec `app/di` (get_it + injectable, un `GetIt` par instance d'app, [p-ar-frontend](../architecture/frontend.md)), session voix par relais SDP sans clé dans l'app (NFR-09 : test V6, `lib/` sans `api_key`), versions figées (NFR-10) ; l'essai réel avec micro et voix reste à faire en répétition avec le porteur (SP-06, J7). | NFR-09, NFR-10 | J2, J8 |
| EP-02 | Conversation vocale et coupure de parole ; **Livré partiellement par la fonctionnalité 003 (2026-10-29)** : relais SDP, sideband, app-channel, journal, compose, CI minimale ; orchestrateur et agent A2A livrés par 004 ; **livré par 005 (2026-10-30)** : session voix (démarrer, arrêter, redémarrer, erreurs honnêtes), transcription sur deux lignes (FR-02 partiel : sans troncature de la réplique coupée) ; **009 (2026-10-30)** : voix hors délégation (`VoiceReply.Announce`, commentaire à `delegation_id` nul, repli sur refus, consigne fixe de l'orchestrateur ; Q-75 ouverte, voix non observée en réel) ; couverture : FR-01, FR-02 (partiel), NFR-09. Reste à faire (J7) : états d'orbe Écoute, Interrompue et Micro coupé, troncature de la réplique (FR-19), barge-in et AEC (SP-06). | FR-02, FR-13, FR-14, FR-16, FR-18, FR-19, NFR-01 | J2, J7 |
| EP-03 | Orchestrateur, agents A2A et rail des agents ; **livré partiellement par 004 (2026-10-29)** : orchestrateur, client A2A, validateur A2UI, agent Qualité (KPI), file par session ; **livré par 006 (J3-A, terminée le 2026-10-30)** : agents Voix du client et Livraison (module `backend/agents`, un binaire par agent), choix des agents par l'orchestrateur (`Planner`, message `plan`, état `rejected`, refus hors catalogue RG-08, échec partiel honnête), côté données de FR-03 et FR-04 ; reste : annulation « Stop » (J7) ; **côté app, livré par 005 (2026-10-30)** : panneau d'activité minimal (FR-03 partiel : une ligne par agent, états `working`, `completed`, `failed`, interrompu) ; **rail complet livré par 007 (2026-10-30, FR-03)** : orchestrateur puis agents du dernier `plan` sans nom codé en dur, « en veille », « aucun agent retenu », états `rejected` et `interrupted` ; **livré par 008 (2026-10-30)** : `kit.ParseIntent` (plateforme, comparaison 3.3, motifs de refus fermés), tags communs aux trois profils, agents qui mutent leurs surfaces par `updateDataModel` seul, canevas partagé entre sessions (`orchestrate.Canvas`, pdr-0058) ; FR-17 **premier temps** (correction de plateforme) ; reste : révision de consigne, annulation en vol (FR-14, FR-16, FR-17 second temps) et « Stop » (J7) ; **livré par 009 (2026-10-30)** : `ActionPlanner` (routage par tag de carte `action:*`), `Manager.Act` atomique, `Delegation.Action` (`act-<n>`), chemin d'action du `Pipeline`, agent Livraison qui crée `actions` à l'acte 2 et répond par `updateDataModel` de `/checklist/decisionStatus`, `rejected` d'une action absente des tags (noyau d'agent), plan Livraison seul | FR-03, FR-17, NFR-02, NFR-03 | J2, J3, J4, J7 |
| EP-04 | Canevas génératif et catalogue (surfaces, squelettes, mutation, étagère) ; **livré partiellement par 005 (2026-10-30)** : orbe à 60 i/s sans rebuild des widgets voisins (NFR-04, preuve par test : 60 niveaux poussés, aucun rebuild de la barre du haut ; mesure DevTools en J7), canevas vide au démarrage (FR-01), rendu A2UI du flux vivant en trois temps, 1 surface (FR-04), avec le **catalogue de base de genui** ; **contrat du catalogue fermé `genesis` livré côté backend par 006** (4 composants dans la liste blanche, `catalogComponents` = les 6 de pdr-0014, `contracts/a2ui/genesis/v1/`, validateur de propriétés) ; **côté client livré par 007 (2026-10-30)** : catalogue `genesis` fermé (4 composants, trois états squelette / sans données / neutre), validation côté client (Q-71 → pdr-0053), grille déterministe 2×2 puis 3×2, étagère « n / 6 utilisés » (FR-06), RD-9 levé ; **mutation sur place (FR-07) livrée par 008 (2026-10-30)** : ligne `comparison-<surface>`, légende de séries par plateforme, colonnes de checklist calculées, remise à vide de démarrage (D6), asset de rejeu `act2-replay.jsonl`, capture 1920×1080 conforme ; **Barre d'actions et `ActionBar` livrés par 009 (2026-10-30)** : cinquième surface en bandeau de 72 px hors grille, trois états, tons, boutons inactifs pendant l'action, `CanvasActionBloc`, `writableSubPaths` appliqué par `A2uiGate`, budget des zones modifié (barre 128, canevas 572), étagère « 5 / 6 », assets de rejeu `act2-replay.jsonl` (19 lignes) et `act3-replay.jsonl` (20), capture 1920×1080 conforme ; reste : interruption sans destruction (FR-15, J7), mesure 60 i/s et lisibilité à la projection (J7) ; stories Widgetbook et goldens par composant reportés (C1, C3) | FR-01, FR-04, FR-06, FR-07, FR-15, NFR-04, NFR-05, NFR-06 | J2, J3, J4, J7 |
| EP-05 | Flux du protocole (panneau JSON relié au composant) ; **livré par 007 (2026-10-30)** : panneau replié par défaut, déplié il recouvre le canevas, message en cours relié à sa surface par un contour pointillé, messages refusés marqués ; reste : synchronisation avec le rejeu (J6) | FR-05 | J3 |
| EP-06 | Interaction avec un composant généré ; `ActionBar` (schéma et rendu) : J5 ([pdr-0061](../decisions/pdr-0061-action-bar-appears-end-of-act-2.md), pdr-0064 D5) ; **livré par 009 (2026-10-30)** : `POST /canvas/actions` (gardes de `/canvas/reset`, corps strict, 202/400/403/409/413/415/422/500), clic → Livraison → « Bloquée » / « Validée » (RG-18, RG-28, RG-30), S-03 et C1 à C6 verts ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md)) ; reste à observer en répétition : la voix après un clic (Q-75) ; limite Q-76 | FR-08 | J5 |
| EP-07 | Enregistrement du flux A2UI et rejeu (acte 4) ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | FR-09 (~~FR-10~~, ~~NFR-07~~ retirées) | J6 |
| EP-08 | Régie de scène (souris d'abord, raccourcis facultatifs, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) ; remise à vide (FR-11) : **livrée par 007 (2026-10-30)** : bouton « Remettre à vide » + indicateur d'acte (régie dans la barre supérieure, sans raccourci `R`), route Go `POST /canvas/reset` ; reste : couper le micro, faire taire (FR-12, FR-20, J7), régie complète du talk (J7), essai de répétition avec le porteur | FR-11, FR-12, FR-20, NFR-12 | J3, J7 |
| EP-09 | Jeu de données fictif et figé ; livrable de l'assistant : valeurs du jeu de référence ([pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)) ; **livré par 006 (2026-10-30)** : toutes les valeurs de l'acte 1 recalculées depuis les lignes brutes, sans écart ([dataset.md](../functional/dataset.md)) ; **008 (2026-10-30)** : valeurs de l'acte 2 et de la vue iOS recalculées sans écart ([dataset-acts.md](../functional/dataset-acts.md)) | NFR-08 | J3, J4 |
| EP-10 | Coût et mesures (budget total 20 €, [pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) ; organisation des répétitions gérée par le porteur | NFR-11 + vérification de toutes les exigences | J2, J8 |

Questions encore ouvertes qui conditionnent les epics : Q-68 (plafond de durée par session GPT-Live, avant J7). Tranchées ou conformes le 2026-10-30 après l'essai au micro : Q-40, Q-42, Q-67 (pdr-0069, coupure vocale hybride, fonctionnalité 011), Q-41 (conforme), Q-74, Q-75 (pdr-0071, 011), Q-76 (pdr-0068). **Ordre après 010** : 011 interaction vocale et corrections de l'essai (EP-02, EP-03, EP-06 ; FR-13, FR-14, FR-16, FR-19, FR-17 second temps), 012 compositeur LLM puis CrashList ([pdr-0070](../decisions/pdr-0070-llm-composer-and-crashlist-012.md), EP-03, EP-04), 013 design et ergonomie ([pdr-0072](../decisions/pdr-0072-design-ergonomics-013.md), EP-04, EP-08 ; FR-04, NFR-04, NFR-05), puis J7. Q-73 résolue par construction par 008 (canevas partagé, pdr-0058). Tranchées le 2026-10-30 (décisions du porteur) : Q-17 (pdr-0060), Q-20 (pdr-0061), Q-21, Q-32, Q-49, Q-52 (pdr-0059), Q-22, Q-30, Q-31, Q-35 (pdr-0054), Q-44 (pdr-0055), Q-69 (pdr-0056), Q-70 (pdr-0058), Q-71 (pdr-0053), Q-72 (pdr-0057). Tranchées : Q-47 (pdr-0050, délégation `client`), Q-43 (pdr-0051, niveau d'orbe par le RMS de la copie sideband), Q-53 (pdr-0052, une session GPT-Live par acte), Q-25 (pdr-0046, Flutter 3.47.8), Q-39 (pdr-0045, canal WSS maison), Q-46 (pdr-0047, Go 1.27.3 au 1er commit de code), Q-55 (pdr-0048, journal seul), Q-63 (pdr-0049, 9 scénarios de la fiche), Q-27 et Q-48 (pdr-0041), Q-65 (pdr-0042) ; Q-01 (pdr-0013), Q-02 et Q-60 (pdr-0014), Q-29 (pdr-0015), Q-62 (pdr-0016), décisions contraintes Q-03, Q-04, Q-58, Q-59 (pdr-0018, pdr-0019, pdr-0024, pdr-0025) ; réponses du porteur du 2026-10-29 : Q-15 (pdr-0029), Q-16, Q-37 (pdr-0036, agents A2A réels qui produisent l'A2UI ; Q-37 : penchant du porteur), Q-18, Q-19 (pdr-0032, acte 4), Q-05 (pdr-0033), Q-08 (pdr-0034), Q-23 (pdr-0040), Q-13 (pdr-0030), Q-61 (pdr-0039), Q-26 (pdr-0037). Q-14 et Q-24 : gérées par le porteur. Voir [open-questions.md](open-questions.md).

## Livrables confiés à l'assistant (2026-10-29)

| Livrable | Epic | Jalon | Décision |
|---|---|---|---|
| `docker-compose.yaml` (backend Go + un service par agent, choix de conception ; ports sur `127.0.0.1`, [pdr-0041](../decisions/pdr-0041-backend-in-this-repo-local-no-auth.md) ; `.env` non commité) | EP-01 | J2 | [pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md) |
| CI GitHub Actions (tests, build Linux ; minimale en J2, réductible : coupe C3) | EP-01 | J2 | [pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md) |
| Texte des instructions vocales (français, répliques courtes, commentaire pendant la construction) | EP-02 | J3, réglage J7 | [pdr-0037](../decisions/pdr-0037-voice-brise-delegated-instructions.md) |
| Valeurs du jeu de référence dans `dataset.md` | EP-09 | J3 | [pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md) |

Mode de développement : boucle autonome (`tools/loop/README.md`), un dossier `specs/NNN-<slug>/` par fonctionnalité ([pdr-0043](../decisions/pdr-0043-light-spec-kit-sdd-template.md)) ; première fonctionnalité `specs/000-loop-harness` (**terminée le 2026-10-29** : app Linux, rejeu A2UI v0.9 scripté, capture PNG ; couvre la part « app Linux » d'EP-01 et le début de NFR-10 : Flutter 3.47.8 et `genui` 0.10.4 figés, `pubspec.lock` committé ; `genui_a2a` arrive avec la fonctionnalité A2A), puis SP-03, SP-02, J2 ([roadmap](roadmap.md)).

Slides et supports du talk : uniquement sur demande explicite du porteur ([pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)).

## Exigences fonctionnelles (fiche § 4)

| ID | Exigence (résumé) | MoSCoW | Epic | Jalon | Scénario BDD |
|---|---|---|---|---|---|
| FR-01 | Canevas vide au démarrage, orbe animé | Must | EP-04 | J2 | Contexte « le canevas est vide » |
| FR-02 | Transcription du speaker en direct | Must | EP-02 | J2 (partiel), J3 | Acte 1 |
| FR-03 | Agent sollicité allumé dans le rail, avec sa tâche | Must | EP-03 | J3 | Acte 1, Acte 3 |
| FR-04 | Surface en 3 temps : squelette, composants, données | Must | EP-04 | J2 (1 surface), J3 | Acte 1 |
| FR-05 | Message du protocole mis en évidence avec son composant | Must | EP-05 | J3 | — (revue visuelle ; pdr-0049) |
| FR-06 | Composant utilisé allumé dans l'étagère | Should | EP-04 | J3 | — (revue ; pdr-0049) |
| FR-07 | Modification sur place, sans recréer — **livrée (008, 2026-10-30)** | Must | EP-04 | J4 | Acte 2 |
| FR-08 | Clic transmis à l'agent, réponse vocale — **livrée (009, 2026-10-30)** ; voix après un clic à observer (Q-75) | Must | EP-06 | J5 | Acte 3 |
| FR-09 | Génération enregistrée, rejouable de 0,25× à 2× | Must | EP-07 | J6 | — (revue ; pdr-0049) |
| FR-10 | ~~Raccourci de bascule en mode secours~~ | **retirée (pdr-0032)** | — | — | ~~Bascule en mode secours~~ (S-04 commenté) |
| FR-11 | Raccourci de remise à vide (assouplie : souris, pdr-0033) | Must | EP-08 | J3 | — (revue ; pdr-0049) |
| FR-12 | Couper le micro sans fermer la session | Should | EP-08 | J7 | — (revue ; pdr-0049) |
| FR-13 | Couper la parole à l'IA en parlant | Must | EP-02 | 011 (avant J7) | Interrompre l'IA |
| FR-14 | Nouvelle phrase = consigne en vigueur | Must | EP-02 | 011 (avant J7) | Interrompre l'IA, Corriger la demande |
| FR-15 | Une interruption ne détruit pas les surfaces | Must | EP-04 | 011 (avant J7) | Interrompre l'IA, Annuler une génération |
| FR-16 | « Stop » arrête voix et génération, retire l'inachevé | Must | EP-02 | 011 (avant J7) | Annuler une génération |
| FR-17 | Correction en cours de génération, sans repartir de zéro — **partielle** : correction de plateforme livrée (008) ; annulation en vol (S-07) : J7 | Should | EP-03 | J4, J7 | Corriger la demande |
| FR-18 | Un bruit court n'interrompt pas l'IA | Should | EP-02 | J7 | Un bruit court |
| FR-19 | Interruption visible (orbe, réplique tronquée) | Must | EP-02 | 011 (avant J7) | Interrompre l'IA |
| FR-20 | Raccourci « silence » (assouplie : souris, pdr-0033) | Must | EP-08 | J7 | Faire taire l'IA au clavier |

Bilan MoSCoW : 16 Must dans la fiche, dont FR-10 retirée (15 Must actives), 4 Should (FR-06, FR-12, FR-17, FR-18), aucun Could ni Won't dans la fiche. Le hors-périmètre de la fiche § 3 tient lieu de « Won't » ([pdr-0004](../decisions/pdr-0004-mvp-three-acts.md), [beyond.md](beyond.md)).

## Exigences non fonctionnelles (fiche § 5)

| ID | Catégorie | Seuil | Epic | Jalon de livraison | Jalon de mesure |
|---|---|---|---|---|---|
| NFR-01 | Latence voix | < 1 s après la fin de phrase, p90 | EP-02 | J7 | instrumenté J2, p90 J8 |
| NFR-02 | Latence UI | 1er squelette < 1,5 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-03 | Latence UI | Acte 1 complet < 8 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-04 | Fluidité | 60 i/s pendant les apparitions | EP-04 | 013 puis J7 | J7 (DevTools) |
| NFR-05 | Lisibilité | ≥ 24 px, contraste WCAG AA | EP-04 | 013 puis J7 | J7 contrôle 24 px et contraste à l'écran ; projecteur et fond de salle : géré par le porteur, hors périmètre de l'assistant |
| NFR-06 | Lisibilité | ≤ 6 surfaces visibles | EP-04 | J3 | J3 (Q-04 → pdr-0019) |
| NFR-07 | Résilience | ~~Bascule secours < 2 s, sans redémarrer~~ **retirée (pdr-0032)** | — | — | — |
| NFR-08 | Déterminisme | Données figées, seule la composition varie | EP-09 | J3 | J3 (snapshot des réponses d'agents) |
| NFR-09 | Sécurité | Aucune clé OpenAI dans l'app (fiche : « jeton éphémère » ; GPT-Live : relais SDP backend, aucun client secret, cf. écart de vocabulaire dans [pdr-0012](../decisions/pdr-0012-voice-provider-openai.md), [rt-ephemeral-keys]) | EP-01 | J2 | J2 revue de code |
| NFR-10 | Reproductibilité | Flutter, genui, genui_a2a figés, `pubspec.lock` committé | EP-01 | J2 | J8 machine vierge |
| NFR-11 | Coût | Coût d'une répétition connu et plafonné (budget total 20 €, pdr-0030 ; plafond par répétition proposé) | EP-10 | J2 (suivi) | J8 |
| NFR-12 | Accessibilité scène | Raccourci pour chaque action critique (assoupli : souris, pdr-0033) | EP-08 | J7 | J7 checklist |

## Matrice de couverture exigence → jalon

`●` = jalon qui livre l'exigence ; `○` = jalon qui la prépare ou la mesure.

| Exigence | J1 | J2 | J3 | J4 | J5 | J6 | J7 | J8 |
|---|---|---|---|---|---|---|---|---|
| FR-01 |  | ● |  |  |  |  |  | ○ |
| FR-02 |  | ○ | ● |  |  |  |  | ○ |
| FR-03 |  |  | ● |  |  |  |  | ○ |
| FR-04 |  | ○ | ● |  |  |  |  | ○ |
| FR-05 |  |  | ● |  |  |  |  | ○ |
| FR-06 |  |  | ● |  |  |  |  | ○ |
| FR-07 |  |  |  | ● |  |  |  | ○ |
| FR-08 |  |  |  |  | ● |  |  | ○ |
| FR-09 | ○ |  |  |  |  | ● |  | ○ |
| ~~FR-10~~ retirée |  |  |  |  |  |  |  |  |
| FR-11 |  |  | ● |  |  |  |  | ○ |
| FR-12 |  |  |  |  |  |  | ● | ○ |
| FR-13 | ○ |  |  |  |  |  | ● | ○ |
| FR-14 |  |  |  |  |  |  | ● | ○ |
| FR-15 |  |  |  |  |  |  | ● | ○ |
| FR-16 |  |  |  |  |  |  | ● | ○ |
| FR-17 |  |  |  | ● |  |  | ○ | ○ |
| FR-18 | ○ |  |  |  |  |  | ● | ○ |
| FR-19 |  |  |  |  |  |  | ● | ○ |
| FR-20 |  |  |  |  |  |  | ● | ○ |
| NFR-01 | ○ | ○ |  |  |  |  | ● | ○ |
| NFR-02 | ○ | ○ | ● |  |  |  |  | ○ |
| NFR-03 | ○ |  | ● |  |  |  |  | ○ |
| NFR-04 | ○ |  |  |  |  |  | ● | ○ |
| NFR-05 | ○ |  |  |  |  |  | ● | ○ |
| NFR-06 |  |  | ● |  |  |  |  | ○ |
| ~~NFR-07~~ retirée |  |  |  |  |  |  |  |  |
| NFR-08 |  |  | ● |  |  |  |  | ○ |
| NFR-09 |  | ● |  |  |  |  |  | ○ |
| NFR-10 | ○ | ● |  |  |  |  |  | ○ |
| NFR-11 |  | ○ |  |  |  |  |  | ● |
| NFR-12 |  |  |  |  |  |  | ● | ○ |

Contrôle : chaque ligne active a exactement un `●` ; FR-10 et NFR-07, retirées, n'en ont aucun. J8 vérifie tout (DoD, fiche § 8) : la DoD s'en tient aux 9 scénarios de la fiche (S-04 retiré : 8 actifs) plus une revue pour FR-05, FR-06, FR-09, FR-11, FR-12, sans scénario Gherkin supplémentaire ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md)).

## Règles de fonctionnement → epic → jalon

Lecture de l'assistant ; les règles viennent de [p-fn-business-rules](../functional/business-rules.md).

| RG | Epic | Jalon | RG | Epic | Jalon |
|---|---|---|---|---|---|
| RG-01 | EP-04 | J2 | RG-15 | EP-03 | J4 (plateforme, 008), J7 (annulation en vol) |
| RG-02 | EP-04 | J2, J3 | RG-16 | EP-02 | J7 |
| RG-03 | EP-03 | J3 | RG-17 | EP-02 | J7 (E20 · Q-59 → pdr-0025) |
| RG-04 | EP-03 | J3 (commentaire pendant la construction) | RG-18 | EP-06 | J5, livrée par 009 |
| RG-05 | EP-04 | J3 (Q-04 → pdr-0019) | RG-19 | EP-07 | J6 (acte 4, flux A2UI seul) |
| RG-06 | EP-04 | J4, livré par 008 (Q-21 → pdr-0059 ; Q-58 → pdr-0024) | ~~RG-20~~ | retirée (pdr-0032) | — |
| RG-07 | EP-04 | J3 | RG-21 | EP-08 | J7 |
| RG-08 | EP-03 | J3 (refus à la voix, alternative) | RG-22 | EP-08 | J7 |
| RG-09 | EP-04 | J3 (thème), J7 (projecteur) | RG-23 | EP-08 | J3 |
| RG-10 | EP-04 | J3 (état neutre) | RG-24 | EP-09 | J3 |
| RG-11 | EP-02 | J7 | RG-25 | EP-03, EP-05 | J3 |
| RG-12 | EP-02 | J7 | RG-26 | EP-02 | J2 |
| RG-13 | EP-04 | J7 | RG-27 | EP-02 | J7 (consigne de répliques courtes) |
| RG-14 | EP-02 | J7 | RG-28 | EP-06 | J5, livrée par 009 (Q-35 → pdr-0054) |
