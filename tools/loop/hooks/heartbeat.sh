#!/usr/bin/env bash
# Hook PostToolUse de la session de boucle : chaque appel d'outil prouve que la boucle travaille.
. "$(dirname "$0")/../lib.sh"
date +%s > "$STATE/heartbeat"
cat > /dev/null
exit 0
