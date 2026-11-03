# 018 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/018-replay-bar-reachable
- **Backlog** : EP-07, EP-05
- **Mis à jour** : 2026-11-03

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-11-03 | Définir | `spec.md`, `plan.md`, `tasks.md` (T01, T10, T90 à T92). Consultations : `product-lookup` (pdr-0085, Q-92 a, p-ar-replay, frontend-screen), `kb-lookup` (test-bdd-app-running-fixture, test-mock-boundaries-only). Mise en page choisie sous pdr-0062 : le panneau déplié se pose au-dessus de la rangée du bas. | commit `3b6a22b` |
| 2026-11-03 | Revue du plan | `architect-reviewer` (mode PLAN, Opus) : verdict **À AMENDER** (P1, P2 bloquantes ; P3 à P7 importantes ; P8 mineure) ; toutes intégrées dans `spec.md`, `plan.md` (pose du panneau dans la page, `ProtocolPanel` inchangé, `Key('bottom-row')`, `GENESIS_PROTOCOL_EXPANDED`, fichiers du contournement de 017) et `tasks.md` (T01 durci, T02 nouvelle : pdr-0086, T11 nouvelle) | verdict ci-dessous |
| 2026-11-03 | Gherkin | **T01 faite** : `Acte4Harness.press` strict (`hitTestable()` avant `tester.tap`) ; `product/functional/features/replay-bar-018.feature` (RB-01 à RB-03, indexé) et sa copie `acte_barre_rejeu.feature` ; sept steps et `replay_bar_harness.dart` ; seule ligne de production : `Key('bottom-row')` sur la rangée du bas. **Rouge attendu, pour la bonne raison** (`flutter test test/acceptance/acte4_rejouer_test.dart test/acceptance/acte_barre_rejeu_test.dart` : 15 verts, 3 rouges) : R-01 « la commande replay-speed-2 est recouverte » (`Found 0 widgets` hitTestable) ; RB-01 « replay-play est recouverte : son rectangle (1084.8, 954.0, 1136.8, 1002.0) recoupe le panneau (1116.0, 452.0, 1896.0, 1072.0) » (passe `hitTestable()` par 3,2 px, échoue sur le rectangle) ; RB-03 « Expected ≤ 932.5, Actual 1072.0 : le panneau recouvre la rangée du bas » ; **RB-02 vert**. Vérifié aussi (RB-03 sans sa première assertion) : 4 entrées montrées, `kpi`, `reset-button`, `mic-button`, `action-block_release` traversent le panneau, le bouton « Replier » est dans la fenêtre. `gate --unit flutter` vert, 372 tests | `.omc/state/loop/gates/20261103-073603-unit-flutter.log` |
| 2026-11-03 | TDD | **T10 faite** : le panneau déplié se pose au-dessus de la rangée du bas (`Expanded(Stack)` sous le rail ; `Positioned.fill(Align(bottomRight, BlocSelector → Padding(bas 148 si déplié) → ProtocolPanel)))` ; `ProtocolPanel` inchangé, `Padding` toujours présent). Rouge : `genesis_canvas_page_layout_test` « panneau déplié » `Expected ≤ 932.0, Actual 1072.0`. Vert : R-01, RB-01 à RB-03 (18 scénarios `acte4_rejouer` + `acte_barre_rejeu`), acceptation complète 116 verts (D-01 à D-07, U-xx compris), nombre d'entrées montrées inchangé (4). Test de focus du bouton « Replier » ajouté (caractérisation, déjà vert : le focus reste sur le bouton). `genesis_canvas_page_replay_reach_test.dart` supprimé (couvert par RB-01 sans marge). Commentaire obsolète de `replay_bar.dart` corrigé, géométrie de 8 px conservée. Reste : T11 | `.omc/state/loop/gates/20261103-074223-unit-flutter.log` |
| 2026-11-03 | TDD | **T11 faite** : `GENESIS_PROTOCOL_EXPANDED` (`1`/`true` ou `0`/`false`, absent ou vide = faux, autre valeur = erreur de configuration en français sans recopier la valeur) lue par `GenesisConfig` (`protocolExpandedAtStart`), transmise par `GenesisCanvasApp` aux réglages de la page, un seul `PanelToggled` dans `initState` ; ligne ajoutée à la table de `frontend-screen.md`. Rouge : les deux fichiers de test ne compilaient pas (`No named parameter 'protocolExpandedAtStart'`). Vert : tests de configuration, de réglages et de page (déplié 780×620 et « Replier » avec la variable, replié 140 de haut sans) ; acceptation 116 verts. `app-smoke.sh` hérite de l'environnement du shell : `GENESIS_REPLAY_AT=0.5 GENESIS_PROTOCOL_EXPANDED=1 tools/loop/app-smoke.sh act1-replay` transmet la variable | `.omc/state/loop/gates/20261103-074610-unit-flutter.log` |

## Revue d'architecte
**Revue du plan (mode PLAN) : verdict À AMENDER, toutes intégrées.**
- [x] **P1 (bloquante)** `Acte4Harness.press` touche sans vérifier l'atteignabilité (R-01 est vert alors que le clic sur 2× tombe sous le panneau : « would not hit test ») → `hitTestable()` avant `tester.tap` ; preuve rouge attendue à T01 : R-01, RB-01, RB-03 rouges, RB-02 vert.
- [x] **P2 (bloquante)** un paramètre `expandedBottomInset` aurait fait mesurer 780×768 à la clé `protocol-panel` → `ProtocolPanel` inchangé, retrait dans la page (`Padding` toujours présent : focus du bouton conservé).
- [x] **P3 (importante)** le plafond « hauteur du canevas » n'existait pas (le `LayoutBuilder` voit 1064, aujourd'hui non borné) → panneau posé dans un `Expanded(Stack)` sous le rail (zone 824, retrait 148, plafond 676) ; coordonnées corrigées (rail 144..240, canevas 248..924, panneau 304..924, rangée du bas 932..1072).
- [x] **P4 (importante)** détail d'interface tranché par la boucle → pdr-0086 (T02) ; recouvrement accru de la colonne de droite (y 304..452) consigné ; option 472 px écartée.
- [x] **P5 (importante)** aucun moyen de capturer le panneau déplié → `GENESIS_PROTOCOL_EXPANDED` (T11).
- [x] **P6 (importante)** le contournement de 017 est dans `replay_bar.dart` (remplissage de 8 px, commentaire l. 23-25) et `genesis_canvas_page_replay_reach_test.dart`, pas dans `acte4_rejouer*` → fichiers listés au plan.
- [x] **P7 (importante)** conception de RB-01 à RB-03 (rejeu en pause à mi-parcours, `hitTestable()` et rectangle hors du panneau, extrémités de la glissière, `Key('bottom-row')`, traversée des clics, nombre d'entrées).
- [x] **P8 (mineure)** test de focus et de sémantique du bouton ; observation à remonter sans bloquer : le second bouton de la Barre d'actions tombe probablement sous le panneau déplié à l'acte 3 (antérieur à 018) ; note `knowledge/` sur `hitTestable()` en clôture.

## Questions pour le porteur
Aucune.
