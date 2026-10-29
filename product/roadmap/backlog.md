---
id: p-rm-backlog
title: Backlog par epics et couverture des exigences
area: roadmap
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3-p7, product/sources/product-description.pdf#p11-p12]
links: [pdr-0041-backend-in-this-repo-local-no-auth, pdr-0042-calendar-and-cut-order-validated, pdr-0043-light-spec-kit-sdd-template, pdr-0027-talk-context-meetup-flutter-nantes, p-fn-business-rules, pdr-0012-voice-provider-openai, rt-ephemeral-keys, p-rm-roadmap, p-rm-open-questions, p-fn-requirements, p-fn-nfr, p-fn-risks-acceptance, p-fn-dataset, p-ar-overview, p-ar-replay, p-ar-quality, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0019-six-limit-applies-to-surfaces, pdr-0024-act2-android-only, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0029-local-docker-compose-hosting, pdr-0030-llm-budget-20-eur, pdr-0031-github-actions-ci-linux, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0037-voice-brise-delegated-instructions, pdr-0040-reference-dataset-adjusted-by-assistant]
tags: [backlog, epics, moscow, couverture, exigences]
---
# Backlog : epics → exigences → jalons

**En bref.** Dix epics regroupent les 20 exigences fonctionnelles et les 12 exigences non fonctionnelles de la fiche. FR-10 et NFR-07 sont **retirées par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)** (secours = vidéo gérée par le porteur) ; elles restent listées, barrées. Chaque exigence a **un** epic porteur. Les priorités MoSCoW des FR sont celles de la fiche (§ 4) ; la fiche ne priorise pas les NFR (« cibles de conception à valider en répétition », § 5). La matrice finale relie chaque exigence au jalon de [roadmap.md](roadmap.md) qui la livre ; depuis le 2026-10-29, les jalons sont datés (J1 29/10 → J7 9/11, gel J8 10-11/11, talk 12/11) et un **ordre de coupe** (C1 à C10, proposition à valider, Q-65) désigne ce qui saute en premier si le temps manque.

## Epics

| Epic | Intitulé | Exigences portées | Jalons |
|---|---|---|---|
| EP-01 | Socle, sécurité et reproductibilité (app desktop Linux, backend Go, session voix créée par relais SDP backend sans clé dans l'app, versions figées) ; livrables de l'assistant : `docker-compose.yaml` ([pdr-0029](../decisions/pdr-0029-local-docker-compose-hosting.md)) et CI GitHub Actions ([pdr-0031](../decisions/pdr-0031-github-actions-ci-linux.md)) | NFR-09, NFR-10 | J2, J8 |
| EP-02 | Conversation vocale et coupure de parole | FR-02, FR-13, FR-14, FR-16, FR-18, FR-19, NFR-01 | J2, J7 |
| EP-03 | Orchestrateur, agents A2A et rail des agents | FR-03, FR-17, NFR-02, NFR-03 | J2, J3, J4 |
| EP-04 | Canevas génératif et catalogue (surfaces, squelettes, mutation, étagère) | FR-01, FR-04, FR-06, FR-07, FR-15, NFR-04, NFR-05, NFR-06 | J2, J3, J4, J7 |
| EP-05 | Flux du protocole (panneau JSON relié au composant) | FR-05 | J3 |
| EP-06 | Interaction avec un composant généré | FR-08 | J5 |
| EP-07 | Enregistrement du flux A2UI et rejeu (acte 4) ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) | FR-09 (~~FR-10~~, ~~NFR-07~~ retirées) | J6 |
| EP-08 | Régie de scène (souris d'abord, raccourcis facultatifs, [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) | FR-11, FR-12, FR-20, NFR-12 | J3, J7 |
| EP-09 | Jeu de données fictif et figé ; livrable de l'assistant : valeurs du jeu de référence ([pdr-0040](../decisions/pdr-0040-reference-dataset-adjusted-by-assistant.md)) | NFR-08 | J3 |
| EP-10 | Coût et mesures (budget total 20 €, [pdr-0030](../decisions/pdr-0030-llm-budget-20-eur.md)) ; organisation des répétitions gérée par le porteur | NFR-11 + vérification de toutes les exigences | J2, J8 |

Questions encore ouvertes qui conditionnent les epics : EP-03 (Q-17), EP-04 (Q-21), EP-06 (Q-20, Q-49), EP-01 (Q-25, Q-27, Q-39, Q-46, Q-48) ; calendrier et coupes : Q-65. Tranchées : Q-01 (pdr-0013), Q-02 et Q-60 (pdr-0014), Q-29 (pdr-0015), Q-62 (pdr-0016), décisions contraintes Q-03, Q-04, Q-58, Q-59 (pdr-0018, pdr-0019, pdr-0024, pdr-0025) ; réponses du porteur du 2026-10-29 : Q-15 (pdr-0029), Q-16, Q-37 (pdr-0036, agents A2A réels qui produisent l'A2UI ; Q-37 : penchant du porteur), Q-18, Q-19 (pdr-0032, acte 4), Q-05 (pdr-0033), Q-08 (pdr-0034), Q-23 (pdr-0040), Q-13 (pdr-0030), Q-61 (pdr-0039), Q-26 (pdr-0037). Q-14 et Q-24 : gérées par le porteur. Voir [open-questions.md](open-questions.md).

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
| FR-05 | Message du protocole mis en évidence avec son composant | Must | EP-05 | J3 | — (revue visuelle ; Q-63) |
| FR-06 | Composant utilisé allumé dans l'étagère | Should | EP-04 | J3 | — (Q-63) |
| FR-07 | Modification sur place, sans recréer | Must | EP-04 | J4 | Acte 2 |
| FR-08 | Clic transmis à l'agent, réponse vocale | Must | EP-06 | J5 | Acte 3 |
| FR-09 | Génération enregistrée, rejouable de 0,25× à 2× | Must | EP-07 | J6 | — (Q-63) |
| FR-10 | ~~Raccourci de bascule en mode secours~~ | **retirée (pdr-0032)** | — | — | ~~Bascule en mode secours~~ (S-04 commenté) |
| FR-11 | Raccourci de remise à vide (assouplie : souris, pdr-0033) | Must | EP-08 | J3 | — (Q-63) |
| FR-12 | Couper le micro sans fermer la session | Should | EP-08 | J7 | — (Q-63) |
| FR-13 | Couper la parole à l'IA en parlant | Must | EP-02 | J7 | Interrompre l'IA |
| FR-14 | Nouvelle phrase = consigne en vigueur | Must | EP-02 | J7 | Interrompre l'IA, Corriger la demande |
| FR-15 | Une interruption ne détruit pas les surfaces | Must | EP-04 | J7 | Interrompre l'IA, Annuler une génération |
| FR-16 | « Stop » arrête voix et génération, retire l'inachevé | Must | EP-02 | J7 | Annuler une génération |
| FR-17 | Correction en cours de génération, sans repartir de zéro | Should | EP-03 | J4 | Corriger la demande |
| FR-18 | Un bruit court n'interrompt pas l'IA | Should | EP-02 | J7 | Un bruit court |
| FR-19 | Interruption visible (orbe, réplique tronquée) | Must | EP-02 | J7 | Interrompre l'IA |
| FR-20 | Raccourci « silence » (assouplie : souris, pdr-0033) | Must | EP-08 | J7 | Faire taire l'IA au clavier |

Bilan MoSCoW : 16 Must dans la fiche, dont FR-10 retirée (15 Must actives), 4 Should (FR-06, FR-12, FR-17, FR-18), aucun Could ni Won't dans la fiche. Le hors-périmètre de la fiche § 3 tient lieu de « Won't » ([pdr-0004](../decisions/pdr-0004-mvp-three-acts.md), [beyond.md](beyond.md)).

## Exigences non fonctionnelles (fiche § 5)

| ID | Catégorie | Seuil | Epic | Jalon de livraison | Jalon de mesure |
|---|---|---|---|---|---|
| NFR-01 | Latence voix | < 1 s après la fin de phrase, p90 | EP-02 | J7 | instrumenté J2, p90 J8 |
| NFR-02 | Latence UI | 1er squelette < 1,5 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-03 | Latence UI | Acte 1 complet < 8 s | EP-03 | J3 | J3 indicatif, p90 J8 |
| NFR-04 | Fluidité | 60 i/s pendant les apparitions | EP-04 | J7 | J7 (DevTools) |
| NFR-05 | Lisibilité | ≥ 24 px, contraste WCAG AA | EP-04 | J7 | J7 contrôle 24 px et contraste à l'écran ; projecteur et fond de salle : géré par le porteur, hors périmètre de l'assistant |
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
| FR-17 |  |  |  | ● |  |  |  | ○ |
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

Contrôle : chaque ligne active a exactement un `●` ; FR-10 et NFR-07, retirées, n'en ont aucun. J8 vérifie tout (DoD, fiche § 8).

## Règles de fonctionnement → epic → jalon

Lecture de l'assistant ; les règles viennent de [p-fn-business-rules](../functional/business-rules.md).

| RG | Epic | Jalon | RG | Epic | Jalon |
|---|---|---|---|---|---|
| RG-01 | EP-04 | J2 | RG-15 | EP-03 | J4 |
| RG-02 | EP-04 | J2, J3 | RG-16 | EP-02 | J7 |
| RG-03 | EP-03 | J3 | RG-17 | EP-02 | J7 (E20 · Q-59 → pdr-0025) |
| RG-04 | EP-03 | J3 (commentaire pendant la construction) | RG-18 | EP-06 | J5 |
| RG-05 | EP-04 | J3 (Q-04 → pdr-0019) | RG-19 | EP-07 | J6 (acte 4, flux A2UI seul) |
| RG-06 | EP-04 | J4 (Q-21 ; Q-58 → pdr-0024) | ~~RG-20~~ | retirée (pdr-0032) | — |
| RG-07 | EP-04 | J3 | RG-21 | EP-08 | J7 |
| RG-08 | EP-03 | J3 (refus à la voix, alternative) | RG-22 | EP-08 | J7 |
| RG-09 | EP-04 | J3 (thème), J7 (projecteur) | RG-23 | EP-08 | J3 |
| RG-10 | EP-04 | J3 (état neutre) | RG-24 | EP-09 | J3 |
| RG-11 | EP-02 | J7 | RG-25 | EP-03, EP-05 | J3 |
| RG-12 | EP-02 | J7 | RG-26 | EP-02 | J2 |
| RG-13 | EP-04 | J7 | RG-27 | EP-02 | J7 (consigne de répliques courtes) |
| RG-14 | EP-02 | J7 | RG-28 | EP-06 | J5 (Q-35) |
