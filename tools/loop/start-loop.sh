#!/usr/bin/env bash
# Lance (ou relance) la session de boucle dans tmux, DANS LE WORKTREE DE BOUCLE.
# - La session a un identifiant fixe ($STATE/session_id) : un redémarrage reprend toujours
#   CETTE conversation (--resume <id>), jamais celle du porteur.
# - La consigne /loop est passée en argument : rien n'est tapé dans l'interface.
# - Réglages : modèle et effort de loop.env, mode auto, réglages projet + réglages de boucle
#   générés (chemins absolus), sans les réglages utilisateur (plugins, hooks globaux).
set -eu
. "$(dirname "$0")/lib.sh"
[ "$(git -C "$LOOP_ROOT" rev-parse --abbrev-ref HEAD)" != main ] \
  || { echo "refus : à lancer depuis le worktree de boucle (tools/loop/setup-worktree.sh), pas depuis main"; exit 1; }

if tmux has-session -t "$LOOP_TMUX_SESSION" 2>/dev/null; then
  echo "La session tmux $LOOP_TMUX_SESSION tourne déjà (tmux attach -t $LOOP_TMUX_SESSION)."; exit 1
fi
rm -f "$STATE/STOP" "$STATE/paused_until"

sed "s#@ROOT@#$LOOP_ROOT#g" "$LOOP_ROOT/tools/loop/settings.loop.template.json" > "$STATE/settings.json"
DELEGATE="$(jq -r '.statusLine.command // empty' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null || true)"

[ -s "$STATE/session_id" ] || uuidgen > "$STATE/session_id"
SID="$(cat "$STATE/session_id")"
# Reprendre seulement si la conversation existe vraiment (transcript écrit par Claude Code).
if find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -maxdepth 2 -name "$SID.jsonl" 2>/dev/null | grep -q .; then
  SESSION_ARGS=(--resume "$SID")
else
  SESSION_ARGS=(--session-id "$SID")
fi
PROMPT='/loop Exécute une itération du skill dev-loop (.claude/skills/dev-loop/SKILL.md).'

# shellcheck disable=SC2054  # « project,local » est une seule valeur
CMD=(claude "${SESSION_ARGS[@]}" --model "$LOOP_MODEL" --effort "$LOOP_EFFORT"
     --permission-mode auto --setting-sources project,local --settings "$STATE/settings.json"
     -n "$LOOP_TMUX_SESSION" "$PROMPT")
printf -v CMD_STR '%q ' "${CMD[@]}"

tmux new-session -d -s "$LOOP_TMUX_SESSION" -c "$LOOP_ROOT" \
  -e "LOOP_STATUSLINE_DELEGATE=$DELEGATE" -e "DISABLE_OMC=1" "exec $CMD_STR"
date +%s > "$STATE/heartbeat"
loop_log "démarrage ${SESSION_ARGS[0]} $(cat "$STATE/session_id")"
echo "Boucle lancée (tmux $LOOP_TMUX_SESSION, dossier $LOOP_ROOT). Suivre : tmux attach -t $LOOP_TMUX_SESSION"
