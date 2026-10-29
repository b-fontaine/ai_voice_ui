# NNN — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. `[P]` = indépendante des autres tâches ouvertes.

## Gherkin
- [ ] T01 Flutter — automatiser S-xx avec bdd_widget_test dans `test/acceptance/` · test d'abord : le scénario échoue (step non implémenté)
- [ ] T02 Go — test d'acceptation du flux <…> (build tag `acceptance`) · test d'abord : …

## TDD
- [ ] T10 [P] Flutter — <unité> · test d'abord : <test unitaire>
- [ ] T11 [P] Go — <unité> · test d'abord : …

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; état d'avancement mis à jour ; fusion et `publish.sh`
