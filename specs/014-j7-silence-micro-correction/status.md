# 014 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
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

## Revue d'architecte
Revue du plan (P1 à P8) : voir le journal ci-dessus ; amendements appliqués. Conflits avec une décision : aucun (P1 précise pdr-0076 D3, P2 complète le contrat de pdr-0073).

## Questions pour le porteur
- Q-87 (non bloquante) : délégation du fournisseur pour une correction en vol, à observer en répétition.
