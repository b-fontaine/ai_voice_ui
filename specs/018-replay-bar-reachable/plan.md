# 018 — Plan technique

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `apps/genesis_canvas` | page (composition) | `lib/pages/genesis_canvas/genesis_canvas_page.dart` (pose du panneau) |
| Flutter | `apps/genesis_canvas` | widget | `lib/widgets/protocol_panel/protocol_panel.dart` (retrait du bas et plafond de hauteur) |
| Flutter | `apps/genesis_canvas` | tests | `test/acceptance/acte_barre_rejeu.{feature,_test.dart}`, `test/widgets/protocol_panel_test.dart`, `test/acceptance/acte4_rejouer*` (R-01 : retirer le contournement) |

## Contrats
- `ProtocolPanel` gagne un paramètre `expandedBottomInset` (px, défaut 0) : déplié, il se pose avec ce retrait en bas ; replié, retrait 0. La page passe `_bottomRowHeight + _gap` (148 px). Aucune dépendance nouvelle ; aucun appel à `getIt`.
- La page remplace `Positioned(right: 0, bottom: 0, child: ProtocolPanel())` par `Positioned.fill(child: Align(alignment: Alignment.bottomRight, child: ProtocolPanel(...)))` : seul le panneau reçoit les clics (`Align` ne capte rien hors de son enfant). Les clés (`protocol-panel`, `protocol-toggle`, `protocol-entry-<n>`) sont inchangées.
- Hauteur dépliée = `min(620, hauteur de la zone − retrait)` ; à 1920×1080, 620 (le canevas fait 676).
- Aucune modification du `ProtocolFeedBloc` ni du `ReplayBloc`.

## Références
- `product/architecture/frontend-screen.md` § Acte 4 ; `product/architecture/replay.md`.
- Notes `knowledge/` : [test-bdd-app-running-fixture], [test-mock-boundaries-only] (on ne mocke qu'aux frontières ; le test d'atteignabilité utilise la vraie page et le faux backend).

## Risques
- Le panneau déplié recouvre alors une zone de canevas plus haute (y 296..916 environ au lieu de 452..1072) → D-01 à D-07 (rectangles des cellules) inchangés par construction (recouvrement, pas de redimensionnement) ; vérifié par la suite d'acceptation complète.
- Le rail (y 136..232) ne doit pas être recouvert : plafond de hauteur contrôlé par RB-03.
- Un clic sur l'espace vide autour du panneau doit traverser vers le canevas → test (clic sur une cellule sous la zone vide).
