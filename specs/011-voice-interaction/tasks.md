# 011 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante. Go et Flutter peuvent avancer en parallèle (piles distinctes). `product/`, `specs/`, `docker-compose.yaml` : session principale seule.

## Gherkin
- [ ] T01 Go — acceptation (tag `acceptance`) K-01, K-02, K-03, K-04 · rouges : `compare_without_platform` au lieu de la comparaison ; mot à l'offset absent ; aucune annulation sur « Stop »
- [ ] T02 Flutter — `acte_interruption.feature` K-05, K-06, K-07 · rouges : événement `voice.interrupted` inconnu ; indicateur bloqué à « Acte 1/3 » ; statut tronqué

## TDD Go
- [ ] T10 [P] Go — `RequestWindow` marge + attente des deltas tardifs (cas réel : « … client et » 20600, « livraison » 21000, offset 21000 → Livraison) · `window_test.go`
- [ ] T11 [P] Go — `Canvas.Focus` + métadonnée `genesis/focus` + héritage dans `kit/scope.go` · `scope_test.go`, `canvas_test.go`
- [ ] T12 [P] Go — journal du motif de refus · `pipeline_plan_test.go`
- [ ] T13 [P] Go — `StopDetector` (mots entiers, fenêtre glissante, anti-rebond, liste injectée) · `stopword_test.go`
- [ ] T14 Go — `Manager.CancelInFlight` + compensation des surfaces inachevées + `agent.activity canceled` · `manager_cancel_test.go`
- [ ] T15 Go — câblage service voix : détecteur → `CancelInFlight` → `voice.interrupted` ; contrat app-channel · `service_stop_test.go`
- [ ] T16 Go — idempotence de l'action déjà en place · `action_test.go`
- [ ] T17 Go — consignes vocales (`voice-instructions.fr.md`) + test de non-régression du texte (contient les trois règles)

## TDD Flutter
- [ ] T20 [P] Flutter — décodage `voice.interrupted` (backend_channel, entity_session) · test de codec
- [ ] T21 Flutter — `VoiceSessionBloc` : interruption (orbe, troncature, port `RemoteAudioMute`) · `voice_session_bloc_test.dart`
- [ ] T22 Flutter — adaptateur `flutter_webrtc` du port `RemoteAudioMute` (frontière plateforme) · test avec faux
- [ ] T23 [P] Flutter — `StageActReached` monotone · `stage_bloc_test.dart`
- [ ] T24 Flutter — câblage de la page (surface `actions`, `ActionRunning`, rejeu sans effet) · `genesis_canvas_page_act_test.dart`
- [ ] T25 [P] Flutter — `ReleaseChecklist` pastille de décision, `ActionBar` « en cours »/« fait » · tests de widget (aucun débordement, aucun texte tronqué)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Vérification (`app-smoke`), docs `product/` (contrat app-channel, barge-in.feature, requirements FR-13 à FR-19), `specs/progress.md`, fusion et `publish.sh`
