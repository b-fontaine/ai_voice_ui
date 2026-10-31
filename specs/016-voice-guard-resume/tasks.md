# 016 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`.

## Gherkin
- [ ] T01 Go — acceptation R-01 à R-07 (faux live, agents scriptés, journal de la voix) · test d'abord : R-01 échoue (la voix dit `failure_rejected_view`) ; R-02 à R-04, R-06 gardes verts
- [ ] T02 Go — G-01 (contrat du fichier d'instructions) et G-02 (texte reçu par le faux fournisseur) · test d'abord : G-01 échoue (consigne de silence absente)

## TDD
- [ ] T10 Go — config : `VOICE_RECOVERY_WINDOW` (parseur, bornes, refus sans chevauchement actif) et clé `repeat_request` (phrases, validation, fichier par défaut, `check-compose.sh` via le compose) · test d'abord : tables de `config_test.go` et `phrases_*_test.go`
- [ ] T11 Go — `Service.overlap` appelle `NoteOverlap` ; port `SessionDelegations.NoteOverlap` ; `session` mémorise le plus récent `atMs` · test d'abord : `service_overlap_test.go` et `delegations_test.go` (faux gestionnaire)
- [ ] T12 Go — `session.run` marque `Degraded` après `settle` ; `Pipeline` dit `RepeatRequest` aux trois points de refus si `Degraded` · test d'abord : `pipeline_repeat_test.go` (table : refus de vue, refus simple, aucun agent, échec d'agent, réussite, action) et test de course `-race`
- [ ] T13 Go — consigne de silence dans `voice-instructions.fr.md`, phrase `repeat_request` dans `phrases.fr.json`, compose (`VOICE_RECOVERY_WINDOW: 8s`), `config/README.md` · test d'abord : G-01, G-02, `check-compose.sh`

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; essai réel payant au plus (voix de synthèse « Papa Papa », budget consulté) ; `product/` (feature `garde-fou-reprise-016`, architecture, Q-89 et Q-80 d/e, PDR) ; `progress.md` ; fusion et `publish.sh`
