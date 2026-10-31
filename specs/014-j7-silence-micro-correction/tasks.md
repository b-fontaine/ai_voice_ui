# 014 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante des autres tâches ouvertes. Les piles Flutter (lot A) et Go (lot B) sont indépendantes ; `docker-compose.yaml` et `product/` sont modifiés par la session principale seulement.

## Gherkin
- [ ] T01 Flutter — automatiser S-09 (bouton « Faire taire »), M-01 et M-02 (micro) dans `apps/genesis_canvas/test/acceptance/` · test d'abord : steps non implémentés, puis rouges (pas de bouton)
- [ ] T02 Flutter — automatiser le côté app de S-07 (`voice.interrupted` de correction : piste coupée, orbe « Interrompue », surfaces conservées) · test d'abord : rouge pour la bonne raison ou déjà couvert par K-05 (le dire)
- [ ] T03 Go — C-01 à C-04 (tag `acceptance`, agents scriptés bloquants `startTestAgent`) · test d'abord : pas de `CorrectionDetector`

## TDD — lot A (Flutter)
- [ ] T10 [P] Flutter — `VoiceTransport.setMicEnabled` + `RtcPeer.setLocalAudioEnabled` + `FlutterWebRtcTransport` (état mémorisé avant l'ouverture, réarmé au redémarrage) · test d'abord : faux pair, la piste locale passe à `enabled=false`, jamais arrêtée
- [ ] T11 [P] Flutter — `VoiceSession.setMicMuted` / `silenceRemote` (sans effet hors `Active`, jamais de fermeture) · test d'abord : session `Active` reste `Active`
- [ ] T12 [P] Flutter — `OrbPhaseBloc` : phase `MicMuted` (grisé barré), event de silence demandé → `Interrupted` puis `Listening` par le chemin existant (`resumeRemoteAudio`) · test d'abord : Bloc test `Speaking` + silence → `Interrupted`
- [ ] T13 Flutter — boutons `silence-button` (actif en `Speaking`) et `mic-button` dans la régie ; budget de la barre du haut ; ≥ 48 px, `Semantics` · test d'abord : widget test (cibles, états, libellés entiers à 24 px)
- [ ] T14 Flutter — câblage de la page + raccourcis `M` et `Échap` (sans effet hors session ; jamais `Espace`) · test d'abord : widget test avec focus sur un bouton
- [ ] T15 Flutter — capture `app-smoke` 1920×1080 relue (boutons lisibles, barre sans débordement)

## TDD — lot B (Go)
- [ ] T20 [P] Go — `CorrectionDetector` : premier mot significatif, reste de l'énoncé conservé, correction nue ignorée, mot d'arrêt prioritaire, liste vide = coupé · test d'abord : table de cas (« Non, plutôt iOS » oui ; « Non. » non ; « non seulement… » en vol oui, hors vol non)
- [ ] T21 [P] Go — `session.Interrupt` avec `keepFrom` (délégations `≥ at_ms` conservées, `< at_ms` retirées avec leur phrase `stopped`, actions conservées, pas de `ConsumeUntil`, pas de `hasStop`) · test d'abord : ordre FIFO et `-race`
- [ ] T22 Go — branchement dans `supervise` (détecteur lu seulement si une exécution est en vol ou en file) et configuration `VOICE_CORRECTION_WORDS` validée au démarrage · test d'abord : transcripts scriptés → `voice.interrupted` publié une fois
- [ ] T23 Go — non-régression Q-74 / RD-10 (deux délégations « Concentre-toi sur Android » / « et compare avec la 3.3 » : aucune annulation) · test d'abord : scénario vert avant et après
- [ ] T24 Compose (session principale) — `VOICE_CORRECTION_WORDS=non,plutôt,en fait` · test d'abord : test de configuration du compose

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Documents `product/` (voice-interruption, screen, requirements FR-12/FR-17/FR-20, barge-in.feature, Q-87), `gate.sh --full` vert, état d'avancement, fusion et `publish.sh`
