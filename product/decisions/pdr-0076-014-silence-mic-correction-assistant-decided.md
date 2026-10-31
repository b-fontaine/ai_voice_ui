---
id: pdr-0076-014-silence-mic-correction-assistant-decided
title: "PDR-0076 — 014 (J7-A) : faire taire et micro coupé locaux, correction en vol par mots de correction"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/014-j7-silence-micro-correction/spec.md, specs/014-j7-silence-micro-correction/plan.md, specs/014-j7-silence-micro-correction/status.md, product/functional/features/barge-in.feature, knowledge:rt-barge-in, knowledge:rt-gpt-live-sideband]
links: [pdr-0033-optional-shortcuts-mouse-first, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0071-act2-focus-memory-act-indicator-click-feedback, p-ar-voice-interruption, p-ar-app-channel-contract, p-ar-frontend-screen, p-ar-stage-runtime, p-fn-requirements, p-fn-business-rules, p-fn-nfr, p-fn-screen, p-fn-feature-silence-micro-correction-014, p-fn-feature-barge-in, p-rm-open-questions, rt-barge-in, rt-gpt-live-sideband, rt-gpt-live-delegation, ux-desktop-shortcuts]
tags: [pdr, decision, voix, silence, micro, correction, 014, regie, raccourcis]
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
- **D3** Correction (FR-17) : liste `VOICE_CORRECTION_WORDS` (compose : `non,plutôt,en fait`), reste de l'énoncé conservé ; effet seulement si une exécution vocale est en vol ou en file : `voice.interrupted`, annulation par époque, surfaces inachevées retirées, délégations d'offset ≥ `at_ms` conservées ; un mot d'arrêt prime ; correction nue ignorée. **Précisé à la clôture** : un **classifieur d'énoncé unique** (Stop \| Correction) remplace le détecteur frère (un minuteur, anti-rebond partagé, toujours alimenté) ; `Supersede` est un point d'entrée **distinct** d'`Interrupt` ; le texte antérieur est écarté de la fenêtre de demande ; `voice.interrupted` porte `cause` (D4) ; côté app, l'interruption d'une correction **se termine à la première délégation d'offset ≥ `at_ms`**, ou aussitôt si cette délégation a précédé `voice.interrupted`.

- **D1 bis** (revue du plan) : faire taire émet un événement local `VoiceSilenced` traité par les quatre consommateurs de `voice.interrupted` (session, orbe, transcription, niveau) ; le bouton est actif quand la session est `Active` et la phase n'est pas `Interrompue` (idempotent). Le micro coupé est un voile sur la phase réelle (`Active(micMuted)`), pas une phase de l'orbe.
- **D4** (revue du plan) : `voice.interrupted` gagne un champ facultatif fermé `cause ∈ {stop, correction}` (absent = `stop`) ; avec `correction`, la première délégation d'offset ≥ `at_ms` termine l'interruption côté app. Côté orchestrateur, point d'entrée distinct `Supersede(atMs, announce)` : ne s'applique qu'à une demande vocale **antérieure** à la correction en vol ou en file, conserve la correction (époque re-tamponnée), écarte le texte antérieur et les délégations tardives antérieures ; `Interrupt` reste inchangé. Un seul classifieur d'énoncé (Stop \| Correction) ; « Non, stop » est un Stop.

- **D5** (détails d'interface tranchés en T13/T14, sous pdr-0062, contestables) :
  - **Régie à deux colonnes de 480 px** (968 px au total) : colonne gauche « Couper le micro » / « Rétablir le micro » puis « Faire taire » ; colonne droite indicateur d'acte puis « Remettre à vide » ; cibles ≥ 48 px, libellés à 24 px sans ellipse.
  - **Voile « Micro coupé »** : disque grisé barré de 64 px avec le libellé à 24 px sous l'orbe, posé **par-dessus** la phase réelle de l'IA (pas de phase `MicMuted`, donc « Faire taire » reste possible micro coupé).
  - **Réplique de l'IA limitée à une ligne** quand un message d'état est affiché (deux lignes sinon), pour ne pas déborder de la barre du haut.
  - **Page** : `Focus(autofocus)` à la racine + `Shortcuts`/`Actions` ; `M` (micro) et `Échap` (silence) sans effet hors session ; jamais `Espace` (D2).
- **D6** Micro coupé : `setMicEnabled` rend un **booléen** (vrai si la plateforme a appliqué la commande) et `Active(micMuted)` n'est posé que sur succès ; sinon l'état reste « non coupé » et l'erreur est consignée. ⚠️ Hypothèse non confirmée : dans `flutter_webrtc` 1.6.3 le setter `track.enabled` n'attend pas l'appel natif `mediaStreamTrackSetEnable` ; un échec natif n'est donc pas observable, et la coupure de la piste reste à vérifier en réel (Q-79).

## Raisons
- Le micro coupé local suffit (la piste désactivée émet du silence) et ne dépend d'aucun message ; le mute serveur ajouterait un second propriétaire de l'état du micro.
- « Faire taire » est un secours si le micro capte mal (FR-20) : y ajouter l'annulation de la génération casserait l'idempotence d'une action de secours.
- La correction par mots reprend la mécanique déjà testée (011) sans trancher Q-77.

## Options écartées
- Mute serveur : second propriétaire, aucune nécessité démontrée.
- Silence = Stop complet : non demandé par FR-20 ; « Stop » vocal l'assure déjà.
- Correction sur prise de parole : Q-77 est au porteur.

## Conséquences
- Documents mis à jour à la clôture de 014 (2026-10-31) : [p-ar-voice-interruption](../architecture/voice-interruption.md), [p-ar-app-channel-contract](../architecture/app-channel-contract.md), [p-ar-frontend-screen](../architecture/frontend-screen.md), [p-ar-stage-runtime](../architecture/stage-runtime.md), [p-fn-screen](../functional/screen.md), [p-fn-requirements](../functional/requirements.md) (FR-12, FR-14, FR-17, FR-20), [p-fn-business-rules](../functional/business-rules.md) (RG-15, RG-22), [p-fn-nfr](../functional/nfr.md) (NFR-12), [barge-in.feature](../functional/features/barge-in.feature), [silence-micro-correction-014.feature](../functional/features/silence-micro-correction-014.feature).
- Q-87 ouverte (non bloquante) ; Q-79 complétée (micro local, setter asynchrone non observable).
- **Faire taire ne coupe que la voix** (D1) : l'orchestration n'est pas annulée. Si l'IA marque une pause d'au moins `GENESIS_INTERRUPT_RESUME_SILENCE_MS`, l'app rétablit la piste et **sa voix revient au milieu de la réplique** ; ⚠️ non observé en réel, à valider en répétition.
- La réplique de l'IA tient sur **une ligne** tant qu'un message d'état est affiché (D5) : une réplique longue est tronquée visuellement dans cette situation.

## Réexaminer si
- L'essai en répétition montre qu'un « non » ordinaire déclenche des annulations indues (réduire la liste ou la vider) ; que `Échap` entre en conflit avec le focus ; que GPT-Live ne crée pas de délégation pour la correction (Q-87).
- La réplique à une ligne (D5) gêne la lecture à la projection (réexaminer la hauteur de la barre du haut) ; le retour de la voix de l'IA au milieu de la réplique après « Faire taire » est jugé gênant (faire annuler la génération, ce qui est déjà le sens de « Stop » vocal) ; la coupure de la piste locale ou distante n'est pas audible sous Linux (Q-79).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (délégation pdr-0062) | Assistant (délégation du porteur, pdr-0062) |
| 2026-10-31 | **Livrée par 014** (`gate --full` vert, 67 contrôles : `.omc/state/loop/gates/20261031-060732-full.log`). D3 précisé ; D5 (régie, voile, réplique à une ligne, page) et D6 (`setMicEnabled` booléen) ajoutés, détails tranchés en T13/T14 et à la revue du code (R2, R9) sous pdr-0062. Aucune parole nouvelle du porteur ; non observé en réel (Q-79, Q-87) | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
