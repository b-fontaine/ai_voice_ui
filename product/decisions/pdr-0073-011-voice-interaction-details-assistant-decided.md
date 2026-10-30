---
id: pdr-0073-011-voice-interaction-details-assistant-decided
title: "PDR-0073 — 011 : détails de l'interruption vocale, du focus et du retour au clic"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/011-voice-interaction/spec.md, specs/011-voice-interaction/plan.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-fn-requirements, p-ar-app-channel-contract, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0065-009-act3-interact-details-assistant-decided, rt-barge-in, p-ar-voice-interruption, p-ar-agents-protocols, p-ar-backend, p-ar-frontend-screen, p-ar-stage-runtime, p-fn-screen, p-fn-business-rules, p-fn-feature-voice-interaction-011, p-fn-feature-voice-screen-generation, p-fn-feature-barge-in]
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
| **D2** | **Détecteur de mots d'arrêt** (amendé par la revue du code, R1-R2) : le mot d'arrêt doit être le **premier mot significatif** d'un énoncé d'au plus `VOICE_STOP_MAX_WORDS` mots (4 par défaut) ; énoncé = suite de deltas dont l'écart de `start_ms` reste sous `VOICE_STOP_UTTERANCE_GAP` ; confirmé seulement à une ponctuation terminale, à `VOICE_STOP_SETTLE` sans nouveau delta ou à l'ouverture d'un nouvel énoncé (jamais sur une simple frontière de mot) ; candidat écarté dès que le nombre de mots dépasse le maximum ; anti-rebond sur le `start_ms` du delta déclencheur ; une demande réduite à des mots d'arrêt n'est jamais planifiée (`VOICE_STOP_SPAN` borne l'écart d'une demande vide) ; liste injectée (`VOICE_STOP_WORDS`, liste vide = détecteur coupé), jamais codée en dur. |
| **D3** | **Annulation sans fermeture** : `Interrupt` du port des délégations, époque et contexte annulé par cause (pas de verrou du canevas tenu pendant l'annulation) ; les actions `act-<n>` ne sont pas annulées ; le statut d'agent `canceled`, réservé au contrat depuis 004, est désormais émis. Les surfaces complètes restent (RG-14). |
| **D4** | **Focus** : métadonnée A2A `genesis/focus` (liste fermée : plateforme, comparaison), l'orchestrateur la tient à partir de `genesis/intent` renvoyée par les agents réussis du canevas ; les agents restent sans état. |
| **D5** | **Motif des refus** dans le journal de l'orchestrateur seulement ; le `detail` d'`agent.activity` reste l'ensemble fermé (« hors périmètre »). |
| **D6** | **Indicateur d'acte** : événement monotone `StageActReached` (max) ; acte 2 à l'apparition de la surface `actions`, acte 3 à `ActionRunning` ; ni l'ouverture d'une session voix ni le message `plan` ne servent de signal. |
| **D7** | **Clic idempotent côté client** : le bouton de l'action déjà en place passe à « fait » et ne renvoie aucune requête ; pas d'idempotence backend (amendé par la revue du plan : un 202 sans activité laisserait l'action « en cours » 60 s). |

## Raisons
Mécanismes déduits du diagnostic de l'essai au micro (journaux contre-vérifiés) ; chacun est la seule voie testable sans toucher aux contrats `genesis/v1`.

## Conséquences
Documents mis à jour à la clôture de 011 (2026-10-30), sans changement des décisions ci-dessus :
- [p-ar-voice-interruption](../architecture/voice-interruption.md) (D1-D5 : détecteur, annulation, focus, contrat, réglages) ; [p-ar-app-channel-contract](../architecture/app-channel-contract.md) (`voice.interrupted`, `canceled`, métadonnées A2A) ; [p-ar-agents-protocols](../architecture/agents-protocols.md) et [p-ar-backend](../architecture/backend.md) (séquence « Stop », règle 6).
- [p-ar-frontend-screen](../architecture/frontend-screen.md) § 011 et [p-ar-stage-runtime](../architecture/stage-runtime.md) (D1, D6, D7 : coupure du son, orbe, indicateur d'acte, bouton « fait ») ; [p-fn-screen](../functional/screen.md).
- [p-fn-requirements](../functional/requirements.md) (FR-08, FR-13 à FR-20), [p-fn-business-rules](../functional/business-rules.md) (RG-11 à RG-17) ; scénarios [voice-interaction-011.feature](../functional/features/voice-interaction-011.feature) (K-03 à K-07), [voice-screen-generation.feature](../functional/features/voice-screen-generation.feature) (K-01, K-02), [barge-in.feature](../functional/features/barge-in.feature).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-40, Q-42, Q-67, Q-74 et Q-75 implémentées par 011 ; hypothèses d'observation Q-78 à Q-80 ; Q-77 reste ouverte.

## Réexaminer si
Le mot-clé déclenche à tort en répétition, ou la piste distante ne se coupe pas sur `flutter_webrtc` Linux.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée (délégation pdr-0062). | Assistant |
| 2026-10-30 | Amendée par la revue du plan (D3, D4, D7). Q-77 ouverte (déclencheur sur prise de parole). | Assistant |
| 2026-10-30 | Amendée par la revue du code : D2 (règle du premier mot significatif et `MaxWords` effectif mot à mot, `VOICE_STOP_SPAN`). Le client ignore une délégation datée du « Stop » pour rétablir la voix (`GENESIS_INTERRUPT_STOP_SPAN_MS`). | Assistant |
