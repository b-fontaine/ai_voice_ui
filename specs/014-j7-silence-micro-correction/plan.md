# 014 — Plan technique (amendé par la revue du plan : P1 à P8)

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `packages/features/voice_session` (model) | model | `VoiceSessionEvent` `VoiceMicMuteRequested(bool muted)` (valeur cible, `sequential()`), `Active({bool micMuted = false})` avec `==`/`hashCode` incluant `micMuted` ; `VoiceSession.setMicMuted`, `silenceRemote()` ; remise à faux dans `start()` et `_release()` ; `OrbPhase` inchangé (`Listening \| Speaking \| Interrupted`) |
| Flutter | `packages/features/voice_session` (api) | api | `VoiceTransport.setMicEnabled(bool)`, frontière `RtcMic.setEnabled(bool)` (piste du `getUserMedia`, jamais `RtcPeer`), `FlutterWebRtcTransport` ; échec plateforme → état non coupé, erreur consignée ; `session_event_converter.dart` : champ `cause` validé (inconnu = `stop`) |
| Flutter | `packages/entities` (`entity_session`) | entities | variante `sealed` locale `VoiceSilenced` (jamais dans `EnvelopeLog` ni `A2uiJournal`, jamais envoyée au backend) ; `VoiceInterrupted` gagne `cause` (`stop` par défaut, `correction`) |
| Flutter | `OrbPhaseBloc`, `TranscriptBloc`, `OrbLevelController` | model/ui | traitent `VoiceSilenced` comme `VoiceInterrupted` sans `at_ms` ; `cause = correction` : la 1ʳᵉ `DelegationStarted` d'offset ≥ `at_ms` termine l'interruption ; l'orbe rend un voile « Micro coupé » par-dessus la phase |
| Flutter | `apps/genesis_canvas/lib/widgets/stage_bar` (+ `top_bar`) | widgets | boutons `silence-button`, `mic-button` ; **disposition écrite avant T13** : `StageBar` occupe 100 des 104 px (48 + 4 + 48) → seconde colonne de même largeur à gauche de la première (deux colonnes × deux lignes : act / reset ; micro / silence), largeur par colonne ≥ libellé le plus long à 24 px, cibles ≥ 48 px, `Semantics` |
| Flutter | `apps/genesis_canvas/lib/pages/genesis_canvas` | page (composition) | `Focus(autofocus: true)` à la racine + `Shortcuts`/`Actions` : `M` (cible calculée depuis l'état), `Échap` ; sans effet hors session ; câblage `silenceRemote` |
| Flutter | `apps/genesis_canvas/test/acceptance` | tests | S-09 (bouton et `Échap`), S-07 côté app, M-01, M-02 |
| Go | `backend/orchestrator/internal/port` | port | `SessionDelegations.Supersede(atMs int64, announce func())` (non bloquant) ; `Interrupt` **inchangé** ; faux de `app/voice/delegations_test.go` |
| Go | `backend/orchestrator/internal/app/voice` | app | classifieur d'énoncé unique (`sealed` Stop \| Correction) qui remplace l'appel direct au `StopDetector` dans `stopWatch` (un minuteur, anti-rebond partagé, toujours alimenté) ; `Detection` porte le genre ; `forwarder` : item `"supersede"` jamais abandonné ; config `VOICE_CORRECTION_WORDS` |
| Go | `backend/orchestrator/internal/app/orchestrate` | app | `session.Supersede` ; champs `runOffset` (posé par `beginRun`) et `supersededBefore` ; `Window.ConsumeBefore(atMs)` ; garde de `Delegate` pour une délégation vocale d'offset `< supersededBefore` (reçoit `stopped`) ; `IsStopOnly`/`OnlyStopWords` ignorent les mots de correction de tête |
| Go | `backend/orchestrator/acceptance` | tests (tag `acceptance`) | C-01 à C-05, pilotés par le faux fournisseur et la variable d'environnement, **sans** référencer le symbole du classifieur |
| Compose | `docker-compose.yaml` | config | `VOICE_CORRECTION_WORDS` — fichier partagé : session principale seulement |

## Contrats
- **`Supersede` (P1), sous `session.mu`** : s'applique seulement si (a) l'exécution vocale en cours a `runOffset < atMs`, ou (b) une délégation vocale en file a `OffsetMs < atMs` ; les actions n'entrent jamais en compte. Effet : `epoch++` ; capture de `cancel := s.cancelRun` (seulement si `runOffset < atMs`) ; file vidée en gardant, dans l'ordre, les actions et les délégations vocales d'offset `>= atMs`, **re-tamponnées `d.epoch = s.epoch`** ; `pending -= len(removed)` ; `supersededBefore = atMs` ; `hasStop` intact. **Hors verrou, dans cet ordre** : `announce()` (publie `voice.interrupted {at_ms, cause: correction}` depuis la goroutine du forwarder, avant toute compensation), `cancel(ErrInterrupted)`, `window.ConsumeBefore(atMs)` (retire les deltas `start < atMs`, `consumed = max(consumed, atMs)`), puis la phrase `stopped` de chaque délégation retirée. Condition fausse : rien n'est publié. Ordre des verrous : jamais `Canvas.mu`.
- **App-channel (P2)** : `voice.interrupted {at_ms, cause?}` ; `cause ∈ {stop, correction}`, absent = `stop` (pas de nouveau message) ; valeur inconnue traitée comme `stop` côté app. Faire taire et micro coupé restent locaux ; `session.input_audio.mute` du sideband n'est pas utilisé.
- **Classifieur (P3)** : règles de la spec B1. `at_ms` d'une correction = `start_ms` du delta du premier mot de correction. `IsStopOnly` ignore les mots de correction de tête (« Non, stop » n'est jamais planifié).
- **Dart (P4, P5)** : Bloc uniquement, états et events `sealed`, aucun `getIt` dans un widget ou un Bloc. `VoiceMicMuteRequested` : valeur cible ; sans effet en `Connecting`/`Stopping`/`Idle`. `silenceRemote()` : sans effet hors `Active`, jamais de fermeture.
- **Configuration (P7)** : `VOICE_CORRECTION_WORDS` : au plus 16 mots de 32 runes, une lettre ou un chiffre au moins, message d'erreur sans recopier de mot ; un mot commun avec `VOICE_STOP_WORDS` (après normalisation) refusé au démarrage ; liste vide = détection coupée. `VOICE_STOP_UTTERANCE_GAP`, `VOICE_STOP_SETTLE`, `VOICE_STOP_DEBOUNCE` sont **réutilisés** ; `VOICE_STOP_MAX_WORDS` ne s'applique pas à la correction.

## Références
- `product/architecture/voice-interruption.md`, `frontend-screen.md` § 011, `stage-runtime.md`, `screen.md`, `app-channel-contract.md`.
- Notes `knowledge/` : [rt-barge-in], [rt-gpt-live-delegation], [rt-gpt-live-delegation-latency], [rt-gpt-live-sideband], [rt-flutter-webrtc-audio-routing], [ux-desktop-shortcuts].

## Risques
- **Correction perdue ou annulée elle-même** → `Supersede` distinct, condition `runOffset < atMs`, re-tamponnage d'époque, C-01/C-04/C-05 et T21 (a à f) sous `-race`.
- **Texte antérieur collé à la correction** → `ConsumeBefore` (jamais `ConsumeUntil(atMs)`, qui avalerait le delta de la correction).
- **Délégation tardive** (≈ 1 s après la fin de la parole, [rt-gpt-live-delegation-latency]) → garde `supersededBefore`.
- **Régression de Q-74 / RD-10** → T23 écrit **avant** T22 avec agent bloquant : vert avant, vert après.
- **Faux positif de « non »** → le classifieur exige un mot significatif non correctif ensuite, et `Supersede` exige une demande antérieure en vol ou en file.
- **Micro désactivé sous `flutter_webrtc` Linux non prouvé** → faux `RtcMic` seulement ; à écouter en répétition (ajouté à Q-79).
- **Barre du haut** → disposition écrite ci-dessus ; capture `app-smoke` 1920×1080.
- **Hypothèse fournisseur** → Q-87 ; sans délégation, la correction annule et fait taire seulement, sans état incohérent.
