#!/usr/bin/env bash
# Registre des dépenses OpenAI réelles de la boucle. Versionné (specs/openai-spend.tsv) pour
# survivre à un nettoyage de .omc/. Plafond : LOOP_OPENAI_CAP_EUR (loop.env), le reste des 20 €
# est réservé aux répétitions du porteur. Fixer aussi une limite dure sur le projet OpenAI.
#   openai-budget.sh add <eur> "<note>"   montant au format 0.35 (point décimal)
#   openai-budget.sh check [<eur prévus>] 0 si ça tient sous le plafond, 11 sinon
#   openai-budget.sh total
set -eu
export LC_ALL=C
. "$(dirname "$0")/lib.sh"
LEDGER="${LOOP_OPENAI_LEDGER:-$LOOP_ROOT/specs/openai-spend.tsv}"
touch "$LEDGER"
total() { awk -F'\t' '{s+=$2} END {printf "%.2f", s+0}' "$LEDGER"; }
amount_ok() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "montant invalide : $1 (attendu : 0.35)" >&2; exit 2; }; }
case "${1:-total}" in
  add)   amount_ok "${2:-}"; printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$2" "${3:-}" >> "$LEDGER"
         echo "total $(total) € / plafond boucle $LOOP_OPENAI_CAP_EUR €" ;;
  check) planned="${2:-0}"; amount_ok "$planned"; t=$(total)
         if awk -v t="$t" -v p="$planned" -v c="$LOOP_OPENAI_CAP_EUR" 'BEGIN{exit !(t+p<=c)}'; then
           echo "OK $t € + $planned € <= $LOOP_OPENAI_CAP_EUR €"
         else echo "STOP $t € + $planned € > $LOOP_OPENAI_CAP_EUR € : test réel interdit, faux fournisseur seulement"; exit 11; fi ;;
  total) echo "$(total) € / plafond boucle $LOOP_OPENAI_CAP_EUR €" ;;
  *) echo "usage: $0 add|check|total" >&2; exit 2 ;;
esac
