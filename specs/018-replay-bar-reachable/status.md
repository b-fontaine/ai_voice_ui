# 018 — État

- **Étape** : Gherkin
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
