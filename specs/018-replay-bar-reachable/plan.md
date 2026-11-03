# 018 — Plan technique

*Amendé par la revue du plan (P1 à P8).*

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `apps/genesis_canvas` | page (composition) | `lib/pages/genesis_canvas/genesis_canvas_page.dart` : pose du panneau, `Key('bottom-row')` sur la rangée du bas, lecture de `GENESIS_PROTOCOL_EXPANDED` |
| Flutter | `apps/genesis_canvas` | configuration | `GenesisConfig` : `GENESIS_PROTOCOL_EXPANDED` (absent par défaut) |
| Flutter | `apps/genesis_canvas` | widget | `lib/widgets/replay_bar/replay_bar.dart` : commentaire des lignes 23-25 obsolète (géométrie de 8 px conservée) ; `ProtocolPanel` **inchangé** |
| Flutter | `apps/genesis_canvas` | tests | `test/acceptance/acte_barre_rejeu.{feature,_test.dart}` ; `test/acceptance/support/acte4_harness.dart` (`press` strict) ; `test/pages/genesis_canvas_page_replay_reach_test.dart` (remplacé par RB-01 ou réécrit) ; `test/pages/genesis_canvas_page_layout_test.dart` (test « panneau déplié » : `panel.bottom <= bottom-row.top`) ; `test/acceptance/step/le_panneau_protocole_deplie_ne_depasse_pas_le_haut_du_canevas.dart` ; tests de configuration et de focus |

## Contrats
- **`ProtocolPanel` ne change pas** (pas de paramètre `expandedBottomInset`) : la clé `protocol-panel` garde la boîte visible du panneau (460×140 replié, 780×620 déplié). Le retrait vit dans la page.
- **Pose du panneau** (option (a) de la revue) : la zone sous le rail devient un `Expanded(Stack)` dont les enfants sont la colonne `[Expanded(canevas), gap, SizedBox(key: bottom-row, height: 140, rangée)]` et `Positioned.fill(Align(bottomRight, BlocSelector<ProtocolFeedBloc, ProtocolFeedState, bool>(selector: expanded, builder: Padding(bottom: expanded ? 140 + 8 : 0, child: const ProtocolPanel()))))`. Le `Padding` est **toujours présent** (seule sa valeur change) : l'élément du bouton `protocol-toggle` et son focus sont conservés. `Align` et `Padding` ne captent aucun clic hors de leur enfant. Le `LayoutBuilder` du panneau voit alors exactement la zone du canevas plus la rangée du bas (824) moins le retrait (148) = 676, donc `min(620, 676)` = 620 ; le plafond protège le rail.
- **Capture** : `GENESIS_PROTOCOL_EXPANDED` (bool, absent par défaut) lue par `GenesisConfig`, injectée dans la page qui émet une fois `PanelToggled` au montage ; ajoutée à la table de `frontend-screen.md`. Commande : `GENESIS_REPLAY_AT=0.5 GENESIS_PROTOCOL_EXPANDED=1 app-smoke.sh act1-replay`.
- Aucune dépendance nouvelle ; aucun appel à `getIt` ; aucune modification du `ProtocolFeedBloc` ni du `ReplayBloc`.

## Références
- `product/architecture/frontend-screen.md` § Acte 4 ; `product/architecture/replay.md`.
- [pdr-0085] (décision du porteur), pdr-0086 (mise en page, T02), pdr-0084 U15 (d) (raison caduque).
- Notes `knowledge/` : [test-bdd-app-running-fixture], [test-mock-boundaries-only].

## Risques
- **Faux vert** : `tester.tap` ne fait jamais échouer un clic manqué (`warnIfMissed`, plusieurs étapes en `warnIfMissed: false`) ; R-01 est vert alors que le clic sur 2× tombe sous le panneau → `Acte4Harness.press` vérifie `hitTestable()` avant de toucher ; preuve rouge attendue à T01 : R-01, RB-01 et RB-03 rouges, RB-02 vert.
- **Boîte de `protocol-panel`** : un retrait dans le widget aurait fait mesurer 780×768 → retrait dans la page.
- **Recouvrement accru** de la colonne de droite (y 304..452) → pdr-0086, D-01 à D-07 inchangés par construction (recouvrement, pas de redimensionnement), `panel.top >= board.top` et `panel.bottom <= board.bottom`.
- **Focus** : le bouton passe de « Déplier » à « Replier » en bougeant → test de focus et de sémantique.
- **Clics hors du panneau** : traversée prouvée par RB-03.
