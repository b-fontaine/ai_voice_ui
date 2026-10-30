#!/usr/bin/env bash
# Auto-test de check-compose.sh (pdr-0074, 012) : chaque surcharge de backend/testdata/compose-bad-*.yaml
# viole une regle de la passerelle LLM interne et DOIT faire echouer le controle. Le compose de
# reference doit, lui, passer. check-compose.sh n'est lance que par la CI : brancher cet auto-test au meme endroit.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bash backend/check-compose.sh >/dev/null

failed=0
count=0
for bad in backend/testdata/compose-bad-*.yaml; do
  count=$((count + 1))
  if COMPOSE_FILE="docker-compose.yaml:$bad" bash backend/check-compose.sh >/dev/null 2>&1; then
    echo "ECHEC : $bad aurait du faire echouer check-compose.sh" >&2
    failed=1
  fi
done
[ "$count" -ge 1 ] || { echo "ECHEC : aucune surcharge compose-bad-*.yaml" >&2; exit 1; }
[ "$failed" -eq 0 ] || exit 1
echo "check-compose-selftest : OK ($count surcharges refusees)"
