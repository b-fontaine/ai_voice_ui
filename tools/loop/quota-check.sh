#!/usr/bin/env bash
# La boucle peut-elle lancer une étape ? Lit $STATE/quota.json.
#   OK <détail>                    -> 0
#   PAUSE <epoch_reprise> <raison> -> 10
#   UNKNOWN <raison>               -> 0  (pas de donnée valide et fraîche : étape courte seulement)
# Règles (loop.env) :
#   - 5 h : pause si used >= LOOP_MAX_5H, jusqu'à resets_at ;
#   - semaine : autorisé = part écoulée × LOOP_WEEK_SHARE/100 + LOOP_WEEK_MARGIN, plafonné à
#     LOOP_MAX_7D ; au-delà, pause jusqu'à ce que le lissage rattrape la consommation.
set -u
. "$(dirname "$0")/lib.sh"
F="$STATE/quota.json"
WEEK=604800
NOW=$LOOP_NOW

[ -s "$F" ] || { echo "UNKNOWN pas de quota.json (barre d'état de boucle inactive ?)"; exit 0; }
IFS=$'\t' read -r chg h_used h_reset w_used w_reset < <(jq -r '[(.changed_at // ""),
  (.rate_limits.five_hour.used_percentage // "" | if type=="number" then floor else . end),
  (.rate_limits.five_hour.resets_at // "" | if type=="number" then floor else . end),
  (.rate_limits.seven_day.used_percentage // "" | if type=="number" then floor else . end),
  (.rate_limits.seven_day.resets_at // "" | if type=="number" then floor else . end)] | @tsv' "$F" 2>/dev/null)
for v in "$chg" "$h_used" "$h_reset" "$w_used" "$w_reset"; do
  is_int "$v" || { echo "UNKNOWN quota.json invalide"; exit 0; }
done
if [ $(( NOW - chg )) -gt "$LOOP_QUOTA_STALE_S" ] && [ "$h_reset" -le "$NOW" ]; then
  echo "UNKNOWN données de quota anciennes ($(( (NOW - chg) / 60 )) min) et fenêtre 5 h expirée"; exit 0
fi

if [ "$h_reset" -gt "$NOW" ] && [ "$h_used" -ge "$LOOP_MAX_5H" ]; then
  echo "PAUSE $h_reset fenêtre 5 h à ${h_used} % (seuil ${LOOP_MAX_5H} %)"; exit 10
fi

if [ "$w_reset" -gt "$NOW" ]; then
  start=$(( w_reset - WEEK ))
  elapsed_pct=$(( (NOW - start) * 100 / WEEK ))
  allowed=$(( elapsed_pct * LOOP_WEEK_SHARE / 100 + LOOP_WEEK_MARGIN ))
  [ "$allowed" -gt "$LOOP_MAX_7D" ] && allowed=$LOOP_MAX_7D
  if [ "$w_used" -gt "$allowed" ]; then
    if [ "$w_used" -ge "$LOOP_MAX_7D" ]; then resume=$w_reset
    else
      need_pct=$(( ((w_used - LOOP_WEEK_MARGIN) * 100 + LOOP_WEEK_SHARE - 1) / LOOP_WEEK_SHARE ))
      resume=$(( start + need_pct * WEEK / 100 ))
      [ "$resume" -gt "$w_reset" ] && resume=$w_reset
    fi
    [ "$resume" -le "$NOW" ] && resume=$(( NOW + 600 ))
    echo "PAUSE $resume semaine à ${w_used} % pour ${elapsed_pct} % du temps écoulé (autorisé ${allowed} %)"; exit 10
  fi
fi
echo "OK 5h ${h_used} % · 7j ${w_used} %"; exit 0
