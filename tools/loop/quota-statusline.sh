#!/usr/bin/env bash
# Barre d'état de la session de boucle.
# Claude Code envoie sur stdin un JSON avec rate_limits (abonnés claude.ai) :
#   rate_limits.five_hour.{used_percentage,resets_at}, rate_limits.seven_day.{...}
# On l'enregistre dans $STATE/quota.json. changed_at ne bouge que si les valeurs changent :
# il mesure la fraîcheur des données, pas celle de l'affichage.
# L'affichage est ensuite délégué à la barre d'état habituelle ($LOOP_STATUSLINE_DELEGATE).
set -u
. "$(dirname "$0")/lib.sh"
input="$(cat)"
rl="$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)"
if [ -n "$rl" ]; then
  prev="$(jq -c '.rate_limits // empty' "$STATE/quota.json" 2>/dev/null)"
  changed_at="$(jq -r '.changed_at // empty' "$STATE/quota.json" 2>/dev/null)"
  [ "$rl" != "$prev" ] || [ -z "$changed_at" ] && changed_at="$(date +%s)"
  jq -n --argjson rl "$rl" --argjson c "$changed_at" --argjson s "$(date +%s)" \
    '{changed_at: $c, seen_at: $s, rate_limits: $rl}' > "$STATE/quota.json.tmp" \
    && mv "$STATE/quota.json.tmp" "$STATE/quota.json"
fi
if [ -n "${LOOP_STATUSLINE_DELEGATE:-}" ]; then
  printf '%s' "$input" | sh -c "$LOOP_STATUSLINE_DELEGATE"
else
  printf '%s' "$input" | jq -r '"boucle · 5h " + ((.rate_limits.five_hour.used_percentage // "?")|tostring) + "% · 7j " + ((.rate_limits.seven_day.used_percentage // "?")|tostring) + "%"' 2>/dev/null
fi
