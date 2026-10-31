---
id: p-fn-requirements
title: Exigences fonctionnelles FR-01 à FR-20
area: functional
status: validated
updated: 2026-10-31
sources: [specs/013-design-ergonomie/status.md, specs/011-voice-interaction/spec.md, specs/011-voice-interaction/status.md, specs/010-j6-act4-replay/status.md, specs/009-j5-act3-interact/status.md, specs/008-j4-act2-transform/status.md, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4]
links: [pdr-0075-013-design-ergonomics-details-assistant-decided, p-fn-feature-design-ergonomics-013, p-ar-voice-interruption, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0066-010-act4-replay-details-assistant-decided, p-ar-replay, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0072-design-ergonomics-013, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0042-calendar-and-cut-order-validated, p-fn-dataset-acts, rt-echo-cancellation, p-fn-nfr, p-fn-business-rules, p-fn-screen, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in, p-rm-backlog, pdr-0004-mvp-three-acts, pdr-0006-replay-fallback-must, rt-barge-in, ux-voice-multimodal, pdr-0013-orchestrator-visible-agent-selection, pdr-0016-validate-release-action, pdr-0024-act2-android-only, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0039-component-voice-interactions-via-fr07, pdr-0012-voice-provider-openai, pdr-0049-sheet-gherkin-scenarios-only]
tags: [exigences, fr, moscow, bdd]
---
# Exigences fonctionnelles (FR-01 à FR-20)

**En bref.** 20 exigences reprises telles quelles de la fiche (§ 4, p. 3-4), avec leur priorité MoSCoW : 16 Must, 4 Should. FR-10 est **retirée par [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)** (secours = vidéo gérée par le porteur) : 15 Must actives. FR-11 et FR-20 sont **assouplies par [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)** (souris d'abord). Chaque ligne indique le scénario BDD qui la vérifie (S-xx) et les règles de fonctionnement associées (RG-xx, [p-fn-business-rules](business-rules.md)).

## Scénarios BDD (fiche § 4)

| Id | Scénario | Fichier |
|---|---|---|
| S-01 | Acte 1 - créer le tableau de release | [voice-screen-generation.feature](features/voice-screen-generation.feature) |
| S-02 | Acte 2 - transformer sans recréer — **vert en BDD depuis 008** (Go et Flutter) | idem |
| S-03 | Acte 3 - interagir avec un composant généré — **vert en BDD depuis 009** (Go et Flutter) | idem |
| S-04 | ~~Bascule en mode secours~~ — **retiré par pdr-0032** (scénario commenté dans le `.feature`) | idem |
| S-05 | Interrompre l'IA pendant qu'elle parle — **couvert en partie par 011** : le côté app (K-05) est vert, mais `voice.interrupted` n'est publié que sur un mot d'arrêt ; couper la parole sans « Stop » repose sur le modèle (Q-77) | [barge-in.feature](features/barge-in.feature) |
| S-06 | Annuler une génération en cours — **vert en BDD depuis 011** (K-03, agents scriptés bloquants ; les vrais agents finissent en 0 à 3 ms) | idem |
| S-07 | Corriger la demande en cours de génération — **pas encore vert** : correction de plateforme livrée (008), « l'IA se tait » et annulation en vol : J7 | idem |
| S-08 | Un bruit court n'interrompt pas l'IA — conforme à l'essai au micro (Q-41) ; pas de test automatisé du bruit | idem |
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
| FR-07 | Une demande de modification transforme une surface existante sur place, sans la recréer | Must | S-02 | RG-06 ; aucune surface retirée (E8 · Q-21 → pdr-0059) ; uniquement Android, checklist comprise (E19 · Q-58 tranché, [pdr-0024](../decisions/pdr-0024-act2-android-only.md)) ; couvre aussi les interactions vocales par composant de la fiche § 7 (Q-61, [pdr-0039](../decisions/pdr-0039-component-voice-interactions-via-fr07.md)) ; **livrée par 008 (2026-10-30)** : mutation par `updateDataModel` seul, Android seul, comparaison 3.3, NO-GO Android ([pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md), [p-fn-dataset-acts](dataset-acts.md)) ; essai réel avec micro : à faire en répétition |
| FR-08 | Un clic sur un composant généré est transmis à l'agent, qui répond à la voix | Must | S-03 | RG-18, RG-28, RG-30 ; **livrée par 009 (2026-10-30)** : clic « Bloquer la release » / « Valider la release » → `POST /canvas/actions` → agent Livraison (rail) → vrai résultat → statut « Bloquée » / « Validée » → la voix confirme **après** `completed` ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md), [p-fn-dataset-acts](dataset-acts.md)) ; la voix hors délégation a été entendue à l'essai au micro du 2026-10-30 (après la phrase en cours ; la stratégie utilisée n'est pas établie) ; décision perdue par une demande vocale ultérieure (limite connue, Q-76 → [pdr-0068](../decisions/pdr-0068-act3-decision-not-kept-after-new-request.md)) ; **retour au clic renforcé par 011 ([pdr-0071](../decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md))** : pastille de décision entière, bouton « <libellé> · fait ✓ » désactivé sans nouvelle requête (idempotence côté client, D7), indicateur « en cours », indicateur d'acte automatique (K-06, K-07) ; la voix hors délégation parle après sa phrase en cours (observé à l'essai au micro, Q-75 tranchée) |
| FR-09 | Toute la génération est enregistrée et rejouable à une vitesse de 0,25× à 2× | Must | — (revue ; pdr-0049) ; acceptation propre à 010 : R-01 à R-09 | RG-19 ; flux A2UI seul, rejeu = acte 4 ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) ; **livrée par 010 (2026-10-30)** : journal en mémoire du flux A2UI brut, rejeu par le même `A2uiGate`, cinq vitesses de 0,25× à 2×, curseur, sans réseau ni LLM ; `gate --full` vert, capture conforme ([pdr-0066](../decisions/pdr-0066-010-act4-replay-details-assistant-decided.md), [p-ar-replay](../architecture/replay.md)) ; pas d'essai avec micro : sans objet |
| FR-10 | ~~Un raccourci clavier bascule en mode secours (rejeu d'une session enregistrée)~~ | ~~Must~~ **retirée (pdr-0032)** | ~~S-04~~ | ~~RG-20~~ ; secours = vidéo OBS gérée par le porteur ([pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)) |
| FR-11 | Un raccourci remet le canevas à l'état vide | Must | — | RG-21, RG-23 ; **assouplie par pdr-0033** : faisable à la souris, raccourci s'il ne pose pas de problème ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |
| FR-12 | Le speaker peut couper son micro sans fermer la session | Should | — | RG-22 ; **J7** (non livrée par 011) |
| FR-13 | Le speaker peut couper la parole à l'IA en parlant : l'IA se tait immédiatement et écoute | Must | S-05 | RG-11 ; **livrée en partie par 011 ([pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md))** : consigne au modèle (se taire si le speaker parle) et, sur mot d'arrêt, `voice.interrupted` + coupure locale de la piste distante ([p-ar-voice-interruption](../architecture/voice-interruption.md)) ; ⚠️ couper la parole sans mot d'arrêt repose sur le modèle (Q-77) ; coupure locale non vérifiée sous `flutter_webrtc` Linux (Q-79) |
| FR-14 | Après une interruption, la nouvelle phrase est traitée comme la consigne en vigueur | Must | S-07 (indirectement) | RG-12 ; **livrée en partie par 011, pour le chemin « Stop »** : la file de délégations est vidée, la demande réduite au mot d'arrêt n'est jamais planifiée (fenêtre consommée jusqu'à `at_ms`), donc la phrase suivante est une consigne neuve ; une correction **sans** mot d'arrêt pendant une génération n'annule rien (J7, voir FR-17) |
| FR-15 | Une interruption ne détruit jamais les surfaces déjà construites | Must | S-05, S-06 | RG-13 ; **livrée par 011** : seules les surfaces inachevées sont retirées (complétude par surface), les complètes restent (K-03, K-05) |
| FR-16 | « Stop » ou « annule » arrête la voix et la génération en cours ; les surfaces inachevées sont retirées proprement | Must | S-06 | RG-14 ; **livrée par 011 ([pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), [pdr-0073](../decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md))** : détecteur de mots d'arrêt configurable (`VOICE_STOP_WORDS`), annulation sans fermer la session, `canceled` au rail, phrase `stopped` ; ⚠️ GPT-Live crée-t-il une délégation pour « Stop » : Q-78 |
| FR-17 | Une correction en cours de génération (« non, plutôt iOS ») réoriente la génération sans tout recommencer | Should | S-07 | RG-15 ; **partielle (pdr-0064 D4, coupe C7 partielle, [pdr-0042](../decisions/pdr-0042-calendar-and-cut-order-validated.md))** : correction de plateforme livrée par 008 (les quatre surfaces passent sur la vue iOS, GO iOS) ; arrêt de la voix et annulation de la génération en vol : « Stop » livré par 011 (FR-16) ; **correction « Non, plutôt iOS » en vol sans mot d'arrêt (révision n+1, S-07) : J7, FR-17 reste partielle** ; depuis 011, la mémoire de focus ([pdr-0071](../decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md)) fait hériter une comparaison de la plateforme affichée |
| FR-18 | Un bruit court (toux, applaudissements, rire) n'interrompt pas l'IA | Should | S-08 | RG-16 ; **tenue** à l'essai au micro (Q-41 conforme) ; à reconfirmer sur enceinte en J7 |
| FR-19 | L'interruption est visible : l'orbe change d'état et la réplique de l'IA est tronquée dans la transcription, là où elle a été coupée | Must | S-05 | RG-17 ; **livrée par 011** sur `voice.interrupted` : orbe « Interrompue » puis « Écoute », réplique tronquée à `at_ms`, rail « interrompu » ([p-ar-frontend-screen](../architecture/frontend-screen.md)) ; mêmes réserves que FR-13 (Q-77, Q-79) |
| FR-20 | Un raccourci clavier fait taire l'IA, en secours si le micro capte mal | Must | S-09 | RG-21, RG-22 ; **J7** (non livrée par 011 : faire taire à la souris, S-09) ; **assouplie par pdr-0033** : faisable à la souris, raccourci s'il ne pose pas de problème ([pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md)) |

## Couverture BDD (constat de l'assistant)

| Constat | Exigences |
|---|---|
| Must sans scénario dédié dans la fiche | FR-05, FR-09, FR-11 (FR-01 n'apparaît que dans un `Contexte`) |
| Should sans scénario | FR-06, FR-12 |
| Couverture indirecte | FR-14 (via S-07) |

La DoD exige que « les 9 scénarios de la section 4 » soient vérifiés ([p-fn-risks-acceptance](risks-acceptance.md)). Aucun scénario n'est ajouté pour les exigences non couvertes (FR-05, FR-06, FR-09, FR-11, FR-12) : elles sont vérifiées par revue ([pdr-0049](../decisions/pdr-0049-sheet-gherkin-scenarios-only.md), Q-63 tranchée, coupe C4), voir [p-rm-backlog](../roadmap/backlog.md).

## Groupes fonctionnels

| Groupe | Exigences | Page de référence |
|---|---|---|
| Montrer la fabrication | FR-01..FR-06 | [p-fn-screen](screen.md) |
| Transformer et interagir | FR-07, FR-08 | [p-fn-catalog](catalog.md) |
| Régie de scène et rejeu | FR-09, FR-11, FR-12, FR-20 (FR-10 retirée) | [p-fn-screen](screen.md), [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md), [pdr-0033](../decisions/pdr-0033-optional-shortcuts-mouse-first.md) |
| Interruption (barge-in) | FR-13..FR-19 | [p-fn-business-rules](business-rules.md), [rt-barge-in], [ux-voice-multimodal] |

## Notes de traçabilité

- Les 4 Should (FR-06, FR-12, FR-17, FR-18) peuvent glisser sans casser le MVP ; les Must non.
- FR-13 à FR-19 dépendent du comportement d'interruption du fournisseur voix ([rt-barge-in]) et d'une annulation d'écho efficace ([rt-echo-cancellation]). ⚠️ Hypothèse non confirmée : « l'IA se tait immédiatement » (FR-13) n'est pas établi à la sortie des haut-parleurs ; le porteur a perçu un décalage à l'essai réel (2026-10-29) → Q-67. Fournisseur : `gpt-live-1`, [pdr-0012-voice-provider-openai](../decisions/pdr-0012-voice-provider-openai.md) (acceptée le 2026-10-29).

- **Après l'essai au micro (2026-10-30)** : FR-13, FR-14 (chemin « Stop »), FR-15, FR-16 et FR-19 sont **livrées par la fonctionnalité 011** ([pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), `gate --full` vert, 58 contrôles ; K-01 à K-07) ; **S-05 n'est couvert qu'en partie** (Q-77), FR-17 reste partielle, FR-12 et FR-20/S-09 restent à J7 ; hypothèses à vérifier en répétition : Q-78 à Q-80 ; FR-18 tenue (Q-41 conforme) ; **FR-04 (apparition en trois temps animée) et NFR-05 livrées par la fonctionnalité 013** le 2026-10-31 ([pdr-0072](../decisions/pdr-0072-design-ergonomics-013.md), [pdr-0075](../decisions/pdr-0075-013-design-ergonomics-details-assistant-decided.md), scénarios D-01 à D-07 : [p-fn-feature-design-ergonomics-013](features/design-ergonomie-013.feature), `gate --full` vert) ; NFR-04 : périmètre de reconstruction prouvé par test, 60 i/s à mesurer à J7.
