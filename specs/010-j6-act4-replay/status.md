# 010 — État

- **Étape** : TDD
- **Tentatives** : 1/3
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
| 2026-10-30 | Gherkin | **T05 faite : sonde VERTE** (genui 0.10.4 : remise à vide, `gate.reset()` puis réinjection de `act1-replay.jsonl` redonne mêmes surfaces, phases, textes, deux tours de suite, aucun refus ; elle rougit sans `gate.reset()` et avec une valeur fausse). Pas de blocage. | `.omc/state/loop/gates/20261030-173531-unit-flutter.log` (VERT) |
| 2026-10-30 | Gherkin | T11 (compteur de toutes les requêtes HTTP du faux backend, `GET /app` exclu), T12 (`GenesisCanvasApp(clock:)`, remplacement de `AppClock` après `getIt.init()`) et T13 (`ProtocolFeedEntriesCleared`, garde `expanded`) faites, un test rouge puis vert chacune ; `gate --unit flutter` vert (25 contrôles). Reste T01 (scénarios R-01 à R-09). | `.omc/state/loop/gates/20261030-174431-unit-flutter.log` |
| 2026-10-30 | Gherkin | **T01 faite — étape Gherkin terminée.** `acte4_rejouer.feature` (15 scénarios : R-01 à R-09, démontage pendant une lecture, glisser = un seul seek, plus les variantes de R-02 à R-05) + H-04 (`GENESIS_REPLAY_AT`) dans `loop_harness.feature`. **Rouges pour la bonne raison** (16 en échec, revérifié) : `widget [<'replay-play'>] introuvable : la zone Rejeu ne l'expose pas` à l'étape « je clique sur Lecture » (R-01…R-06, R-08, R-09, démontage), même message à « le bouton Lecture est inactif » (R-07), et H-04 : « l'indicateur d'acte doit afficher « Acte 4 · Rejeu » : 0 widget trouvé ». Les 42 autres scénarios d'acceptation restent verts. Précisions tranchées : voir `plan.md`. Passage au TDD (T02 d'abord). | `.omc/state/loop/gates/20261030-180107-unit-flutter.log` (VERT, 8 contrôles ; `gates.tsv` 18:01:38) |
| 2026-10-30 | TDD | T02 (`A2uiJournal`/`JournalEntry`, 23 tests), T03b (`ReplayPlayer`, `ReplaySettings`, 24 tests : durée ∝ 1/vitesse, seek avec barrière, `dispose` synchrone) et T04 (`ReplayRouter`, sortie `sync`, `enterReplay` atomique, comptage des messages écartés, `liveDone`, 37 tests au total dans la slice) faites, un test rouge puis vert chacune ; `gate --unit flutter` vert (24 contrôles). Choix : `restart()` = `seek(0)` ; `play()` après la fin = `restart()` ; statut initial `paused` ; journal plein = cesse d'enregistrer (jamais d'éviction du début). Restent T06 à T09d. | `.omc/state/loop/gates/20261030-180951-unit-flutter.log` ; `gates.tsv` 18:10:53 |

## Revue d'architecte
**Mode PLAN : À AMENDER.** A1 [bloquant] ordre remise à vide / réinjection (barrière d'un tour de boucle, routeur `sync`, `enterReplay` atomique) ; A2 [bloquant] cycle de vie (`ReplayBloc` à deux handlers, `ReplayStage` réduit à `clear`/`exit`, lecteur arrêté de façon synchrone dans `dispose`) ; A3 mode scénario et capture (`GENESIS_REPLAY_AT`, `liveDone`) ; A4 temps testable (lecteur à pas fixe, paramètre `clock`) ; A5 erreurs (remise à vide en rejeu, `canPlay`, messages écartés comptés) ; A6 budget de la zone Rejeu (480 px, deux rangées) ; A7 pas de sérialisation du journal, plafond, panneau resté déplié ; A8 tâches. Tous appliqués dans `plan.md`.

## Arbre inattendu (signalé, non touché)
Des modifications **non committées hors de 010** sont apparues dans le worktree de boucle à 18:11 (écrites par une autre session, probablement celle du porteur après l'essai au micro) : `product/decisions/index.yaml` (`next_id: pdr-0073`), `product/roadmap/open-questions.md`, `product/roadmap/roadmap.md`, et les fichiers non suivis `product/decisions/pdr-0069` à `pdr-0072` et `product/decisions/_archive/`. La boucle ne les committe pas (`git add` par chemins explicites) et ne les modifie pas ; à la Clôture de 010, les éditions de `product/` devront composer avec ces fichiers (ne committer que ses propres hunks, ou attendre que le porteur les ait committés).

## Questions pour le porteur
Aucune bloquante. À observer en répétition : plafond d'écart de 3 s (D6), place de la zone Rejeu (D4).
