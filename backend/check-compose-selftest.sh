#!/usr/bin/env bash
# Auto-test de check-compose.sh (pdr-0074, 012) : chaque surcharge de backend/testdata/compose-bad-*.yaml
# viole UNE regle de la passerelle LLM interne et DOIT faire echouer le controle, avec le message annonce
# par sa premiere ligne `# attendu: <fragment>` (une surcharge mal formee ne passe donc pas pour une
# regle verifiee). Le compose de reference doit, lui, passer. Controle positif : `COMPOSER_MODEL=` vide
# desactive le modele (filet de pdr-0060). check-compose.sh n'est lance que par la CI : meme endroit.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bash backend/check-compose.sh >/dev/null

failed=0
count=0
for bad in backend/testdata/compose-bad-*.yaml; do
  count=$((count + 1))
  expected="$(sed -n '1s/^# attendu: //p' "$bad")"
  if [ -z "$expected" ]; then
    echo "ECHEC : $bad n'annonce pas son message attendu (premiere ligne '# attendu: ...')" >&2
    failed=1
    continue
  fi
  if out="$(COMPOSE_FILE="docker-compose.yaml:$bad" bash backend/check-compose.sh 2>&1)"; then
    echo "ECHEC : $bad aurait du faire echouer check-compose.sh" >&2
    failed=1
  elif ! grep -qF -- "$expected" <<<"$out"; then
    echo "ECHEC : $bad a echoue pour une autre raison que '$expected'" >&2
    failed=1
  fi
done
[ "$count" -ge 1 ] || { echo "ECHEC : aucune surcharge compose-bad-*.yaml" >&2; exit 1; }

# Controle positif : une valeur VIDE desactive le modele ; une variable absente prend le defaut.
model_of() {
  docker compose config --format json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["services"]["orchestrator"]["environment"].get("COMPOSER_MODEL", "<absent>"))'
}
if [ "$(env COMPOSER_MODEL= bash -c "$(declare -f model_of); model_of")" != "" ]; then
  echo "ECHEC : COMPOSER_MODEL vide devrait desactiver le modele" >&2
  failed=1
fi
if [ -z "$(env -u COMPOSER_MODEL bash -c "$(declare -f model_of); model_of")" ]; then
  echo "ECHEC : COMPOSER_MODEL absent devrait prendre la valeur par defaut" >&2
  failed=1
fi

[ "$failed" -eq 0 ] || exit 1
echo "check-compose-selftest : OK ($count surcharges refusees pour la bonne raison, filet modele vide verifie)"
