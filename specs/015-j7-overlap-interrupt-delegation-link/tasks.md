# 015 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante des autres tâches ouvertes. Les piles Flutter (lot A) et Go (lot B) sont indépendantes ; `docker-compose.yaml`, `product/` et `specs/` sont modifiés par la session principale seulement.

## Gherkin
- [ ] T01 Flutter — S-05 (sans mot d'arrêt), O-01 côté app (`voice.interrupted {overlap}` → piste coupée puis rétablie à la délégation d'offset ≥ `at_ms`, ou au silence) et L-01 à L-04 dans `apps/genesis_canvas/test/acceptance/` (`acte_chevauchement_liaison.feature`) · test d'abord : steps non implémentés, puis rouges (cause inconnue → traitée comme `stop`, aucune liaison)
- [ ] T02 Go — O-01 à O-07 (tag `acceptance`, agents scriptés bloquants `startTestAgent`), pilotés par le faux fournisseur et `VOICE_OVERLAP_*`, sans référencer `OverlapFilter` · test d'abord : rouge parce qu'aucun `voice.interrupted {overlap}` n'est publié (pas une erreur de compilation)

## TDD — lot A (Flutter)
- [ ] T10 [P] Flutter — `InterruptionCause.overlap`, convertisseur (inconnu = `stop`), `OrbPhaseBloc` (fin à la délégation d'offset ≥ `at_ms`, y compris arrivée avant l'interruption ; silence de reprise sinon) · test d'abord : Bloc tests de la table des causes
- [ ] T11 [P] Flutter — `DelegationLinkPainter` (pointillés, phase, arc au-dessus des pastilles, épaisseur ≥ 3 px) · test d'abord : tests du peintre sur des rectangles de tuiles donnés (positions de départ et d'arrivée, aucun trait sur un agent hors des deux états)
- [ ] T12 Flutter — `DelegationLinks` et câblage dans `AgentsRail` (mesure par `GlobalKey`, `AnimationController` unique sous `SceneMotionScope`, `RepaintBoundary`, clés `delegation-link-<agent>`) · test d'abord : widget tests L-01 à L-04 (trois agents, tuile la plus éloignée, plan vide, animations coupées, rejeu)
- [ ] T13 Flutter — capture `app-smoke` 1920×1080 relue (liaison visible, aucun libellé couvert)

## TDD — lot B (Go), ordre T20 → T21 → T22 → T23
- [ ] T20 Go — `CauseOverlap` (domain), `VOICE_OVERLAP_*` : lecture, bornes, validation (erreur sans recopier de mot), interrupteur · test d'abord : `config_test` pour chaque refus et chaque défaut
- [ ] T21 Go — `OverlapFilter` pur : mots significatifs, liste ignorée, écho de sortie sur fenêtre média, mémo borné, garde « l'IA parle » (horloge injectée) · test d'abord : table (écho exact, mot partiel, mot court, interjection, IA silencieuse depuis plus de la fenêtre, deux mots dont un écho)
- [ ] T22 Go — `KindOverlap` dans le classifieur : priorité (correction, arrêt, début d'arrêt, chevauchement), énoncé tranché une fois, anti-rebond partagé · test d'abord : table (« Stop » mot à mot ne déclenche jamais `Overlap` ; « Non, plutôt iOS » reste correction ; « Et pour la 3.3 » pendant que l'IA parle → `Overlap`)
- [ ] T23 Go — branchement dans `supervise`/`stopWatch` (`NoteOutput`, `FeedOutput`, `onDetection`), `announceInterrupted(overlap)` avant `supersede(atMs, no-op)` · test d'abord sous `-race` : transcripts scriptés → un seul `voice.interrupted {cause: overlap}` ; exécution antérieure annulée, demande du speaker planifiée ; rien sans exécution en vol sauf l'annonce ; aucune annonce IA silencieuse (O-07)
- [ ] T24 Compose (session principale) — `VOICE_OVERLAP_*` avec liste de mots ignorés en français · test d'abord : test de configuration du compose (`check-compose.sh`)

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Documents `product/` (voice-interruption : détecteur de chevauchement et configuration ; app-channel-contract : `cause` ; screen : liaison ; frontend-screen ; requirements FR-03/FR-13/FR-18 ; barge-in.feature S-05 complet ; nouveau fichier de scénarios 015 ; Q-77 et Q-85 « livrées » ; Q-80 enrichie ; roadmap), `gate.sh --full` vert, état d'avancement, fusion et `publish.sh`
