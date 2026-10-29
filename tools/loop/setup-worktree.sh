#!/usr/bin/env bash
# Crée (une fois) le worktree de la boucle, à côté du dépôt du porteur :
#   ../$LOOP_WORKTREE_NAME sur la branche $LOOP_BRANCH, partie de origin/main.
# La boucle n'écrit jamais dans l'arbre du porteur ; elle publie sur origin/main via publish.sh.
# Le hook pre-push est activé pour ce seul worktree (configuration --worktree).
set -eu
. "$(dirname "$0")/lib.sh"
REPO="$(git -C "$LOOP_ROOT" rev-parse --path-format=absolute --git-common-dir)"
REPO="$(dirname "$REPO")"
WT="$(dirname "$REPO")/$LOOP_WORKTREE_NAME"
if [ -d "$WT" ]; then echo "worktree déjà présent : $WT"; exit 0; fi
git -C "$REPO" fetch origin main
git -C "$REPO" ls-tree -d --name-only origin/main tools/loop | grep -q . \
  || { echo "tools/loop n'est pas encore sur origin/main : committer et pousser le dispositif d'abord"; exit 1; }
git -C "$REPO" worktree add -B "$LOOP_BRANCH" "$WT" origin/main
git -C "$REPO" config extensions.worktreeConfig true
git -C "$WT" config --worktree core.hooksPath "$WT/tools/loop/git-hooks"
chmod +x "$WT"/tools/loop/*.sh "$WT"/tools/loop/hooks/*.sh "$WT"/tools/loop/git-hooks/*
echo "worktree prêt : $WT (branche $LOOP_BRANCH)"
