# 018 — Tâches

Format : `- [ ] Txx [P?] <pile> — <tâche> · test d'abord : <test qui doit échouer>`. Une seule pile (Flutter) : aucune tâche n'est parallélisable. Amendées par la revue du plan (P1 à P8).

## Gherkin
- [ ] T01 Flutter — (1) durcir `Acte4Harness.press` (`expect(finder.hitTestable(), findsOneWidget)` avant `tester.tap`) ; (2) ajouter `product/functional/features/replay-bar-018.feature` (product-curate, index et `tasks`) et sa copie `apps/genesis_canvas/test/acceptance/acte_barre_rejeu.feature` ; (3) automatiser RB-01 à RB-03 dans `acte_barre_rejeu_test.dart` (rejeu en pause à mi-parcours ; chaque commande : `hitTestable()` et rectangle hors du panneau ; extrémité droite de la glissière par `hitTestOnBinding` ; `Key('bottom-row')` ; traversée des clics ; nombre d'entrées mesuré) · test d'abord : **R-01, RB-01 et RB-03 rouges pour la bonne raison (commande recouverte), RB-02 vert**, sortie citée dans `status.md`
- [x] T02 Doc — `product-decide` : pdr-0086 (ancrage au-dessus de la rangée du bas, hauteur 620, emplacement replié vide ; recouvrement accru de la colonne de droite ; option écartée à 472 px ; « Réexaminer si ») ; historique de pdr-0084 : la raison de U15 (d) est caduque ; mention dans `progress.md` · test d'abord : `product_lint.py` sans erreur

## TDD
- [ ] T10 Flutter — page : pose du panneau par `Expanded(Stack)` + `Positioned.fill(Align(BlocSelector → Padding → ProtocolPanel))` ; `Key('bottom-row')` ; commentaire obsolète de `replay_bar.dart` ; remplacement du test `genesis_canvas_page_replay_reach_test.dart` (par RB-01) ; test « panneau déplié » de `genesis_canvas_page_layout_test.dart` (`panel.bottom <= bottom-row.top`, `panel.top >= board.top`, `panel.bottom <= board.bottom`) ; test de focus et de sémantique du bouton (Entrée déplie, le focus reste, « Replier » dans la fenêtre, Entrée replie) · test d'abord : ces tests de page rouges, puis RB-01 à RB-03 et R-01 verts, suite d'acceptation de l'app entière verte
- [ ] T11 Flutter — `GENESIS_PROTOCOL_EXPANDED` : `GenesisConfig`, page (un `PanelToggled` au montage), `frontend-screen.md` · test d'abord : test de configuration (absent → faux ; valeur invalide → erreur en français sans recopier la valeur) et test de page qui démarre déplié

## Clôture
- [ ] T90 `tools/loop/gate.sh --full` vert
- [ ] T91 Revue architect-reviewer + refactorisations
- [ ] T92 `gate.sh --full` vert après refactorisation ; capture `GENESIS_REPLAY_AT=0.5 GENESIS_PROTOCOL_EXPANDED=1 app-smoke.sh act1-replay` (1920×1080) lue ; `progress.md`, `product/` (frontend-screen.md, replay.md, backlog, roadmap, Q-92 a, pdr-0085 « livrée ») ; `knowledge/` : note sur `hitTestable()`, `warnIfMissed` et `hitTestWarningShouldBeFatal` (kb-curate) ; fusion et `publish.sh`
