# Boucle de développement autonome

Fait avancer Genesis Canvas fonctionnalité par fonctionnalité jusqu'au talk du 12/11/2026. Le porteur ne tranche que les arbitrages (`product/roadmap/open-questions.md`) et récupère le travail par `git pull` sur `main`.

## Cycle (une itération = une étape d'une fonctionnalité)
```
Définir (specs/NNN) → Revue du plan (Opus) → Gherkin rouge → TDD tâche par tâche (gate --unit) → Revue d'architecte (Opus)
      ↑                                                                            ↓
  Clôture : état, roadmap, décisions, fusion, publish.sh  ←  Vérification (gate --full + capture)  ←  Refactorisation
```
Détail : `.claude/skills/dev-loop/SKILL.md`. Gabarits et état : `specs/`.

## Isolation
- La boucle travaille dans un **worktree séparé** (`../ai_voice_ui-loop`, branche `loop`), jamais dans l'arbre du porteur.
- Une fonctionnalité = une branche `feat/NNN-<slug>`, fusionnée dans `loop` seulement quand elle est verte. Une fonctionnalité bloquée ne pollue pas la base.
- Seul `publish.sh` publie : `git fetch`, fusion de `origin/main` (jamais de rebase), porte complète, `git push origin HEAD:main`. En cas de conflit, la fusion est annulée et une question part au porteur.
- Le hook `pre-push` du worktree refuse tout commit qui n'a pas passé `gate.sh --full` sur un arbre propre.
- La session a son propre identifiant (`--session-id`) : un redémarrage reprend toujours **sa** conversation, jamais celle du porteur. Elle charge les réglages du projet et ceux de la boucle (`--setting-sources project,local`), sans les plugins ni les hooks utilisateur.

## Modèles
| Rôle | Agent | Modèle | Effort |
|---|---|---|---|
| Boucle (choix, décisions contraintes, état) | session principale | Sonnet 5.5 | high |
| Gherkin, TDD | `feature-developer` | Sonnet 5.5 | medium |
| Refactorisation | `refactorer` | Sonnet 5.5 | medium |
| Revue d'architecture | `architect-reviewer` | Opus 5.5 | high |

Ultracode désactivé ; jamais le modèle Fable (son compteur pèse sur la semaine). Workflows multi-agents seulement sur besoin réel. Deux sous-agents en parallèle au plus, sur des piles différentes (Go / Flutter).

Accélérations du 2026-10-29 : revue du **plan** par l'architecte avant le TDD ; refactorisations **par lots** avec une seule porte complète ; jusqu'à 3 étapes enchaînées par itération ; Go et Flutter en parallèle.

## Garde-fous
| Risque | Mécanisme |
|---|---|
| Quota 5 h | `quota-check.sh` : pause à 90 % jusqu'à la remise à zéro |
| Quota hebdomadaire | lissage : la boucle consomme au plus 90 % de la semaine, au rythme du temps écoulé (+10 points), plafond 95 % (choix du porteur, 2026-10-29) ; le reste est pour lui |
| Pause longue | > 1 h : la boucle s'arrête (`paused_until`) ; le superviseur la relance à l'heure |
| Limite atteinte malgré tout | Claude Code attend seul la remise à zéro ; hook `StopFailure` → `rate_limited_at` ; le superviseur n'intervient pas avant |
| Contexte qui grossit | une conversation neuve par fonctionnalité : après publication, la boucle pose `fresh_session` et s'arrête ; le superviseur la relance avec un nouvel identifiant. La compaction automatique reste le filet de sécurité |
| Plantage, session tuée | `supervisor.sh` relance (`--resume <id>`) ; il ne tape jamais dans la session, et ne relance pas une session occupée |
| Tâche interrompue | `status.md` garde « Tâche en cours » et « Fichiers touchés » : reprise par la porte, ou annulation ciblée |
| Boucle sans fin | 3 tentatives par étape, compteur dans `status.md`, puis « Bloquée » et fonctionnalité suivante |
| Faux vert | preuves = journaux de `gate.sh` (`gates.tsv`, `last_green_sha`) ; `verify.sh` refuse `skip`, `.only`, `solo`, `t.Skip`, TODO ; régénère le code (`build_runner`) |
| Budget OpenAI | `openai-budget.sh` : 12 € pour la boucle, 8 € réservés aux répétitions ; registre versionné `specs/openai-spend.tsv` |
| Auto-modification | règles `deny` : `.claude/`, `tools/loop/`, `AGENTS.md`, `CLAUDE.md` |
| Dégâts git | `deny` : push direct, `pull`, `rebase`, `reset`, `stash`, `clean`, `add -A`/`.`, `commit -a`/`--amend`/`--no-verify`, `config` |

Réglages : `loop.env`. Surcharges locales : `loop.local.env` (non versionné).

## Commandes
```bash
tools/loop/setup-worktree.sh                       # une fois : crée ../ai_voice_ui-loop (branche loop)
cd ../ai_voice_ui-loop
tools/loop/start-loop.sh                           # lance la session tmux « genesis-loop »
tools/loop/supervisor.sh                           # dans un autre terminal
tmux attach -t genesis-loop                        # regarder (Ctrl-b d pour se détacher)
tools/loop/stop-loop.sh [--now]                    # arrêt propre (ou immédiat)
tools/loop/gate.sh --full                          # porte complète, à la main
tools/loop/openai-budget.sh total                  # dépense OpenAI de la boucle
```
État : `specs/progress.md`, `specs/NNN-*/status.md` (versionnés) ; `.omc/state/loop/` dans le worktree (quota, battement, journaux de porte, captures ; non versionné).

## Voir l'app
`app-smoke.sh` démarre le backend (`docker compose`), compile l'app Linux, la lance **sous Xvfb** (hors de l'écran du porteur) avec `GENESIS_SCENARIO` / `GENESIS_SNAPSHOT` : l'app rejoue le scénario (défaut : rejeu A2UI de l'acte 1, sans micro ni coût), écrit une capture PNG et se ferme. La boucle ouvre la capture et la compare à la spec. Ce mode est livré par `specs/000-loop-harness`, première fonctionnalité de la boucle. Prérequis système : `xvfb` et les en-têtes GStreamer.
