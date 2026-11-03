# 018 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Une seule pile (Flutter) : aucune tâche n'est parallélisable.

## Gherkin
- [ ] T01 Flutter — ajouter `product/functional/features/replay-bar-018.feature` (product-curate, index et `tasks`), copie `apps/genesis_canvas/test/acceptance/acte_barre_rejeu.feature`, automatiser RB-01 à RB-03 dans `acte_barre_rejeu_test.dart` · test d'abord : RB-01 et RB-03 rouges (commande recouverte par le panneau), RB-02 vert

## TDD
- [ ] T10 Flutter — `ProtocolPanel` : paramètre `expandedBottomInset`, hauteur dépliée plafonnée ; page : `Positioned.fill` + `Align`, retrait de 148 px ; R-01 sans contournement · test d'abord : `protocol_panel_test` (position et hauteur dépliée, repliée inchangée), puis RB-01 à RB-03 verts, suite d'acceptation de l'app entière verte

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; capture `app-smoke` 1920×1080 en rejeu, panneau déplié ; `progress.md`, `product/` (frontend-screen.md, replay.md, backlog, roadmap, Q-92 a, pdr-0085 « livrée ») ; fusion et `publish.sh`
