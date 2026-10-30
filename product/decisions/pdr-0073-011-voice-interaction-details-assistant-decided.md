---
id: pdr-0073-011-voice-interaction-details-assistant-decided
title: "PDR-0073 — 011 : détails de l'interruption vocale, du focus et du retour au clic"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/011-voice-interaction/spec.md, specs/011-voice-interaction/plan.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-fn-requirements, p-ar-app-channel-contract, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0065-009-act3-interact-details-assistant-decided, rt-barge-in]
tags: [pdr, decision, voix, stop, focus, 011]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0073 — 011 : détails de l'interruption vocale, du focus et du retour au clic

> **En bref.** pdr-0069 et pdr-0071 fixent le résultat ; ils sont muets sur le mécanisme. La boucle tranche sept détails sous pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Décision
| Id | Décision |
|---|---|
| **D1** | **Événement `voice.interrupted {at_ms}`** sur l'app-channel, un seul type nouveau ; il sert au « Stop » détecté (pdr-0069) et déclenche la coupure locale, l'orbe « Interrompue » puis « Écoute » et la troncature de la réplique. |
| **D2** | **Détecteur de mots d'arrêt** : correspondance sur mots entiers, fenêtre glissante de 6 mots, anti-rebond configurable ; liste injectée (`VOICE_STOP_WORDS`), jamais codée en dur. |
| **D3** | **Annulation sans fermeture** : `Manager.CancelInFlight` ; le statut d'agent `canceled`, réservé au contrat depuis 004, est désormais émis. Les surfaces complètes restent (RG-14). |
| **D4** | **Focus** : métadonnée A2A `genesis/focus` (liste fermée : plateforme, vue), calculée par l'orchestrateur à partir de la dernière intention réussie du canevas ; les agents restent sans état. |
| **D5** | **Motif des refus** dans le journal de l'orchestrateur seulement ; le `detail` d'`agent.activity` reste l'ensemble fermé (« hors périmètre »). |
| **D6** | **Indicateur d'acte** : événement monotone `StageActReached` (max) ; acte 2 à l'apparition de la surface `actions`, acte 3 à `ActionRunning` ; ni l'ouverture d'une session voix ni le message `plan` ne servent de signal. |
| **D7** | **Clic idempotent** : une action dont l'effet est en place répond comme un succès sans nouvelle annonce vocale ; le bouton passe à « fait ». |

## Raisons
Mécanismes déduits du diagnostic de l'essai au micro (journaux contre-vérifiés) ; chacun est la seule voie testable sans toucher aux contrats `genesis/v1`.

## Réexaminer si
Le mot-clé déclenche à tort en répétition, ou la piste distante ne se coupe pas sur `flutter_webrtc` Linux.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée (délégation pdr-0062). | Assistant |
