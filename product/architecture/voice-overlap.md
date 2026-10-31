---
id: p-ar-voice-overlap
title: Chevauchement de parole (015) : couper l'IA sans mot d'arrêt
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/015-j7-overlap-interrupt-delegation-link/spec.md, specs/015-j7-overlap-interrupt-delegation-link/plan.md, specs/015-j7-overlap-interrupt-delegation-link/status.md, product/sources/product-description.pdf#p5, knowledge:rt-barge-in, knowledge:rt-transcription, knowledge:rt-gpt-live-output-level, knowledge:rt-gpt-live-delegation-latency, knowledge:rt-echo-cancellation, knowledge:ux-voice-multimodal]
links: [p-ar-voice-interruption, p-ar-voice-recovery, p-fn-feature-garde-fou-reprise-016, p-ar-app-channel-contract, p-ar-frontend-screen, p-ar-stage-runtime, p-fn-requirements, p-fn-business-rules, p-fn-screen, p-fn-feature-barge-in, p-fn-feature-chevauchement-liaison-015, p-rm-open-questions, p-rm-spikes, pdr-0077-011b-overlap-interrupt-delegation-link, pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided, pdr-0076-014-silence-mic-correction-assistant-decided, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, rt-barge-in, rt-transcription, rt-gpt-live-output-level, rt-gpt-live-delegation-latency, rt-echo-cancellation, ux-voice-multimodal]
tags: [barge-in, chevauchement, voix, echo, interruption, orbe, 015, 011b]
---
# Chevauchement de parole (015) : couper l'IA sans mot d'arrêt

**En bref.** Livré par 015 (2026-10-31, `gate --full` vert, 67 contrôles) : le speaker coupe la voix de l'IA en prenant simplement la parole (S-05 complet, FR-13, FR-19), sans « Stop ». Le backend juge l'énoncé d'entrée (mot significatif, hors écho de l'IA, pendant que l'IA parle) et publie `voice.interrupted {cause: overlap}` ; l'app coupe sa piste distante. Décision : [pdr-0077](../decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md) (porteur, Q-77) ; réalisation : [pdr-0080](../decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md) (boucle, pdr-0062). Complète [p-ar-voice-interruption](voice-interruption.md) (011, 014). Seuils = valeurs de départ, **à régler en répétition** (Q-80, SP-06) ; rien ici ne prouve le comportement acoustique réel.

## Classifieur à trois genres

Le classifieur d'énoncé unique de 014 (`StopDetector`) gagne `KindOverlap` : même minuteur, même énoncé, anti-rebond partagé, un énoncé tranché n'est plus réévalué. Code : `internal/app/voice/{overlap.go,stopword.go,service.go}`.

| Priorité | Genre | Condition |
|---|---|---|
| 1 | `Correction` | tête de correction, ou début d'un mot de correction (`CouldStart`) |
| 2 | `Stop` | tête d'arrêt, ou début d'un mot d'arrêt |
| 3 | `Overlap` | mots significatifs en nombre suffisant, garde « l'IA parle » vraie |

- Un « Stop » écarté pour longueur (« Stop, montre plutôt Android pour la 3.3 ») est évalué en `Overlap`.
- **Anti-rebond asymétrique** : un `Overlap` qui suit un `Stop` ou une `Correction` de moins de `VOICE_STOP_DEBOUNCE` est filtré ; un `Stop` n'est jamais filtré par un `Overlap`.
- Un seul `voice.interrupted` par énoncé dans tous les cas (test de non-doublon, O-06).
- `VOICE_STOP_SETTLE` doit être **> 0** quand le chevauchement est actif (sinon le jeton ouvert serait jugé aussitôt) : refusé au démarrage, message nommant les deux variables.

## Garde « l'IA parle »

Le flux `output_audio` du sideband est **continu, silence compris** : un bloc ne prouve rien ([rt-gpt-live-output-level]). Les blocs arrivent toutes les 200 ms.

| Point | Règle |
|---|---|
| Vrai si | un bloc de niveau ≥ `VOICE_OVERLAP_SPEAKING_LEVEL` (niveau déjà calculé par `translate`, un seul calcul RMS) **ou** un delta de transcription de sortie date de moins de `VOICE_OVERLAP_SPEAKING_WINDOW` |
| Horloge | injectée (`port.Clock`), jamais `time.Now` |
| Verrouillage | évaluée **au premier delta d'entrée de l'énoncé** (`speakingAtOpen`) et non ensuite : GPT-Live coupe sa propre voix 0,6 à 1 s après le début de la parole, avant qu'un mot ne soit confirmé |
| Garde fausse | rien n'est déclenché : tour de parole ordinaire (O-07) |

## Mots significatifs et écho

- **Jetons fermés seulement** (suivis d'un séparateur) : les deltas sont des fragments (« Andr » puis « oid »). Le dernier jeton ouvert est jugé au delta suivant ou à `Settle`.
- **Écho** = mots normalisés de la transcription de **sortie**, jetons fermés, dans les `VOICE_OVERLAP_ECHO_WINDOW` dernières millisecondes (horloge média, ⚠️ Q-80) ; mémo : file `(mot, end_ms)` plus compteur par mot, plafonné à **256** ; le dernier mot d'une réplique sans ponctuation est versé à l'écho quand la réplique suivante s'ouvre (écart ≥ `VOICE_STOP_UTTERANCE_GAP`).
- **Mot significatif** : hors écho ; sinon longueur ≥ `VOICE_OVERLAP_MIN_WORD_LEN` runes et hors `VOICE_OVERLAP_IGNORE_WORDS`. Un **nombre** (« 3.3 ») est dispensé de la longueur et de la liste ignorée, **jamais de l'écho** (pdr-0080 D3, revue R1). Déclenchement à `VOICE_OVERLAP_MIN_WORDS` mots distincts.
- Limite connue : « d'accord » dans la liste ignorée ignore aussi « accord » (découpage par jeton, Q-80).

## Effet

| Étape | Contrat |
|---|---|
| `at_ms` | `start_ms` du **premier delta de l'énoncé** (les mots de tête écartés restent dans la demande du speaker : `ConsumeBefore(atMs)`) |
| 1 | `voice.interrupted {at_ms, cause: overlap}` publié **toujours** (la voix se coupe même sans exécution en vol), avant toute annulation |
| 2 | `Supersede(atMs, nil)` : une demande antérieure à `at_ms` en vol ou en file est annulée (surfaces inachevées retirées, complètes conservées, actions jamais annulées) ; les délégations d'offset ≥ `at_ms` (la demande du speaker) sont conservées et planifiées |
| Jamais | `Interrupt` (il exempterait la demande du speaker) ; aucun message au fournisseur |
| Correction dite pendant que l'IA parle | publie aussi `voice.interrupted {correction}` (chevauchement actif, garde vraie, `Detection.Speaking`) même sans exécution en vol, puis `Supersede(atMs, nil)` ; sans chevauchement actif : comportement de 014 |

⚠️ **Cas décidé par pdr-0077** : un commentaire (« super ») par-dessus l'accusé de **sa propre** demande en vol l'annule ; sans nouvelle délégation (Q-87) le canevas reste interrompu. Atténué par la liste de mots ignorés du compose (O-08).

## Configuration (valeur nulle du code = coupé ; compose = activé)

| Variable | Rôle | Code ; compose | Bornes |
|---|---|---|---|
| `VOICE_OVERLAP_INTERRUPT` | active le chevauchement | coupé ; `true` | booléen |
| `VOICE_OVERLAP_SPEAKING_LEVEL` | niveau de sortie « l'IA parle » | requis si actif ; 0,02 | 0 < x ≤ 1 |
| `VOICE_OVERLAP_SPEAKING_WINDOW` | ancienneté maximale de la dernière parole de l'IA | requis ; 2 s | 200 ms à 10 s |
| `VOICE_OVERLAP_ECHO_WINDOW` | fenêtre média des mots d'écho | requis ; 8 s | 1 à 60 s |
| `VOICE_OVERLAP_MIN_WORDS` | mots significatifs distincts requis | requis ; 1 | 1 à 8 |
| `VOICE_OVERLAP_MIN_WORD_LEN` | longueur minimale d'un mot (runes) | requis ; 3 | 1 à 16 |
| `VOICE_OVERLAP_IGNORE_WORDS` | mots vides, interjections, acquiescements | vide ; mots vides français plus `ok,oui,super,merci,d'accord,parfait,voilà,vas-y,euh,hum,ben,bah,bon` | ≤ 64 mots de 32 runes |

Erreurs de configuration sans recopier de mot. `VOICE_OVERLAP_INTERRUPT=false` rend le comportement de 014 (tous les tests de 011 et 014 passent inchangés). L'acceptation Go entière tourne avec les valeurs du compose (lues par les helpers, sans repli silencieux). `StopConfig.Active()` (arrêt, correction ou chevauchement) décide de la construction du classifieur.

## Côté app : orbe

[pdr-0080](../decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md) D5 ; `OrbPhaseBloc` (`_InterruptionKind.overlap`), détail dans [p-ar-frontend-screen](frontend-screen.md).

| Phase à la réception | Résultat |
|---|---|
| `Speaking` | `Interrupted` ; piste coupée ; réplique tronquée à `at_ms` |
| `Listening` (le fournisseur a déjà coupé sa voix, message vers 1 s) | `Interrupted` puis `Listening` aussitôt (piste rétablie, la nouvelle réplique est audible) |
| `Interrupted` (coupure en cours) | coupure **requalifiée** en `overlap` avec son `at_ms`, **sans la terminer** (revue R10) |

Fin d'une interruption `overlap` : première délégation d'offset ≥ `at_ms`, ou aussitôt si elle a précédé le message, ou silence de reprise (`GENESIS_INTERRUPT_RESUME_SILENCE_MS`).

## Hypothèses non confirmées (à observer en répétition, Q-80)

| Hypothèse | Risque |
|---|---|
| Sans AEC, l'entrée transcrit l'écho de l'IA à l'identique : le filtre par mots suffit ([rt-echo-cancellation]) | faux positifs d'écho sur enceinte ; AEC sur enceinte = SP-06 |
| Latence de la coupure ≈ 1 s ([rt-gpt-live-delegation-latency]) | coupure perçue tardive |
| Fenêtre de parole de 2 s | un speaker qui reprend la parole jusqu'à ≈ 1 à 1,4 s après la fin de la voix de l'IA est classé en chevauchement, sa demande en vol peut être annulée ; piste : comparer le `start_ms` d'entrée au dernier `end_ms` de sortie |
| `start_ms` d'entrée et de sortie sur la même horloge média | élagage de l'écho faussé |

## Suite : 016 (reprise après un chevauchement)

016 (livrée le 2026-10-31) s'appuie sur ce chevauchement : `NoteOverlap` mémorise `at_ms`, et une demande dite par-dessus l'IA, mal transcrite puis refusée, fait dire « pouvez-vous répéter ? » (`no_request`, un seul passage, `VOICE_RECOVERY_WINDOW`). Le chevauchement lui-même ne change pas (aucun message nouveau, contrat de l'app-channel inchangé). Détail et hypothèses : [p-ar-voice-recovery](voice-recovery.md) ; la transcription dégradée en chevauchement est le point (d) de Q-80.

Tests : `backend/orchestrator/acceptance/overlap_*_test.go` (O-01 à O-08) ; scénarios : [p-fn-feature-chevauchement-liaison-015](../functional/features/chevauchement-liaison-015.feature).
