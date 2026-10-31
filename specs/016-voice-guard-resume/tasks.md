# 016 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`.

## Gherkin
- [ ] T01 Go — acceptation R-01 à R-11 (faux live, agents scriptés, journal de la voix ; fenêtre lue dans le compose sans repli silencieux) · test d'abord : R-01, R-05, R-08, R-09, R-10 échouent (la voix dit le refus habituel) ; R-02 à R-04, R-06, R-07, R-11 gardes verts
- [ ] T02 Go — G-01 (contrat du fichier d'instructions : forme, exception explicite, ordre, textes de 012 intacts) et G-02 (`newOpenAI` + `httptest` lisant `session.instructions`) · test d'abord : G-01 échoue (consigne de silence absente) ; G-02 vert en garde avant, rouge sur la consigne

## TDD
- [x] T10 Go — config : `VOICE_RECOVERY_WINDOW` (parseur, bornes 0 à 30 s, `Warn` sans chevauchement actif, jamais de refus), `orchestrate.Options.RecoveryWindow` validée par `NewManager`, câblage (`wiring_test.go`) · test d'abord : tables de `config_test.go`, `manager_test.go`, `wiring_test.go`
- [x] T11 Go — port `SessionDelegations.NoteOverlap` (commentaire du port), `forwarder.noteOverlap` (jamais abandonné, ordre avant `supersede`), `Service.overlap` l'appelle (y compris correction dite pendant que l'IA parle), `session.NoteOverlap` (`hasOverlap`, plus grand `atMs`, sans effet fermée) ; mise à jour des trois faux de `voice/delegations_test.go` qui enregistrent l'appel et son ordre · test d'abord : `service_overlap_test.go`, `forward_test`, `delegations_test.go`
- [x] T12a Go — Manager : `session.run` pose `Delegation.recovery` (lecture sous `session.mu`, fenêtre, consommation, `repeatPending`, jamais pour une action) · test d'abord : tests unitaires de `session.run` avec un faux `Runner` qui lit la dégradation (chevauchement avant `Delegate`, entre `Delegate` et fin de `settle`, après le refus ; borne incluse ; deuxième délégation non dégradée)
- [x] T12b Go — Pipeline : `Phrases.NoRequest` aux trois points de refus si `recovery()` dégrade · test d'abord : `pipeline_recovery_test.go`, table : refus de vue, refus simple, aucun agent retenu → reprise ; `Failure`, mélange refus + échec, réussite partielle, réussite, action → inchangés
- [ ] T13 Go — consigne de silence dans `voice-instructions.fr.md`, compose (`VOICE_RECOVERY_WINDOW: 8s`), `config/README.md` · test d'abord : G-01, G-02, test de lecture du compose

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; essai réel payant au plus (voix de synthèse « Papa Papa », budget consulté ; sinon Q-89 « non démontré ») ; `product/` (feature `garde-fou-reprise-016` sans « l'IA ignore un bruit », architecture, Q-89 et Q-80 d/e, pdr-0082 avec RG-08 différé d'un tour et R-09) ; `progress.md` ; fusion et `publish.sh`
