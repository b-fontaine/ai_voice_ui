---
name: dev-loop
description: Une itération de la boucle de développement autonome de Genesis Canvas (lancée par /loop dans le worktree de boucle) — vérifie arrêt, quota et reprise, avance la fonctionnalité en cours d'une ou plusieurs étapes (Définir → Revue du plan → Gherkin → TDD → Revue d'architecte → Refactorisation → Vérification → Clôture), met à jour l'état et planifie le réveil suivant. À utiliser uniquement dans la session de boucle, ou quand le porteur demande « une itération de la boucle ».
---

# dev-loop — une itération

**Une itération = une à trois étapes** d'une fonctionnalité (voir § 4). L'état vit dans les fichiers, jamais dans le contexte : `specs/progress.md` (global) et `specs/NNN-<slug>/status.md` (local). Tu peux être compacté ou relancé à tout moment : relis l'état avant d'agir.

**Où tu es** : dans le worktree de boucle (branche `loop`), jamais dans l'arbre du porteur. Racine : `R=$(git rev-parse --show-toplevel)`. Appelle toujours les scripts par `"$R"/tools/loop/<script>`. Ne fais jamais `cd` sans revenir à `"$R"` dans la même commande.

**Modèles** : la session tourne sur Sonnet 5.5 (effort high). `feature-developer` et `refactorer` : Sonnet, medium. `architect-reviewer` : Opus, high. Jamais le modèle Fable (décision du porteur : trop coûteux pour le quota hebdomadaire). Un workflow multi-agents seulement pour un vrai besoin de contre-vérification (point d'architecture délicat, revue avant gel).

## 0. Garde-fous (dans cet ordre, à chaque itération)
1. **STOP** : si `"$R"/.omc/state/loop/STOP` existe → ligne « arrêt demandé » dans `specs/progress.md`, puis `ScheduleWakeup` avec `stop: true`. Fin.
2. **Quota** : `"$R"/tools/loop/quota-check.sh`.
   - `PAUSE <epoch> …` et attente ≤ 3600 s → `ScheduleWakeup` (`delaySeconds` = attente, même consigne). Fin.
   - `PAUSE <epoch> …` et attente > 3600 s → écris `<epoch>` dans `"$R"/.omc/state/loop/paused_until`, ligne dans `specs/progress.md`, puis `ScheduleWakeup` avec `stop: true`. Le superviseur relancera la session à l'heure. Fin.
   - `UNKNOWN` → continue, mais n'engage qu'une étape courte (pas de Revue ni de Vérification complète).
3. **Reprise après interruption** : si la fonctionnalité en cours a `Tâche en cours: Txx` dans `status.md` et que `git status --porcelain` n'est pas vide → lance `gate.sh --unit <pile de la tâche>`. Vert : committe ces fichiers et marque la tâche faite. Rouge : `git restore --source=HEAD -- <fichiers listés sous « Fichiers touchés »>`, supprime les fichiers nouveaux de cette liste, puis reprends la tâche (compte une tentative).
4. **Arbre inattendu** : des modifications hors de la fonctionnalité en cours → ne les touche pas ; signale-les dans `status.md` et dans `specs/progress.md`.

## 1. Choisir le travail
- `specs/progress.md` : une fonctionnalité `en cours` → reprends-la (`status.md`) sur sa branche : `git switch feat/NNN-<slug>`, ou `git switch loop && git switch -c feat/NNN-<slug>` si elle n'existe pas encore.
- Sinon : la suivante dans l'ordre de `product/roadmap/roadmap.md` et du backlog, en sautant : celles déjà présentes dans `progress.md` (colonne « Backlog »), celles `Bloquée`, celles dont une `Q-xx` bloquante est ouverte. La toute première est `specs/000-loop-harness` (déjà rédigée).
- Nouvelle fonctionnalité : `git switch loop && git switch -c feat/NNN-<slug>` (NNN = suivant), dossier depuis `specs/_templates/`, ligne dans `progress.md` avec l'id de backlog.
- Rien de faisable (tout attend le porteur) : `progress.md` (« en attente du porteur : Q-… »), puis `ScheduleWakeup` 3600 s.

## 2. Avancer d'une étape
Avant chaque tentative : incrémente `Tentatives` dans `status.md` (remis à 0/3 à chaque changement d'étape). À **3/3** sans succès → `Étape: Bloquée` (cause, extraits de journaux), `Q-xx` si c'est un choix, `progress.md`, retour sur `loop` (`git switch loop`), puis autre fonctionnalité. La branche bloquée n'est jamais fusionnée.

| Étape | Action | Condition de passage (prouvée) |
|---|---|---|
| **Définir** | skills product-lookup + kb-lookup ; `spec.md`, `plan.md`, `tasks.md` (chaque tâche : pile, test d'abord). Choix contraint → product-decide § 0 bis. Arbitrage → `Q-xx` (product-curate) et découpage pour avancer sans. Committe `specs/NNN-*`. | fichiers committés |
| **Revue du plan** | `architect-reviewer` en **mode PLAN** sur `spec.md`, `plan.md`, `tasks.md` (aucun code n'existe encore). Intègre ses remarques dans `plan.md` et `tasks.md` (conception des flux, cycle de vie, ports, erreurs, sécurité) ; colle le verdict dans `status.md` ; committe. | verdict PLAN collé, plan amendé |
| **Gherkin** | `feature-developer` : scénarios automatisés pour chaque pile concernée — Flutter dans `test/acceptance/` (bdd_widget_test), Go avec le build tag `acceptance`. Ils doivent échouer pour la bonne raison. | sortie rouge attendue citée dans `status.md` ; `gate.sh --unit` vert (l'acceptation est exclue) ; commit |
| **TDD** | `feature-developer` sur la tâche ouverte suivante. **Deux en parallèle** si et seulement si les deux tâches sont sur des piles différentes (une Flutter sous `apps/`, `packages/`, `testing/` ; une Go sous `backend/`) et ne touchent aucun fichier partagé (`docker-compose.yaml`, `product/`, `specs/`, `.github/`) ; chacune lance `gate.sh --unit <sa pile>`. Les fichiers partagés ne sont modifiés que par la session principale. Avant l'appel : `Tâche en cours: Txx` (ou `Txx, Tyy`). Après : `Fichiers touchés` à jour, `gate.sh --unit <pile>` vert, commit `feat(NNN): Txx …` avec `git add -- <chemins>`, tâche cochée, `Tâche en cours` vidé. | toutes les tâches cochées et `gate.sh --full` vert (acceptation comprise) |
| **Revue** | `architect-reviewer` en **mode CODE** sur `git diff loop...HEAD`. Colle verdict et R1…Rn dans `status.md`. | rapport collé |
| **Refactorisation** | Regroupe les R-n en **lots** : une bloquante seule ; les autres par zone de code (même fichier ou même slice) ; toutes les mineures d'une pile en un lot. Un `refactorer` par lot ; deux lots en parallèle s'ils sont sur des piles différentes. Après chaque lot : `gate.sh --unit <pile>` et un commit `refactor(NNN): R… lot`. **Une seule** `gate.sh --full` à la fin de l'étape. « Conflits avec une décision » → `Q-xx`, pas de code. | `gate.sh --full` vert |
| **Vérification** | `gate.sh --full`, puis `app-smoke.sh` : ouvre la capture PNG avec l'outil Read et compare à la spec. `UNAVAILABLE` (code 4) → note-le, ne compte pas de tentative, continue. | porte verte sur arbre propre + capture conforme (ou indisponibilité notée) |
| **Clôture** | `status.md` = Terminée ; `progress.md` ; `product/roadmap/` (jalon, backlog) via product-curate ; décisions via product-decide ; commit. Puis `git switch loop && git merge --no-ff feat/NNN-<slug>` et `"$R"/tools/loop/publish.sh`. Code 3 (conflit avec `origin/main`) → `Q-xx` pour le porteur, fonctionnalité `Terminée — publication en attente`. Publication réussie → `touch "$R"/.omc/state/loop/fresh_session`, puis `ScheduleWakeup` avec `stop: true` : le superviseur relance la boucle dans une **conversation neuve** (contexte vide ; l'état est dans les fichiers). | `publish.sh` = 0 |

Les preuves sont les journaux de `gate.sh` (`.omc/state/loop/gates/`, `gates.tsv`) : cite le chemin du journal dans `status.md`, jamais un « vert » de mémoire.

## 2 bis. Spikes (SP-xx de `product/roadmap/spikes.md`)
Un spike n'a ni Gherkin ni revue : **Définir** (question, critère de succès, dans `specs/NNN-sp-xx/spec.md`) → **Expérimenter** (code jetable sous `spikes/<nom>/`, jamais sous `apps/`, `packages/` ou `backend/`) → **Consigner** (faits vérifiés dans `knowledge/` via kb-curate, sans référence au produit ; résultat ✅/❌/⚠️ dans `spikes.md` ; décision éventuelle via product-decide) → **Clôture** (commit, fusion, `publish.sh`).

## 3. Tests réels payants
GPT-Live réel seulement en Vérification d'une fonctionnalité voix, au plus une fois par fonctionnalité : `openai-budget.sh check <coût estimé>` doit répondre OK ; ensuite `openai-budget.sh add <coût réel> "NNN"` (coût tiré de l'usage renvoyé par l'API) et committe `specs/openai-spend.tsv`.

## 4. Enchaîner, puis finir l'itération
- Après une étape réussie, **enchaîne la suivante dans la même itération** si : `quota-check.sh` répond `OK`, l'itération a fait moins de **3 étapes** et dure depuis moins de **45 min**. Sinon, termine.
- Fin d'itération : `status.md` (journal, une ligne par étape) et `specs/progress.md` à jour ; `ScheduleWakeup` 60 s pour enchaîner (plus long seulement si tu attends quelque chose).

## Interdits
Trancher un arbitrage du porteur ; logistique et supports du talk ; `skip`, `.only`, `solo`, `t.Skip`, TODO ; modifier `AGENTS.md`, `CLAUDE.md`, `.claude/`, `tools/loop/` ; `git add -A`/`.`, `commit -a`/`--amend`/`--no-verify`, `push` direct (seul `publish.sh` publie), `pull`, `rebase`, `reset`, `stash`, `clean` ; deux sous-agents qui écrivent dans la même pile en même temps ; le modèle Fable.
