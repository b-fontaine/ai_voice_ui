#!/usr/bin/env bash
# Superviseur : à lancer dans son propre terminal (ou une fenêtre tmux à part), depuis le worktree.
# Il ne tape JAMAIS dans la session de boucle : il la ferme et la relance (--resume <id>),
# seulement quand elle est inactive. Toutes les LOOP_SUPERVISE_S secondes :
#   1. STOP présent                            -> sort ;
#   2. pause en cours (quota lissé, limite atteinte) -> attend ;
#   3. session absente, ou pause longue terminée (paused_until dépassé) -> relance ;
#   4. aucune activité (hook PostToolUse) depuis LOOP_STALE_S ET écran inactif -> relance.
# --once : un seul passage (tests).
set -u
. "$(dirname "$0")/lib.sh"
ONCE=""; [ "${1:-}" = "--once" ] && ONCE=1
slog() { echo "$(date '+%F %T') superviseur : $*" | tee -a "$STATE/supervisor.log"; }

pane_busy() {   # vrai si un tour est en cours, une boîte de dialogue ou une attente de quota s'affiche
  tmux capture-pane -p -t "$LOOP_TMUX_SESSION" 2>/dev/null | tail -n 15 \
    | grep -qiE 'esc to (interrupt|cancel)|enter to confirm|continuing automatically|limit reached|do you want|❯ *[0-9]\.'
}
restart() {
  slog "relance : $1"
  tmux kill-session -t "$LOOP_TMUX_SESSION" 2>/dev/null || true
  "$LOOP_ROOT/tools/loop/start-loop.sh" >> "$STATE/supervisor.log" 2>&1 || slog "échec de relance"
}
pause_until() {   # max(pause demandée par la boucle, remise à zéro après une limite atteinte)
  local now=$1 until hb limited reset w_used
  until=$(cat "$STATE/paused_until" 2>/dev/null); is_int "$until" || until=0
  hb=$(cat "$STATE/heartbeat" 2>/dev/null); is_int "$hb" || hb=0
  limited=$(cat "$STATE/rate_limited_at" 2>/dev/null); is_int "$limited" || limited=0
  if [ "$limited" -ge "$hb" ] && [ "$limited" -gt 0 ] && [ -s "$STATE/quota.json" ]; then
    w_used=$(jq -r '.rate_limits.seven_day.used_percentage // 0 | floor' "$STATE/quota.json")
    if [ "$w_used" -ge "$LOOP_MAX_7D" ]; then reset=$(jq -r '.rate_limits.seven_day.resets_at // 0 | floor' "$STATE/quota.json")
    else reset=$(jq -r '.rate_limits.five_hour.resets_at // 0 | floor' "$STATE/quota.json"); fi
    is_int "$reset" || reset=0
    [ "$reset" -le "$now" ] && reset=$(( limited + 1800 ))   # remise à zéro inconnue ou passée : 30 min
    [ $(( reset + 120 )) -gt "$until" ] && until=$(( reset + 120 ))
  fi
  echo "$until"
}

while true; do
  now=$(date +%s)
  if [ -f "$STATE/STOP" ]; then slog "STOP présent : arrêt"; exit 0; fi
  until=$(pause_until "$now")
  if [ "$until" -gt "$now" ]; then
    slog "pause jusqu'à $(date -d @"$until" '+%F %T')"
  elif ! tmux has-session -t "$LOOP_TMUX_SESSION" 2>/dev/null; then
    restart "session absente"
  elif [ -f "$STATE/paused_until" ] && ! pane_busy; then
    restart "fin de la pause longue"   # la boucle s'était arrêtée en écrivant paused_until
  else
    hb=$(cat "$STATE/heartbeat" 2>/dev/null); is_int "$hb" || hb=0
    if [ $(( now - hb )) -gt "$LOOP_STALE_S" ] && ! pane_busy; then
      restart "aucune activité depuis $(( (now - hb) / 60 )) min et session inactive"
    fi
  fi
  [ -n "$ONCE" ] && exit 0
  sleep "$LOOP_SUPERVISE_S"
done
