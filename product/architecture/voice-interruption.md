---
id: p-ar-voice-interruption
title: Interruption vocale, « Stop », focus et fenêtre de demande (livrés par 011)
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/011-voice-interaction/spec.md, specs/011-voice-interaction/plan.md, specs/011-voice-interaction/tasks.md, specs/011-voice-interaction/status.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md, knowledge:rt-barge-in, knowledge:rt-gpt-live-delegation, knowledge:rt-gpt-live-sideband, knowledge:rt-transcription, knowledge:proto-a2a-task-lifecycle]
links: [p-ar-llm-composer, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0056-failed-agent-partial-surfaces-removed, p-ar-app-channel-contract, p-ar-agents-protocols, p-ar-backend, p-ar-frontend-screen, p-ar-stage-runtime, p-fn-requirements, p-fn-business-rules, p-fn-feature-barge-in, p-rm-open-questions, p-rm-spikes, rt-barge-in, rt-gpt-live-delegation, rt-gpt-live-sideband, rt-gpt-live-lifecycle, rt-transcription, proto-a2a-task-lifecycle]
tags: [barge-in, stop, voix, focus, annulation, app-channel, 011]
---
# Interruption vocale, « Stop », focus et fenêtre de demande (011)

**En bref.** Livré par la fonctionnalité 011 (2026-10-30, `gate --full` vert, 58 contrôles) : le backend repère « Stop » dans la transcription d'entrée, annule les délégations en vol sans fermer la session, retire les surfaces inachevées et publie `voice.interrupted` ; l'app coupe la piste audio distante. Le même lot corrige la fenêtre de demande et ajoute la mémoire de focus de l'acte 2. Décisions : [pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), [pdr-0071](../decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md) (porteur) ; mécanismes : [pdr-0073](../decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md) (boucle, pdr-0062). Côté app : [p-ar-frontend-screen](frontend-screen.md) § 011.

## Chaîne « Stop »

| Étape | Où | Ce qui se passe |
|---|---|---|
| 1 | `app/voice` (`StopDetector`) | lit les deltas de la transcription d'entrée ([rt-transcription]) |
| 2 | idem | si le mot d'arrêt est confirmé : publie `voice.interrupted {at_ms}` **puis** `Interrupt` |
| 3 | `orchestrate` (époque) | annule l'exécution en cours, vide la file, compense les surfaces inachevées |
| 4 | agents A2A | `CancelTask` (contexte neuf, 1 s) ; `agent.activity canceled` pour chaque agent du plan |
| 5 | voix | une seule phrase `stopped` (jamais `Failure` ni `ResultTemplate`) |
| 6 | app | piste distante coupée, orbe « Interrompue » puis « Écoute », réplique tronquée |

La session reste ouverte ; les surfaces complètes restent (RG-14, FR-15). Un arrêt avant le `plan` n'en publie aucun.

## Détecteur de mots d'arrêt (pdr-0073 D2)

- **Règle** : concaténation des deltas tels quels ; un énoncé = deltas dont l'écart de `start_ms` reste sous `VOICE_STOP_UTTERANCE_GAP` ; déclenche si un mot d'arrêt est le **premier mot significatif** d'un énoncé d'au plus `VOICE_STOP_MAX_WORDS` mots. Normalisation : minuscules, accents conservés, ponctuation retirée, apostrophes et traits d'union gérés (« tais-toi »). « stoppé » et « bus stop » ne déclenchent pas.
- **Confirmation** : ponctuation terminale, `VOICE_STOP_SETTLE` sans nouveau delta (horloge injectée, `SettleNow()`) ou ouverture d'un nouvel énoncé ; jamais sur une simple frontière de mot. Candidat écarté dès que le nombre de mots dépasse le maximum. Anti-rebond `VOICE_STOP_DEBOUNCE` indexé sur le `start_ms` du déclencheur.
- **Liste** : `VOICE_STOP_WORDS`, au plus 16 mots de 32 runes, aucun vide ; **liste vide = détecteur coupé** (défaut du code) ; le compose pose `stop,tais-toi,annule,arrête`. Jamais codée en dur ([pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md)).
- **Demande réduite à des mots d'arrêt** : jamais planifiée (seule `stopped` part) ; la fenêtre est consommée jusqu'à `at_ms`, donc la demande suivante ne relit pas « Stop ». `VOICE_STOP_SPAN` (3 s) borne l'écart entre l'arrêt et la délégation reconnue comme telle.

## Annulation sans fermeture (pdr-0073 D3)

- `port.SessionDelegations.Interrupt(atMs)` : non bloquant, passé par la file FIFO du `forwarder`. Dans la session : incrément d'une **époque**, annulation du contexte de l'exécution en cours (`WithCancelCause`, cause `ErrInterrupted`), file vidée (`pending--` par délégation retirée). Aucun verrou du canevas n'est tenu pendant l'annulation ; `ErrSessionClosed` l'emporte.
- **Compensation** par la goroutine de `Run` : `Registry.CancelCompensation(taskID)` ne retire que les surfaces **inachevées**. Complétude par surface : `root` présent, références résolues, `updateDataModel` de `/<surface>` reçu ; les complètes gardent leur propriétaire (puis `Forget`).
- **Les actions `act-<n>` ne sont jamais annulées** (atomiques, `decisionStatus` non compensable).
- Hypothèse du plan : un arrêt pendant une transformation d'acte 2 peut laisser des surfaces sur la nouvelle vue et d'autres non.
- Les vrais agents finissent en 0 à 3 ms : S-06 n'est observable qu'avec des agents scriptés bloquants (K-03, `startTestAgent`), pas en direct.

## Contrat ajouté à l'app-channel

| Élément | Contrat |
|---|---|
| `voice.interrupted` | `{at_ms}` ; `at_ms` = `start_ms` du delta déclencheur (horloge média des transcripts, pas `t_ms`) ; **jamais rejoué** par le hub (comme `orb.level`) ; gardé dans le journal JSONL ; ignoré par `ReplayRouter` ; non A2UI |
| `agent.activity canceled` | **émis** depuis 011 (réservé depuis 004), sans `detail` ; terminal pour chaque agent de `plan.selected` ; le rail affiche « interrompu » |
| `genesis/intent` | métadonnée de l'état A2A `completed`, posée par l'agent : `{platform, compareTo}` ; validée par `a2aclient` **sur la forme seulement** (2 clés, 0 à 16 caractères `[A-Za-z0-9.]`) → `AgentUpdate.Intent` |
| `genesis/focus` | métadonnée de la requête A2A, posée par l'orchestrateur : `{platform, compareTo}` (`AgentRequest.Focus`) ; absente sans focus ; les agents restent sans état |
| `genesis/scopeReason` | métadonnée de l'état `rejected` : motif de `ScopeError` (ensemble fermé) ; journalisé en slog seulement, **jamais** dans `detail`, le JSONL ni l'app-channel ; depuis 012, le motif `view_unavailable` choisit en plus la phrase vocale de l'orchestrateur ([p-ar-llm-composer](llm-composer.md)) |

## Focus de l'acte 2 (Q-74, pdr-0071)

Le `Pipeline` met à jour `Canvas.Focus()` seulement si au moins un agent est `completed` et que tous les agents réussis concordent. Une comparaison sans plateforme **hérite de celle du focus** (`kit.ParseIntent(text, focus, ds)`) ; sans focus, le refus `compare_without_platform` subsiste. `ResetCanvas` efface le focus ; les actions ne le modifient pas ; son verrou entre dans l'ordre des verrous documenté (`Canvas.mu` en tête, [p-ar-app-channel-contract](app-channel-contract.md)).

## Fenêtre de demande

Bogue corrigé (`window.go`) : un mot commencé à l'offset de la délégation était perdu. `Delegate` ne bloque jamais (contrat du port) : il enregistre `(id, offset, instant)`, envoie le commentaire générique et met en file. Le `Take` se fait dans `session.run`, après le reste de `REQUEST_WINDOW_SETTLE` (arrêt anticipé dès qu'un delta a `start > offset + marge`). **Règle d'inclusion d'un delta** (écart tranché, pdr-0062) : `start < offset`, ou il commence **et** finit avant `offset + REQUEST_WINDOW_MARGIN` ; `consumed = max(consumed, offset + marge)`. File pleine : plus de `Take` immédiat. ⚠️ NFR-02 : jusqu'à 300 ms de plus, à remesurer (Q-80).

## Configuration (jamais codée en dur ; compose = défauts)

| Variable | Rôle | Défaut ; bornes |
|---|---|---|
| `REQUEST_WINDOW_SETTLE`, `REQUEST_WINDOW_MARGIN` | attente des deltas tardifs ; marge après l'offset | 300 ms, 400 ms ; 0 à 2 s |
| `VOICE_STOP_WORDS` | mots d'arrêt | code : vide ; compose : `stop,tais-toi,annule,arrête` |
| `VOICE_STOP_UTTERANCE_GAP`, `VOICE_STOP_MAX_WORDS` | écart d'un énoncé ; mots maximum | 1,5 s (1 ms à 10 s) ; 4 (1 à 32) |
| `VOICE_STOP_SETTLE`, `VOICE_STOP_DEBOUNCE`, `VOICE_STOP_SPAN` | confirmation ; anti-rebond ; écart de la demande vide | 400 ms (0 à 2 s) ; 2 s (0 à 10 s) ; 3 s (0 à 10 s) |
| `VOICE_PHRASES_FILE` | phrase `stopped` **obligatoire** (`Phrases.Validate`) | défaut embarqué |

Consignes vocales (`voice-instructions.fr.md`) : se taire si le speaker parle, attendre la fin de phrase après une hésitation, commentaire final court ; `session.instructions.append` n'est pas utilisé (effet non démontré, [rt-gpt-live-lifecycle]). Variables de l'app : [p-ar-frontend-screen](frontend-screen.md).

## Hypothèses non confirmées (à vérifier en répétition)

| Hypothèse | Renvoi |
|---|---|
| GPT-Live crée une délégation pour « Stop » ; double accusé vocal possible (« D'accord. » par la délégation arrêtée, plus l'accusé du modèle) | Q-78 |
| `track.enabled = false` coupe la lecture sous `flutter_webrtc` Linux (spike T03 non fait) | Q-79 |
| `start_ms` de sortie et `at_ms` sur la même horloge ; deltas d'entrée jamais révisés ; « Stop » transcrit de façon fiable ; NFR-02 +300 ms | Q-80 |
| Couper la parole **sans** « Stop » repose sur le modèle (S-05 en partie) | Q-77 |
