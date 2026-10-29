#!/usr/bin/env bash
# Porte enregistrée : lance verify.sh et laisse une preuve que la boucle ne peut pas inventer.
#   gate.sh --unit [flutter|go] | --full
# - sortie complète dans $STATE/gates/<horodatage>-<mode>.log ;
# - ligne de résumé ajoutée à $STATE/gates.tsv (date, sha, arbre propre ?, mode, résultat) ;
# - en --full vert sur un arbre propre : HEAD est écrit dans $STATE/last_green_sha.
#   Le hook pre-push n'autorise la publication que de ce commit.
set -u
. "$(dirname "$0")/lib.sh"
cd "$LOOP_ROOT" || exit 1
MODE="${1:---full}"
mkdir -p "$STATE/gates"
LOG="$STATE/gates/$(date +%Y%m%d-%H%M%S)-${MODE#--}${2:+-$2}.log"
"$LOOP_ROOT/tools/loop/verify.sh" "$@" > "$LOG" 2>&1
rc=$?
sha="$(git rev-parse HEAD)"
clean=yes; [ -n "$(git status --porcelain)" ] && clean=no
printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$sha" "$clean" "$MODE${2:+ $2}" "$([ $rc -eq 0 ] && echo VERT || echo ROUGE)" >> "$STATE/gates.tsv"
if [ $rc -eq 0 ] && [ "$MODE" = --full ] && [ "$clean" = yes ]; then echo "$sha" > "$STATE/last_green_sha"; fi
tail -n 25 "$LOG"
echo "journal : $LOG"
exit $rc
