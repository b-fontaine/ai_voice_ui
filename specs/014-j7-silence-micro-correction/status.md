# 014 — État

- **Étape** : Refactorisation
- **Tentatives** : 1/3
- **Tâche en cours** : lot F-A (R1, R2, Flutter), lot G (R3-R7, Go)
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/014-j7-silence-micro-correction
- **Backlog** : EP-02, EP-06
- **Mis à jour** : 2026-10-31

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md` (lot A : faire taire, micro coupé, raccourcis facultatifs ; lot B : correction en vol par mots de correction, `keepFrom`), `plan.md`, `tasks.md` (T01-T24 + clôture) ; [pdr-0076](../../product/decisions/pdr-0076-014-silence-mic-correction-assistant-decided.md) (pdr-0062) ; Q-87 créée | `d00e28a` |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER** (2 bloquants P1 `Supersede` distinct sous `session.mu`, re-tamponnage d'époque, `ConsumeBefore` ; P2 champ `cause` de `voice.interrupted` pour que la réponse à la correction soit audible ; 6 importants P3 classifieur unique, P4 micro à propriétaire unique, P5 `VoiceSilenced` pour les quatre consommateurs, P6 T23 avec agent bloquant avant T22, P7 validation de la config, P8 découpage des tâches). Tous intégrés dans `spec.md`, `plan.md`, `tasks.md`, pdr-0076 (D1 bis, D4) ; T00 fait (libellé de S-09) | `341d3f2` |
| 2026-10-31 | Gherkin | T00 (libellé de S-09), T01/T02 Flutter (`acte_silence_micro_correction.feature` : S-09 bouton et Échap, M-01, M-02, S-07 côté app) : **5 rouges pour la bonne raison** (`la commande « silence-button » est absente de la régie`, `« mic-button » est absente`, piste distante restée active, orbe jamais revenu à « Écoute » faute de fin d'interruption sur correction), 86 acceptations existantes vertes ; `gate --unit flutter` vert : `.omc/state/loop/gates/20261031-045758-unit-flutter.log`. T03 Go (`voice_correction_test.go`) : C-01, C-03, C-04 rouges (`aucun voice.interrupted publié`), C-02 et C-05 gardes verts (deviennent utiles dès T22) ; `gate --unit go` vert : `.omc/state/loop/gates/20261031-050009-unit-go.log`. Notes : le voile se cherche par `find.text('Micro coupé')` (T12/T13 le rendent en `Text`) ; `AGENT_TIMEOUT=60s` dans la scène C ; `VOICE_CORRECTION_WORDS` lue par T20 | `49b6a8a`, `5eb69f3` |
| 2026-10-31 | TDD | **Lot B (Go) terminé** : T20 (classifieur Stop\|Correction étendu dans `StopDetector`, `Detection.Kind`, `VOICE_CORRECTION_WORDS` validée : `gate --unit go` `.omc/state/loop/gates/20261031-050444-unit-go.log`), T21 (`Supersede` + `ConsumeBefore` + garde de `Delegate` + forwarder, 8 tests sous `-race` : `…050838-unit-go.log`), T23 (R01-R03 verts avant et après : `…051050-unit-go.log`), T22 (branchement, `voice.interrupted` porte `cause` : C-01 à C-05, R01-R03, K-01..K-04 verts : `…051312-unit-go.log`), T24 (compose, `check-compose.sh` OK). **Lot A (Flutter)** : T10 (`setMicEnabled`), T11 (`Active(micMuted)`, `VoiceMicMuteRequested`, `silenceRemote`/`VoiceSilenced` : `gate --unit flutter` `…050814-unit-flutter.log`), T12 (`InterruptionCause`, orbe/transcript/niveau, voile « Micro coupé » : `…051802-unit-flutter.log` ; acceptation Flutter : S-07 vert, 4 rouges attendus S-09 bouton/Échap, M-01, M-02 faute de boutons). Reste : T13 (disposition de la barre + boutons), T14 (page, `Focus`, `M`/`Échap`), T15 (capture), puis `gate --full`. Points pour la revue : fenêtre entre la sortie de file et `beginRun` non couverte par `Supersede` (ne perd pas la correction) ; libellé du voile à 12 px (RG-09 ≥ 24 px, à arbitrer) | `4964d85`, `ccaf553`, `3b8369b`, `e7bc5e0`, `fa1d05c`, `1da3121`, `099f351` |
| 2026-10-31 | TDD | **TDD terminé** : T13/T14 (barre à deux colonnes de 480 px, `mic-button`, `silence-button`, `Focus(autofocus)` + `M`/`Échap`, jamais `Espace` ; voile « Micro coupé » : disque 64 px + libellé à 24 px dessous ; réplique de l'IA limitée à 1 ligne quand un message d'état est affiché, pdr-0062) : `gate --unit flutter` `.omc/state/loop/gates/20261031-053512-unit-flutter.log`, acceptation Flutter 91 verts dont les 5 scénarios 014 ; T15 capture `.omc/state/loop/snapshots/20261031-053611-act1-replay.png` (1920×1080, quatre boutons lisibles, aucun débordement) ; **`gate --full` VERT sur arbre propre (67 contrôles)** : `.omc/state/loop/gates/20261031-053703-full.log` | `feafe29` |
| 2026-10-31 | Revue | `architect-reviewer` (Opus, mode CODE) : **À REFACTORISER** (0 bloquante, 3 importantes R1-R3, 7 mineures R4-R10), rapport collé ci-dessous | `755ae50` |

## Revue d'architecte
Revue du plan (P1 à P8) : voir le journal ci-dessus ; amendements appliqués. Conflits avec une décision : aucun (P1 précise pdr-0076 D3, P2 complète le contrat de pdr-0073).

### Revue du code (mode CODE, `architect-reviewer` Opus) : **À REFACTORISER** (0 bloquante, 3 importantes, 7 mineures)
Conforme : couches et barrels, `getIt` seulement dans la page racine, Bloc sans Cubit (`sequential()` sur `VoiceMicMuteRequested`), verrous Go (jamais `Canvas.mu` sous `session.mu`, `announce` avant `cancel`, époque re-tamponnée), config bornée sans recopie de mots, micro réarmé à chaque démarrage, RG-09 (24 px), aucun skip/TODO. `go test -race` orchestrate/voice/stopword/bootstrap/wire verts.
- [ ] **R1** [importante, Flutter] `orb_phase_bloc.dart:130` : la délégation de la correction peut arriver avant `voice.interrupted {cause: correction}` (C-04) → l'orbe reste « Interrompue ». Garder `_lastDelegationOffsetMs` ; sur `VoiceInterrupted(correction)` avec offset ≥ `at_ms` : `Interrupted` puis `Listening` aussitôt ; test Bloc + scénario « S-07 bis ».
- [ ] **R2** [importante, Flutter] `setMicEnabled` avale l'erreur → `Active(micMuted: true)` alors que la piste reste active. `Future<bool>` (vrai si appliqué), `VoiceSession.setMicMuted` ne change l'état que sur `true`, `FakeTransport` à valeur de retour réglable ; noter en T92 dans Q-79 que `mediaStreamTrackSetEnable` est asynchrone non observable (flutter_webrtc 1.6.3).
- [ ] **R3** [importante, Go] `voice_correction_test.go:338-366` : C-04 ne passe pas par la file (correction d'un seul delta). Émettre « Non, » puis `deleg_2`, `WaitSends`, puis « plutôt iOS » ; contrôler l'ordre `delegation` avant `voice.interrupted`.
- [ ] **R4** [mineure, Go] `supersede.go:64-72` : `ConsumeBefore` sous `s.mu` avant le `Unlock` ; garde `d.epoch != s.epoch` après `settle` dans `run()` ; test `-race` ≥ 100 itérations.
- [ ] **R5** [mineure, Go] fenêtre sortie de file / `beginRun` : acceptable ; la documenter (« Limite connue » dans `Supersede`, une ligne dans `voice-interruption.md` en T92).
- [ ] **R6** [mineure, Go] `ValidateCorrectionWords` : refuser aussi un mot d'arrêt dont les jetons commencent par ceux d'un mot de correction (« non merci »).
- [ ] **R7** [mineure, Go] `type InterruptCause string` et `CauseStop` explicite dans `interrupt()` (payload sans `cause` inchangé).
- [ ] **R8** [mineure, Flutter] énumération privée `_InterruptionKind { stop, silence, correction }` au lieu de deux booléens ; une seule `canSilence(status, phase)` pour bouton et `Échap` ; `_isStale` dans `silenceRemote`.
- [ ] **R9** [mineure, docs, T92] pdr-0076 D5 (régie à deux colonnes de 480 px, libellé sous l'orbe, réplique à 1 ligne avec un message d'état, `Focus(autofocus)` + `Shortcuts`) ; `screen.md` « Espace » → « Échap ».
- [ ] **R10** [mineure, Flutter] test du focus perdu quand une surface retirée portait le focus ; si rouge, redemander `_shortcutFocus`.
Conflits avec une décision : aucun. À valider en répétition : « Faire taire » n'annule aucune génération (pdr-0076 D1) ; si l'IA marque une pause ≥ `resumeSilence`, sa voix revient en milieu de réplique.

Lots : **F-A** (Flutter) R1 puis R2 ; **G** (Go) R3, R4, R5, R6, R7 ; **F-B** (Flutter) R8, R10 ; R9 et les mentions de R2/R5 en T92.

## Questions pour le porteur
- Q-87 (non bloquante) : délégation du fournisseur pour une correction en vol, à observer en répétition.
