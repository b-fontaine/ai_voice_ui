#!/usr/bin/env bash
# Publie la branche de boucle sur origin/main, sans réécrire l'historique.
# 1. arbre propre exigé ; 2. git fetch ; 3. fusion de origin/main dans la branche de boucle
#    (merge, jamais rebase) ; conflit -> merge annulé, code 3 (question pour le porteur) ;
# 4. gate.sh --full ; 5. git push origin <branche>:main (le hook pre-push revérifie).
# Codes : 0 publié · 1 porte rouge · 2 arbre sale · 3 conflit · 4 push refusé
set -u
. "$(dirname "$0")/lib.sh"
cd "$LOOP_ROOT" || exit 1
[ -z "$(git status --porcelain)" ] || { echo "arbre non propre : committer d'abord"; exit 2; }
git fetch origin main || { echo "fetch impossible"; exit 4; }
if ! git merge-base --is-ancestor origin/main HEAD; then
  if ! git merge --no-edit origin/main; then git merge --abort; echo "CONFLIT avec origin/main : question pour le porteur"; exit 3; fi
fi
"$LOOP_ROOT/tools/loop/gate.sh" --full || { echo "porte rouge après fusion : rien n'est publié"; exit 1; }
git push origin "HEAD:main" || exit 4
echo "publié : $(git rev-parse --short HEAD) -> origin/main"
