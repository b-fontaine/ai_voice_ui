---
id: p-ar-voice-interruption
title: Interruption vocale, « Stop », correction en vol, chevauchement, focus et fenêtre de demande (livrés par 011, 014 et 015)
area: architecture
status: draft
updated: 2026-10-31
sources: [specs/015-j7-overlap-interrupt-delegation-link/spec.md, specs/015-j7-overlap-interrupt-delegation-link/plan.md, specs/015-j7-overlap-interrupt-delegation-link/status.md, specs/014-j7-silence-micro-correction/spec.md, specs/014-j7-silence-micro-correction/plan.md, specs/014-j7-silence-micro-correction/status.md, specs/011-voice-interaction/spec.md, specs/011-voice-interaction/plan.md, specs/011-voice-interaction/tasks.md, specs/011-voice-interaction/status.md, product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md, knowledge:rt-barge-in, knowledge:rt-gpt-live-delegation, knowledge:rt-gpt-live-sideband, knowledge:rt-transcription, knowledge:proto-a2a-task-lifecycle]
links: [p-ar-voice-overlap, p-fn-feature-chevauchement-liaison-015, pdr-0077-011b-overlap-interrupt-delegation-link, pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided, pdr-0076-014-silence-mic-correction-assistant-decided, pdr-0033-optional-shortcuts-mouse-first, p-fn-feature-silence-micro-correction-014, p-ar-llm-composer, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0071-act2-focus-memory-act-indicator-click-feedback, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0056-failed-agent-partial-surfaces-removed, p-ar-app-channel-contract, p-ar-agents-protocols, p-ar-backend, p-ar-frontend-screen, p-ar-stage-runtime, p-fn-requirements, p-fn-business-rules, p-fn-feature-barge-in, p-rm-open-questions, p-rm-spikes, rt-barge-in, rt-gpt-live-delegation, rt-gpt-live-sideband, rt-gpt-live-lifecycle, rt-transcription, proto-a2a-task-lifecycle]
tags: [barge-in, stop, voix, focus, annulation, app-channel, 011, 014, 015, correction, silence, micro, chevauchement]
---
# Interruption vocale, « Stop », correction en vol, chevauchement, focus et fenêtre de demande (011, 014, 015)

**En bref.** Livré par la fonctionnalité 011 (2026-10-30, `gate --full` vert, 58 contrôles) : le backend repère « Stop » dans la transcription d'entrée, annule les délégations en vol sans fermer la session, retire les surfaces inachevées et publie `voice.interrupted` ; l'app coupe la piste audio distante. Le même lot corrige la fenêtre de demande et ajoute la mémoire de focus de l'acte 2. Décisions : [pdr-0069](../decisions/pdr-0069-voice-interruption-hybrid-stop-011.md), [pdr-0071](../decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md) (porteur) ; mécanismes : [pdr-0073](../decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md) (boucle, pdr-0062). Côté app : [p-ar-frontend-screen](frontend-screen.md) § 011. **014 (2026-10-31, `gate --full` vert, 67 contrôles)** ajoute la correction en vol, « Faire taire » et le micro coupé (§ Correction en vol, [pdr-0076](../decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md)). **015 (2026-10-31, `gate --full` vert, 67 contrôles)** ajoute le **chevauchement de parole** : couper l'IA en parlant, sans mot d'arrêt (S-05 complet ; § Chevauchement de parole, détail dans [p-ar-voice-overlap](voice-overlap.md)).

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

## Correction en vol (014, pdr-0076 D3, D4)

FR-17 (second temps) et FR-14 (chemin « correction ») : un mot de correction de tête (« Non, plutôt iOS ») annule la génération en vol et fait de la correction la consigne en vigueur, sans « Stop ». Scénarios : C-01 à C-05, S-07 ([p-fn-feature-silence-micro-correction-014](../functional/features/silence-micro-correction-014.feature)).

**Classifieur d'énoncé unique** (`StopDetector` étendu, résultat scellé `Stop` \| `Correction`, `Detection.Kind`) : un seul minuteur, anti-rebond partagé, toujours alimenté.

| Règle | Effet |
|---|---|
| Mot(s) de correction de tête suivi(s) d'un mot significatif, ni de correction ni d'arrêt | `Correction` ; **pas de plafond de mots** ; `at_ms` = `start_ms` du delta du premier mot de correction |
| « Non. » nue (fin d'énoncé) | sans effet (C-02) |
| Mot d'arrêt après un mot de correction de tête (« Non, stop ») | **`Stop`**, jamais planifié (C-03) |
| Mot de correction hors tête (« Concentre-toi plutôt sur iOS ») | pas une correction (TestR02) |
| Demande réduite à des mots de correction | non planifiée ; une correction coupée en deux délégations (« Non, » puis « plutôt iOS ») donne un seul plan (TestR03) |
| Mot de correction et mot d'arrêt en commun, ou préfixe (« non merci » contre « non ») | refusés au démarrage (config) |

**`Supersede(atMs, announce)`** (port `SessionDelegations`, non bloquant, distinct d'`Interrupt` qui reste inchangé) :

| Point | Contrat |
|---|---|
| Condition | une demande vocale **antérieure** à la correction est en vol (`runOffset < atMs`) ou en file (délégation vocale d'offset `< atMs`) ; jamais une action `act-<n>` ni la correction elle-même (C-05). Sinon rien n'est publié : le mot de correction est du texte ordinaire |
| Sous `session.mu` | époque incrémentée ; file vidée en gardant les actions et les délégations vocales d'offset `>= atMs`, **re-tamponnées à la nouvelle époque** ; `supersededBefore = atMs` ; `Window.ConsumeBefore(atMs)` (retire les deltas `start < atMs`, jamais le delta de la correction) |
| Hors verrou, dans cet ordre | `announce()` (publie `voice.interrupted {at_ms, cause: correction}`) **avant** `cancel` ; annulation de l'exécution en vol ; phrase `stopped` des délégations retirées |
| Effets | surfaces inachevées retirées, complètes conservées, actions jamais annulées (comme « Stop ») ; la correction est planifiée dans l'époque suivante avec la mémoire de focus (pdr-0071) et la correction de plateforme de 008 ; une délégation tardive d'offset `< supersededBefore` est écartée (`stopped`) ; garde d'époque dans `run()` après l'attente de la fenêtre |
| Côté app | `cause = correction` : l'interruption se termine à la **première délégation d'offset ≥ `at_ms`**, ou aussitôt si cette délégation a précédé `voice.interrupted` (C-04, S-07 bis) ; contrat : [p-ar-app-channel-contract](app-channel-contract.md) |

**Configuration** : `VOICE_CORRECTION_WORDS` (code : vide = détection coupée ; compose : `non,plutôt,en fait`), au plus 16 mots de 32 runes, message d'erreur sans recopier de mot. Elle **réutilise** `VOICE_STOP_UTTERANCE_GAP`, `VOICE_STOP_SETTLE` et `VOICE_STOP_DEBOUNCE` ; `VOICE_STOP_MAX_WORDS` ne s'applique pas à la correction.

⚠️ **Limite connue** : une délégation déjà **sortie de la file mais pas encore entrée dans `beginRun`** est invisible pour `Supersede` (ni en vol ni en file). La correction n'est pas perdue : l'ancienne demande s'exécute alors sans `voice.interrupted`, et la mémoire de focus (pdr-0071) fait le reste. Fenêtre de quelques instructions, acceptée et documentée dans le code (« Limite connue » de `Supersede`, revue R5) : la fermer en posant `supersededBefore` quand la condition est fausse écarterait à tort des délégations légitimes.

**Faire taire et micro coupé : locaux** (FR-20, FR-12, [pdr-0076](../decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md) D1, D6). Aucun message au backend, aucune écriture au journal : l'app coupe sa piste distante (événement local `VoiceSilenced`, traité comme `voice.interrupted` par la session, l'orbe, la transcription et le niveau) ou désactive sa piste micro locale (`track.enabled=false`, capture non arrêtée). `session.input_audio.mute` du sideband n'est pas utilisé ([rt-gpt-live-sideband]). « Faire taire » **n'annule aucune génération** (« Stop » vocal le fait) : si l'IA marque une pause d'au moins `GENESIS_INTERRUPT_RESUME_SILENCE_MS`, sa voix revient au milieu de la réplique ; ⚠️ non observé en réel. Côté app : [p-ar-frontend-screen](frontend-screen.md) § 014.

## Chevauchement de parole (015)

FR-13, FR-19, FR-18 (écho, côté logiciel seulement) : le speaker coupe l'IA en prenant la parole ([pdr-0077](../decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md), porteur ; [pdr-0080](../decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md), boucle). Détail, configuration et hypothèses : **[p-ar-voice-overlap](voice-overlap.md)**. Scénarios S-05, O-01 à O-08, L-01 à L-04 : [p-fn-feature-chevauchement-liaison-015](../functional/features/chevauchement-liaison-015.feature).

| Point | Contrat |
|---|---|
| Classifieur | troisième genre `Overlap` du classifieur de 014 ; priorité correction, arrêt, chevauchement ; anti-rebond asymétrique (un Stop n'est jamais filtré par un Overlap) |
| Garde « l'IA parle » | niveau de sortie ≥ `VOICE_OVERLAP_SPEAKING_LEVEL` ou delta de sortie dans `VOICE_OVERLAP_SPEAKING_WINDOW` ; **verrouillée à l'ouverture de l'énoncé** (le flux d'audio de sortie est continu, silence compris) |
| Mot significatif | jetons fermés, hors écho de la transcription de sortie (`VOICE_OVERLAP_ECHO_WINDOW`, mémo borné à 256), longueur et liste ignorée ; un nombre est dispensé de la longueur et de la liste, jamais de l'écho |
| Effet | `at_ms` = `start_ms` du premier delta de l'énoncé ; `voice.interrupted {cause: overlap}` **toujours**, puis `Supersede(atMs, nil)` (jamais `Interrupt`) ; une correction dite pendant que l'IA parle coupe aussi la voix |
| Configuration | sept variables `VOICE_OVERLAP_*` ; code = coupé, compose = activé ; `VOICE_STOP_SETTLE` > 0 exigé |
| Orbe | `overlap` en `Listening` : `Interrupted` puis `Listening` aussitôt ; en `Interrupted` : requalifié ; fin par délégation d'offset ≥ `at_ms` ou silence de reprise |

⚠️ Réglages à observer en répétition avec le porteur (Q-80, SP-06 pour l'AEC sur enceinte) : faux positifs d'écho, latence ≈ 1 s, fenêtre de parole de 2 s.

## Contrat ajouté à l'app-channel

| Élément | Contrat |
|---|---|
| `voice.interrupted` | `{at_ms}` (+ `cause?` depuis 014 : `stop`, `correction` ou (015) `overlap`, absent ou inconnu = `stop`) ; `at_ms` = `start_ms` du delta déclencheur (horloge média des transcripts, pas `t_ms`) ; **jamais rejoué** par le hub (comme `orb.level`) ; gardé dans le journal JSONL ; ignoré par `ReplayRouter` ; non A2UI |
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
| `VOICE_CORRECTION_WORDS` (014) | mots de correction de tête | code : vide ; compose : `non,plutôt,en fait` ; ≤ 16 mots de 32 runes ; réutilise les trois variables d'écart, de confirmation et d'anti-rebond ci-dessous |
| `VOICE_STOP_UTTERANCE_GAP`, `VOICE_STOP_MAX_WORDS` | écart d'un énoncé ; mots maximum | 1,5 s (1 ms à 10 s) ; 4 (1 à 32) |
| `VOICE_STOP_SETTLE`, `VOICE_STOP_DEBOUNCE`, `VOICE_STOP_SPAN` | confirmation ; anti-rebond ; écart de la demande vide | 400 ms (0 à 2 s) ; 2 s (0 à 10 s) ; 3 s (0 à 10 s) |
| `VOICE_OVERLAP_*` (015, sept variables) | chevauchement de parole | code : coupé ; compose : activé ; tableau dans [p-ar-voice-overlap](voice-overlap.md) |
| `VOICE_PHRASES_FILE` | phrase `stopped` **obligatoire** (`Phrases.Validate`) | défaut embarqué |

Consignes vocales (`voice-instructions.fr.md`) : se taire si le speaker parle, attendre la fin de phrase après une hésitation, commentaire final court ; `session.instructions.append` n'est pas utilisé (effet non démontré, [rt-gpt-live-lifecycle]). Variables de l'app : [p-ar-frontend-screen](frontend-screen.md).

## Hypothèses non confirmées (à vérifier en répétition)

| Hypothèse | Renvoi |
|---|---|
| GPT-Live crée une délégation pour « Stop » ; double accusé vocal possible (« D'accord. » par la délégation arrêtée, plus l'accusé du modèle) | Q-78 |
| `track.enabled = false` coupe la lecture (piste distante, 011) et la capture (piste micro locale, 014) sous `flutter_webrtc` Linux (spike T03 non fait) ; le setter de 1.6.3 n'attend pas l'appel natif : un échec n'est pas observable | Q-79 |
| `start_ms` de sortie et `at_ms` sur la même horloge ; deltas d'entrée jamais révisés ; « Stop » transcrit de façon fiable ; NFR-02 +300 ms | Q-80 |
| Couper la parole **sans** « Stop » : livré par 015 (Q-77 → pdr-0077) ; faux positifs d'écho sans AEC, latence ≈ 1 s, fenêtre de parole de 2 s à observer ([p-ar-voice-overlap](voice-overlap.md)) | Q-77, Q-80 |
| GPT-Live crée une délégation pour une correction prononcée pendant qu'une délégation est ouverte ; sans elle, le code annule et fait taire sans replanifier | Q-87 |
| Un « non » ordinaire en tête de phrase ne déclenche pas d'annulation indue ; la voix de l'IA qui revient après « Faire taire » (pause ≥ `resumeSilence`) est acceptable | pdr-0076 « Réexaminer si » |
