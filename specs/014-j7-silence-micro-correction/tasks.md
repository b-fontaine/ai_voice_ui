# 014 — Tâches (amendées par la revue du plan : P1 à P8)

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante des autres tâches ouvertes. Les piles Flutter (lot A) et Go (lot B) sont indépendantes ; `docker-compose.yaml` et `product/` sont modifiés par la session principale seulement.

## Préalable (session principale)
- [ ] T00 `product-curate` — `barge-in.feature` : libellé de S-09 « raccourci » → « bouton ou raccourci » (le scénario est automatisé pour le bouton et pour `Échap`) · lint produit vert

## Gherkin
- [ ] T01 Flutter — S-09 (bouton « Faire taire » **et** `Échap`), M-01, M-02 (faux micro : piste désactivée, capture non arrêtée, session `Active`) dans `apps/genesis_canvas/test/acceptance/` · test d'abord : steps non implémentés, puis rouges (pas de bouton)
- [ ] T02 Flutter — S-07 côté app : `VoiceInterrupted(at, correction)` puis `DelegationStarted(at + 1500)` → orbe `Listening` et piste distante rétablie ; le cas `stop` reste celui de K-05 · test d'abord : **rouge** (exemption `stopSpan` actuelle)
- [ ] T03 Go — C-01 à C-05 (tag `acceptance`, agents scriptés bloquants `startTestAgent`), pilotés par le faux fournisseur et `VOICE_CORRECTION_WORDS`, sans référencer le classifieur · test d'abord : rouge parce qu'aucun `voice.interrupted` n'est publié (pas une erreur de compilation du paquet)

## TDD — lot A (Flutter)
- [x] T10 [P] Flutter — `RtcMic.setEnabled`, `VoiceTransport.setMicEnabled`, `FlutterWebRtcTransport` (jamais d'arrêt de capture ; échec plateforme → non coupé) · test d'abord : faux pair, piste `enabled=false`
- [ ] T11 [P] Flutter — `VoiceMicMuteRequested` (`sequential()`, valeur cible), `Active(micMuted)` avec égalité, remise à faux dans `start()`/`_release()`, `silenceRemote()` + variante `VoiceSilenced` · test d'abord : couper, `stop`, `start` → `micMuted: false` et micro neuf actif ; commande en `Connecting`/`Stopping` sans effet ; faire taire pendant micro coupé
- [ ] T12 Flutter — `cause` de `voice.interrupted` (converter, défaut `stop`, inconnu = `stop`) ; `OrbPhaseBloc` (silence + fin d'interruption sur correction), `TranscriptBloc` (troncature), `OrbLevelController` (niveau 0) ; voile « Micro coupé » · test d'abord : Bloc tests des quatre effets et de la reprise
- [ ] T13 Flutter — disposition de la barre du haut (deux colonnes, voir plan) puis boutons `silence-button` (actif si `Active` et phase ≠ `Interrupted`) et `mic-button` · test d'abord : widget test (cibles ≥ 48 px, libellés entiers à 24 px, états, absence de débordement)
- [ ] T14 Flutter — câblage de la page, `Focus(autofocus: true)`, `M` et `Échap` (jamais `Espace`) · test d'abord : widget test sans aucun focus, et après le clic sur un bouton qui se désactive
- [ ] T15 Flutter — capture `app-smoke` 1920×1080 relue

## TDD — lot B (Go), ordre T20 → T21 → T23 → T22
- [x] T20 Go — classifieur d'énoncé unique (Stop \| Correction), config `VOICE_CORRECTION_WORDS` validée (bornes, intersection avec les mots d'arrêt, liste vide) · test d'abord : table (« Non. » + « Plutôt iOS. » correction ; « Non, stop » Stop ; « Stop, non » Stop ; plus de 4 mots correction ; « En fait, iOS » correction ; « Non. » seul rien) + `config_test` pour chaque refus. **Possède** `stopword.go` et `config` ; ne touche ni le port ni le faux de délégations
- [ ] T21 Go — port `Supersede` + `session.Supersede`, `Window.ConsumeBefore`, garde de `Delegate`, item `"supersede"` du forwarder, faux de `delegations_test.go` · test d'abord sous `-race` : (a) correction déjà en cours non annulée ; (b) correction en file conservée puis exécutée (époque re-tamponnée) ; (c) seule une action en vol : rien publié, action non annulée ; (d) aucune fusion de l'ancien texte ; (e) délégation tardive d'offset `< at` écartée ; (f) `voice.interrupted` avant le premier `deleteSurface` et le premier `agent.activity canceled` ; K-01 à K-07 inchangés
- [ ] T23 Go — non-régression Q-74 / RD-10, **écrite avant T22** (verte avant et après) : « Concentre-toi sur Android » en vol, « et compare avec la 3.3 » en file → aucun `voice.interrupted`, ni annulation, deux exécutions dans l'ordre, focus hérité ; « Concentre-toi plutôt sur iOS » (mot non en tête) → pas de correction ; correction coupée en deux délégations (« Non, » puis « plutôt iOS ») → un seul plan
- [ ] T22 Go — branchement dans `supervise`/`stopWatch` (classifieur toujours alimenté, `Detection` porteuse du genre, `cause` publié) ; `IsStopOnly`/`OnlyStopWords` ignorent les mots de correction de tête ; demande réduite à des mots de correction non planifiée · test d'abord : transcripts scriptés → `voice.interrupted {cause: correction}` publié une fois
- [ ] T24 Compose (session principale) — `VOICE_CORRECTION_WORDS=non,plutôt,en fait` · test d'abord : test de configuration du compose

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 Documents `product/` (voice-interruption : `Supersede`, `cause`, configuration réutilisée ; app-channel-contract ; screen ; requirements FR-12/FR-17/FR-20 ; barge-in.feature ; Q-79 et Q-87), `gate.sh --full` vert, état d'avancement, fusion et `publish.sh`
