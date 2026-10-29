#!/usr/bin/env bash
# Arrêt de la boucle.
#   stop-loop.sh        STOP posé : la boucle finit son étape, s'arrête à l'itération suivante,
#                       et le superviseur ne relance plus rien. La session tmux reste ouverte
#                       pour consultation ; la fermer avant de relancer.
#   stop-loop.sh --now  STOP posé et session tmux fermée tout de suite (étape en cours perdue,
#                       reprise propre grâce à « Tâche en cours » dans status.md).
set -eu
. "$(dirname "$0")/lib.sh"
touch "$STATE/STOP"
loop_log "STOP posé${1:+ ($1)}"
if [ "${1:-}" = "--now" ]; then
  tmux kill-session -t "$LOOP_TMUX_SESSION" 2>/dev/null || true
  echo "Boucle arrêtée. Relancer : tools/loop/start-loop.sh (reprend la même conversation)"
else
  echo "STOP posé. Quand la boucle s'est arrêtée : tmux kill-session -t $LOOP_TMUX_SESSION, puis tools/loop/start-loop.sh pour relancer."
fi
