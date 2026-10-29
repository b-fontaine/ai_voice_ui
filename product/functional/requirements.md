---
id: p-fn-requirements
title: Exigences fonctionnelles FR-01 à FR-20
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4]
links: [rt-echo-cancellation, p-fn-nfr, p-fn-business-rules, p-fn-screen, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-rm-backlog, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, rt-barge-in, ux-voice-multimodal, pdr-0013-orchestrator-visible-agent-selection, pdr-0016-validate-release-action, pdr-0024-act2-android-only, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0039-component-voice-interactions-via-fr07, pdr-0012-voice-provider-openai]
tags: [exigences, fr, moscow, bdd]
---
# Exigences fonctionnelles (FR-01 à FR-20)

**En bref.** 20 exigences reprises telles quelles de la fiche (§ 4, p. 3-4), avec leur priorité MoSCoW : 16 Must, 4 Should. FR-10 est **retirée par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)** (secours = vidéo gérée par le porteur) : 15 Must actives. FR-11 et FR-20 sont **assouplies par [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)** (souris d'abord). Chaque ligne indique le scénario BDD qui la vérifie (S-xx) et les règles de fonctionnement associées (RG-xx, [p-fn-business-rules](business-rules.md)).

## Scénarios BDD (fiche § 4)

| Id | Scénario | Fichier |
|---|---|---|
| S-01 | Acte 1 - créer le tableau de release | [voice-screen-generation.feature](features/voice-screen-generation.feature) |
| S-02 | Acte 2 - transformer sans recréer | idem |
| S-03 | Acte 3 - interagir avec un composant généré | idem |
| S-04 | ~~Bascule en mode secours~~ — **retiré par pdr-0032** (scénario commenté dans le `.feature`) | idem |
| S-05 | Interrompre l'IA pendant qu'elle parle | [barge-in.feature](features/barge-in.feature) |
| S-06 | Annuler une génération en cours | idem |
| S-07 | Corriger la demande en cours de génération | idem |
| S-08 | Un bruit court n'interrompt pas l'IA | idem |
| S-09 | Faire taire l'IA au clavier | idem |

Les ids S-xx sont une numérotation de l'assistant ; les titres sont ceux de la fiche.

## Exigences

| ID | Exigence (fiche) | Priorité | Scénario BDD | Règles |
|---|---|---|---|---|
| FR-01 | Au démarrage, le canevas est vide, avec seulement l'orbe vocal animé | Must | Contexte des S-01..S-03 (« le canevas est vide ») | RG-01 |
| FR-02 | Ce que dit le speaker s'affiche en direct dans la barre de transcription | Must | S-01 | RG-25 |
| FR-03 | Chaque agent sollicité s'allume dans le rail des agents, avec la tâche qu'il traite | Must | S-01, S-03 | RG-25, RG-29 |
| FR-04 | Chaque surface apparaît en 3 temps : squelette, composants, données | Must | S-01 (squelette < 1,5 s) | RG-02, RG-03 |
| FR-05 | Le panneau protocole met en évidence le message qui correspond au composant en train d'apparaître | Must | — | RG-25 |
| FR-06 | Le composant utilisé s'allume dans l'étagère du catalogue | Should | — | RG-25 |
| FR-07 | Une demande de modification transforme une surface existante sur place, sans la recréer | Must | S-02 | RG-06 ; ⚠️ écart E8 · Q-21 (surface retirée) ; uniquement Android, checklist comprise (E19 · Q-58 tranché, [pdr-0024](../decisions/pdr-0024-act2-android-only.md)) ; couvre aussi les interactions vocales par composant de la fiche § 7 (Q-61, [pdr-0039](../decisions/pdr-0039-component-voice-interactions-via-fr07.md)) |
| FR-08 | Un clic sur un composant généré est transmis à l'agent, qui répond à la voix | Must | S-03 | RG-18, RG-28, RG-30 |
| FR-09 | Toute la génération est enregistrée et rejouable à une vitesse de 0,25× à 2× | Must | — | RG-19 ; flux A2UI seul, rejeu = acte 4 ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) |
| FR-10 | ~~Un raccourci clavier bascule en mode secours (rejeu d'une session enregistrée)~~ | ~~Must~~ **retirée (pdr-0032)** | ~~S-04~~ | ~~RG-20~~ ; secours = vidéo OBS gérée par le porteur ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) |
| FR-11 | Un raccourci remet le canevas à l'état vide | Must | — | RG-21, RG-23 ; **assouplie par pdr-0033** : faisable à la souris, raccourci s'il ne pose pas de problème ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |
| FR-12 | Le speaker peut couper son micro sans fermer la session | Should | — | RG-22 |
| FR-13 | Le speaker peut couper la parole à l'IA en parlant : l'IA se tait immédiatement et écoute | Must | S-05 | RG-11 |
| FR-14 | Après une interruption, la nouvelle phrase est traitée comme la consigne en vigueur | Must | S-07 (indirectement) | RG-12 |
| FR-15 | Une interruption ne détruit jamais les surfaces déjà construites | Must | S-05, S-06 | RG-13 |
| FR-16 | « Stop » ou « annule » arrête la voix et la génération en cours ; les surfaces inachevées sont retirées proprement | Must | S-06 | RG-14 |
| FR-17 | Une correction en cours de génération (« non, plutôt iOS ») réoriente la génération sans tout recommencer | Should | S-07 | RG-15 |
| FR-18 | Un bruit court (toux, applaudissements, rire) n'interrompt pas l'IA | Should | S-08 | RG-16 |
| FR-19 | L'interruption est visible : l'orbe change d'état et la réplique de l'IA est tronquée dans la transcription, là où elle a été coupée | Must | S-05 | RG-17 |
| FR-20 | Un raccourci clavier fait taire l'IA, en secours si le micro capte mal | Must | S-09 | RG-21, RG-22 ; **assouplie par pdr-0033** : faisable à la souris, raccourci s'il ne pose pas de problème ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |

## Couverture BDD (constat de l'assistant)

| Constat | Exigences |
|---|---|
| Must sans scénario dédié dans la fiche | FR-05, FR-09, FR-11 (FR-01 n'apparaît que dans un `Contexte`) |
| Should sans scénario | FR-06, FR-12 |
| Couverture indirecte | FR-14 (via S-07) |

La DoD exige que « les 9 scénarios de la section 4 » soient vérifiés ([p-fn-risks-acceptance](risks-acceptance.md)). Ajouter des scénarios pour les exigences non couvertes n'est **pas décidé** : question **Q-63** de [p-rm-open-questions](../roadmap/open-questions.md), reprise dans [p-rm-backlog](../roadmap/backlog.md).

## Groupes fonctionnels

| Groupe | Exigences | Page de référence |
|---|---|---|
| Montrer la fabrication | FR-01..FR-06 | [p-fn-screen](screen.md) |
| Transformer et interagir | FR-07, FR-08 | [p-fn-catalog](catalog.md) |
| Régie de scène et rejeu | FR-09, FR-11, FR-12, FR-20 (FR-10 retirée) | [p-fn-screen](screen.md), [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md), [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md) |
| Interruption (barge-in) | FR-13..FR-19 | [p-fn-business-rules](business-rules.md), [rt-barge-in], [ux-voice-multimodal] |

## Notes de traçabilité

- Les 4 Should (FR-06, FR-12, FR-17, FR-18) peuvent glisser sans casser le MVP ; les Must non.
- FR-13 à FR-19 dépendent du comportement d'interruption du fournisseur voix ([rt-barge-in]) et d'une annulation d'écho efficace ([rt-echo-cancellation]). Fournisseur : `gpt-live-1`, [pdr-0012-voice-provider-openai](../decisions/pdr-0012-voice-provider-openai.md) (acceptée le 2026-10-29).
