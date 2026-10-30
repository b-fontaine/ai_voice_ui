# 011 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante. Go et Flutter peuvent avancer en parallèle (piles distinctes). `product/`, `specs/`, `docker-compose.yaml` : session principale seule.

Ordre amendé par la revue du plan (A1 à A8, `plan.md`, bloc « Amendements », prioritaire). Go **séquentiel** (fichiers partagés) ; Flutter en parallèle de Go.

## Gherkin
- [x] T01 Go — acceptation (tag `acceptance`) K-01, K-02, K-03 (avec `startTestAgent`), K-04 · rouges : `compare_without_platform` au lieu de la comparaison ; mot à l'offset absent ; aucune annulation sur « Stop »
- [x] T02 Flutter — `acte_interruption.feature` K-05, K-06, K-07 (+ « réécriture vocale puis bouton réactivé ») · rouges : événement `voice.interrupted` inconnu ; indicateur bloqué à « Acte 1/3 » ; statut tronqué
- [ ] T03 (reporté en répétition : SP-11 / Q-79) Flutter — **spike manuel** : `track.enabled = false` sur la piste distante, `flutter_webrtc` Linux (résultat dans `status.md` ; échec → repli à documenter, Q-xx)

## TDD Go (séquentiel)
- [x] T10 Go — `RequestWindow` : marge, `consumed = max(…)`, `Take` dans `session.run` après `REQUEST_WINDOW_SETTLE` (jamais d'attente dans `Delegate`) · `window_test.go`, `manager_test.go` (cas réel, delta tardif après la délégation, deux délégations, `Close`)
- [x] T11 Go — focus : `genesis/intent` (agents → `a2aclient` liste blanche → `AgentUpdate.Intent`), `Canvas.Focus`, `AgentRequest.Focus`, `FocusFrom`, `ParseIntent(text, focus, ds)` dans les trois composeurs, `ResetCanvas` efface · `scope_test.go`, `canvas_test.go`, `a2aclient_test.go`
- [x] T12 Go — motif de refus `genesis/scopeReason` (fermé) → slog du `Pipeline` seulement · `pipeline_plan_test.go`
- [x] T13 [P] Go — `StopDetector` (règle A5, horloge injectée) + `VOICE_STOP_WORDS` borné · `stopword_test.go`
- [x] T14 Go — `a2ui.Registry` complétude par surface + `CancelCompensation` ; `port.SessionDelegations.Interrupt` ; époque, `WithCancelCause`, `ErrInterrupted`, `ActivityCanceled`, phrase `stopped` · `registry_test.go`, `manager_cancel_test.go` (-race, 7 cas du plan)
- [x] T18 Go — `voice.interrupted` : domaine, `wire`, hub jamais rejoué, journal · `hub_test.go`, `wire_test.go`
- [x] T15 Go — câblage service voix : détecteur → `voice.interrupted` puis `fw.interrupt()` ; demande réduite aux mots d'arrêt non planifiée · `service_stop_test.go`
- [x] T19 Go — `bootstrap.ConfigFromEnv` : `VOICE_STOP_*`, `REQUEST_WINDOW_*`, bornes · `config_test.go`
- [x] T17 Go — consignes vocales (`voice-instructions.fr.md`) · test du texte (trois règles)

## TDD Flutter
- [x] T20 Flutter — `voice.interrupted` et `canceled` : `entities/session`, convertisseur, `AgentRunState.interrupted` · tests de codec et de `agent_activity_bloc`
- [x] T21 Flutter — Bloc de phase de l'orbe (`Listening | Speaking | Interrupted`), troncature de la réplique, remise du son sur silence, `VoiceSession` direct seulement · `voice_orb_phase_bloc_test.dart` (après T03)
- [x] T22 Flutter — `VoiceTransport.setRemoteAudioEnabled`, `RtcPeer`, `onTrack` tardif · `flutter_web_rtc_transport_test.dart` (faux `RtcPeer`)
- [x] T23 [P] Flutter — `StageActReached` monotone · `stage_bloc_test.dart`
- [x] T24 Flutter — câblage page (surface `actions`, `ActionRunning`), mode scénario et rejeu sans effet, goldens « Acte n/3 » · `genesis_canvas_page_act_test.dart`
- [x] T25 [P] Flutter — `ReleaseChecklist` pastille de décision, `ActionBar` « en cours » / « fait » désactivé (idempotence côté client), réactivation après réécriture · tests de widget (aucun débordement ni troncature)
- [x] T26 Flutter — états visuels de `top_bar/voice_orb.dart` (« Interrompue »), orbe à 0 pendant l'interruption · test de widget

## Clôture
- [x] T89 session principale — `docker-compose.yaml` (variables `VOICE_STOP_*`, `REQUEST_WINDOW_*`, phrases `stopped`) avant T90
- [x] T90 `tools/loop/gate.sh --full` vert
- [x] T91 Revue architect-reviewer + refactorisations
- [x] T92 Vérification (`app-smoke`), docs `product/` (contrat app-channel, barge-in.feature, requirements FR-13 à FR-19), `specs/progress.md`, fusion et `publish.sh`
