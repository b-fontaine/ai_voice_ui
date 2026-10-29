# shellcheck shell=bash
# Bibliothèque commune des scripts de boucle (à sourcer, pas à exécuter).
# Définit LOOP_ROOT (racine du dépôt ou du worktree qui contient ce script), STATE, charge loop.env.
LOOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=loop.env
. "$LOOP_ROOT/tools/loop/loop.env"
# shellcheck disable=SC1091
[ -f "$LOOP_ROOT/tools/loop/loop.local.env" ] && . "$LOOP_ROOT/tools/loop/loop.local.env"
STATE="${LOOP_STATE_DIR:-$LOOP_ROOT/.omc/state/loop}"
mkdir -p "$STATE"
LOOP_NOW="${LOOP_NOW:-$(date +%s)}"
loop_log() { echo "$(date '+%F %T') $*" | tee -a "$STATE/loop.log"; }
is_int() { [[ "${1:-}" =~ ^-?[0-9]+$ ]]; }
