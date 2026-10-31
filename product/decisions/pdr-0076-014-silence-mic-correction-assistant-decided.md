---
id: pdr-0076-014-silence-mic-correction-assistant-decided
title: "PDR-0076 — 014 (J7-A) : faire taire et micro coupé locaux, correction en vol par mots de correction"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/014-j7-silence-micro-correction/spec.md, product/functional/features/barge-in.feature, knowledge:rt-barge-in, knowledge:rt-gpt-live-sideband]
links: [pdr-0033-optional-shortcuts-mouse-first, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0071-act2-focus-memory-act-indicator-click-feedback, p-ar-voice-interruption, p-fn-requirements, p-fn-screen, p-rm-open-questions, rt-barge-in, rt-gpt-live-sideband]
tags: [pdr, decision, voix, silence, micro, correction, 014]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0076 — 014 (J7-A) : faire taire et micro coupé locaux, correction en vol par mots de correction

> **En bref.** Détails d'interface et de mécanisme de FR-12, FR-20 et FR-17 (second temps), tranchés par la boucle sous pdr-0062 : la fiche est muette sur le détail, aucun choix de produit (périmètre, mise en scène, budget, fournisseur) n'est touché. À contester par le porteur.

Part de l'assistant : décision sur délégation (pdr-0062) ; les vrais choix restent au porteur (Q-77, Q-87).

## Contexte
FR-12 (couper le micro), FR-20 (faire taire, S-09) et FR-17 (correction en vol, S-07) restent à J7 ([p-fn-requirements](../functional/requirements.md)). [pdr-0033](pdr-0033-optional-shortcuts-mouse-first.md) : souris d'abord, raccourcis facultatifs. [pdr-0069](pdr-0069-voice-interruption-hybrid-stop-011.md) : détection déterministe par mots, coupure locale de la piste. [rt-barge-in] : GPT-Live n'a aucun événement d'interruption ; [rt-gpt-live-sideband] : `session.input_audio.mute` existe côté serveur.

## Hypothèses
- ✅ Un mot d'arrêt et une coupure locale de la piste existent déjà (011, `gate --full` vert).
- ⚠️ Hypothèse non confirmée : GPT-Live crée une délégation pour une correction prononcée alors qu'une délégation est ouverte → Q-87.
- ⚠️ Hypothèse non confirmée : `track.enabled = false` coupe aussi le micro local sous `flutter_webrtc` Linux (même famille que Q-79).

## Options
1. **Faire taire et micro coupé locaux ; correction par mots de correction injectés** (retenue)
2. Faire taire = `Stop` complet (annule aussi la génération) ; micro coupé par `session.input_audio.mute` côté serveur
3. Correction par simple prise de parole (Q-77, au porteur)

## Décision
- **D1** Faire taire (FR-20) : coupure locale de la piste distante + orbe « Interrompue » ; **ne ferme pas la session, n'annule aucune génération, n'écrit rien au backend**. Micro coupé (FR-12) : `track.enabled=false` sur la piste locale (aucun arrêt de capture), orbe « Micro coupé » ; réarmé à chaque nouveau démarrage.
- **D2** Deux boutons dans la régie (souris d'abord). Raccourcis : `M` (micro) et `Échap` (silence), facultatifs, sans effet hors session ; **pas `Espace`** (il activerait le bouton focalisé, [ux-desktop-shortcuts]) ; l'écart à la fiche (Espace) est consigné ici.
- **D3** Correction (FR-17) : liste `VOICE_CORRECTION_WORDS` (compose : `non,plutôt,en fait`), détecteur frère de celui des mots d'arrêt, reste de l'énoncé conservé ; effet seulement si une exécution vocale est en vol ou en file : `voice.interrupted`, annulation par époque, surfaces inachevées retirées, délégations d'offset ≥ `at_ms` conservées ; un mot d'arrêt prime ; correction nue ignorée.

- **D1 bis** (revue du plan) : faire taire émet un événement local `VoiceSilenced` traité par les quatre consommateurs de `voice.interrupted` (session, orbe, transcription, niveau) ; le bouton est actif quand la session est `Active` et la phase n'est pas `Interrompue` (idempotent). Le micro coupé est un voile sur la phase réelle (`Active(micMuted)`), pas une phase de l'orbe.
- **D4** (revue du plan) : `voice.interrupted` gagne un champ facultatif fermé `cause ∈ {stop, correction}` (absent = `stop`) ; avec `correction`, la première délégation d'offset ≥ `at_ms` termine l'interruption côté app. Côté orchestrateur, point d'entrée distinct `Supersede(atMs, announce)` : ne s'applique qu'à une demande vocale **antérieure** à la correction en vol ou en file, conserve la correction (époque re-tamponnée), écarte le texte antérieur et les délégations tardives antérieures ; `Interrupt` reste inchangé. Un seul classifieur d'énoncé (Stop \| Correction) ; « Non, stop » est un Stop.

## Raisons
- Le micro coupé local suffit (la piste désactivée émet du silence) et ne dépend d'aucun message ; le mute serveur ajouterait un second propriétaire de l'état du micro.
- « Faire taire » est un secours si le micro capte mal (FR-20) : y ajouter l'annulation de la génération casserait l'idempotence d'une action de secours.
- La correction par mots reprend la mécanique déjà testée (011) sans trancher Q-77.

## Options écartées
- Mute serveur : second propriétaire, aucune nécessité démontrée.
- Silence = Stop complet : non demandé par FR-20 ; « Stop » vocal l'assure déjà.
- Correction sur prise de parole : Q-77 est au porteur.

## Conséquences
- [p-ar-voice-interruption](../architecture/voice-interruption.md), [p-fn-screen](../functional/screen.md), [p-fn-requirements](../functional/requirements.md) (FR-12, FR-17, FR-20), [p-fn-business-rules](../functional/business-rules.md) (RG-15, RG-22), `barge-in.feature` : à mettre à jour à la clôture de 014.
- Q-87 ouverte (non bloquante).

## Réexaminer si
- L'essai en répétition montre qu'un « non » ordinaire déclenche des annulations indues (réduire la liste ou la vider) ; que `Échap` entre en conflit avec le focus ; que GPT-Live ne crée pas de délégation pour la correction (Q-87).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (délégation pdr-0062) | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
