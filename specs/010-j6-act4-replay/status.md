# 010 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/010-j6-act4-replay
- **Backlog** : EP-07, EP-05
- **Mis à jour** : 2026-10-30 18:40

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés (9 tâches de développement, Flutter seul) ; **pdr-0066** (D1 à D7, détails tranchés sous pdr-0062) créée et indexée ; `product_lint` 0 erreur. Aucune question bloquante (Q-18, Q-19, Q-36, Q-50, Q-51, Q-52 closes). | `python3 -I product/_tools/product_lint.py` : 0 erreur |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (2 bloquants, 6 importants). Amendements A1 à A8 intégrés dans `plan.md` (bloc « Amendements », prioritaire) et `tasks.md` (réordonné : sonde genui T05 en tête, T03 scindé, T09 en quatre, R-09) ; pdr-0066 D8 ; `replay.md` aligné sur pdr-0066. | `product_lint` 0 erreur |
| 2026-10-30 | Gherkin | T03a faite (squelette `packages/features/replay`, workspace racine, dépendance de l'app, règle de dépendances) ; `gate --unit flutter` vert (10 contrôles). Restent T05, T11, T12, T13 puis T01. | `.omc/state/loop/gates/20261030-173139-unit-flutter.log` |

## Revue d'architecte
**Mode PLAN : À AMENDER.** A1 [bloquant] ordre remise à vide / réinjection (barrière d'un tour de boucle, routeur `sync`, `enterReplay` atomique) ; A2 [bloquant] cycle de vie (`ReplayBloc` à deux handlers, `ReplayStage` réduit à `clear`/`exit`, lecteur arrêté de façon synchrone dans `dispose`) ; A3 mode scénario et capture (`GENESIS_REPLAY_AT`, `liveDone`) ; A4 temps testable (lecteur à pas fixe, paramètre `clock`) ; A5 erreurs (remise à vide en rejeu, `canPlay`, messages écartés comptés) ; A6 budget de la zone Rejeu (480 px, deux rangées) ; A7 pas de sérialisation du journal, plafond, panneau resté déplié ; A8 tâches. Tous appliqués dans `plan.md`.

## Questions pour le porteur
Aucune bloquante. À observer en répétition : plafond d'écart de 3 s (D6), place de la zone Rejeu (D4).
