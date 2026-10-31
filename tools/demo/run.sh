#!/usr/bin/env bash
# Lance la démo Genesis Canvas en local pour un essai au micro (ou une répétition).
#   tools/demo/run.sh            backend + 3 agents (docker compose), puis l'app Linux en debug ;
#                                à la fermeture de l'app (ou Ctrl-C), la pile Docker est arrêtée.
#   tools/demo/run.sh --keep     même chose, mais la pile Docker reste démarrée à la fin.
#   tools/demo/run.sh --check    contrôle sans micro ni coût : pile + app sous Xvfb, capture PNG, arrêt.
#
# Isolation : projet Docker « genesis-demo » sur le port DEMO_PORT (8090 par défaut), pour ne pas
# gêner la pile de la boucle (projet « ai_voice_ui-loop », port 8080). Aucun fichier versionné
# n'est modifié ; la redirection de port passe par un fichier d'override temporaire.
# Prérequis : .env à la racine avec OPENAI_API_KEY (jamais commité), Docker, Flutter.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-run}"
PROJECT="${DEMO_PROJECT:-genesis-demo}"
PORT="${DEMO_PORT:-8090}"
NET="${DEMO_NET:-172.30.78}"
CATALOG_ID="$(sed -n 's/^x-a2ui-catalog: &a2ui_catalog \${A2UI_CATALOG_ID:-\(.*\)}$/\1/p' "$ROOT/docker-compose.yaml")"
CATALOG_ID="${A2UI_CATALOG_ID:-${CATALOG_ID:-https://genesis-canvas.example/a2ui/catalogs/genesis/v1}}"
OVERRIDE="$(mktemp --suffix=.yaml)"
compose() { docker compose -p "$PROJECT" -f "$ROOT/docker-compose.yaml" -f "$OVERRIDE" "$@"; }

cleanup() {
  rc=$?
  if [ "$MODE" != "--keep" ] || [ $rc -ne 0 ]; then
    echo "── arrêt de la pile Docker ($PROJECT)"
    compose down --remove-orphans >/dev/null 2>&1 || true
  else
    echo "── pile Docker laissée démarrée : docker compose -p $PROJECT down pour l'arrêter"
  fi
  rm -f "$OVERRIDE"
  exit $rc
}
trap cleanup EXIT INT TERM

case "$MODE" in run|--keep|--check) ;; *) echo "usage: $0 [--keep|--check]" >&2; exit 2 ;; esac
[ -f "$ROOT/.env" ] || { echo "Il manque $ROOT/.env : printf 'OPENAI_API_KEY=sk-...\\n' > .env" >&2; exit 1; }
grep -q '^OPENAI_API_KEY=.\+' "$ROOT/.env" || { echo "OPENAI_API_KEY absente ou vide dans .env" >&2; exit 1; }
if ss -ltn 2>/dev/null | grep -q "127.0.0.1:$PORT "; then
  echo "Le port $PORT est déjà pris : relance avec DEMO_PORT=8091 $0" >&2; exit 1
fi

# Le compose fixe le sous-réseau des agents (172.30.77.0/24) et leurs adresses (la passerelle LLM
# filtre par adresse source) : la démo prend un autre /24 pour coexister avec la pile de la boucle.
if docker network ls -q | xargs -r docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | grep -qw "$NET.0/24"; then
  echo "Le sous-réseau $NET.0/24 est déjà pris : relance avec DEMO_NET=172.30.79 $0" >&2; exit 1
fi
cat > "$OVERRIDE" <<YAML
services:
  orchestrator:
    ports: !override
      - "127.0.0.1:$PORT:8080"
    environment:
      ALLOWED_HOSTS: "127.0.0.1:$PORT,localhost:$PORT"
      LLM_GATEWAY_ADDR: "$NET.10:8081"
      LLM_GATEWAY_ALLOWED_SOURCES: "$NET.21,$NET.30"
    networks:
      agents:
        ipv4_address: $NET.10
  agent-quality:
    environment:
      COMPOSER_LLM_URL: "http://$NET.10:8081/v1/complete"
    networks:
      agents:
        ipv4_address: $NET.21
  agent-voice:
    networks:
      agents:
        ipv4_address: $NET.22
  agent-delivery:
    networks:
      agents:
        ipv4_address: $NET.23
  composer-bench:
    environment:
      COMPOSER_LLM_URL: "http://$NET.10:8081/v1/complete"
    networks:
      agents:
        ipv4_address: $NET.30
networks:
  agents:
    ipam: !override
      config:
        - subnet: $NET.0/24
YAML

echo "── backend et agents (projet $PROJECT, port $PORT) : construction et démarrage…"
compose up --build -d --wait
# Vérifie aussi le garde de l'en-tête Host (421 si le port n'est pas autorisé).
curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null || { echo "L'orchestrateur ne répond pas correctement sur le port $PORT" >&2; exit 1; }
echo "   orchestrateur prêt sur http://127.0.0.1:$PORT"

APP="$ROOT/apps/genesis_canvas"
export GENESIS_BACKEND_URL="http://127.0.0.1:$PORT" GENESIS_CATALOG_ID="$CATALOG_ID"
if [ "$MODE" = "--check" ]; then
  command -v xvfb-run >/dev/null || { echo "xvfb-run absent (sudo apt install xvfb)" >&2; exit 1; }
  PNG="$(mktemp --suffix=.png)"
  echo "── contrôle de l'app sous Xvfb (aucune session voix ouverte)…"
  ( cd "$APP" && flutter build linux --debug >/dev/null )
  BIN="$(find "$APP/build/linux/x64/debug/bundle" -maxdepth 1 -type f -executable | head -1)"
  GDK_BACKEND=x11 GENESIS_SNAPSHOT="$PNG" timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" "$BIN" >/dev/null 2>&1 || true
  if [ -s "$PNG" ]; then echo "OK : l'app démarre et se connecte à la configuration ; capture $PNG"; else echo "ÉCHEC : pas de capture de l'app" >&2; exit 1; fi
else
  echo "── lancement de l'app (fermer la fenêtre ou Ctrl-C pour terminer)"
  echo "   Démarrer → « Prépare la release 3.4 » → « Concentre-toi sur Android et compare avec la 3.3 » → clic « Bloquer la release »"
  ( cd "$APP" && flutter run -d linux )
fi
