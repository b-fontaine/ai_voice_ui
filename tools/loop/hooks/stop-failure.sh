#!/usr/bin/env bash
# Hook StopFailure (matcher rate_limit) : la limite d'usage a réellement été atteinte.
# On garde l'instant et le JSON reçu ; le superviseur ne relance rien avant la remise à zéro.
. "$(dirname "$0")/../lib.sh"
payload="$(cat)"
date +%s > "$STATE/rate_limited_at"
printf '%s\t%s\n' "$(date -Iseconds)" "$(printf '%s' "$payload" | jq -c . 2>/dev/null || printf '%s' "$payload")" >> "$STATE/rate_limits.log"
exit 0
