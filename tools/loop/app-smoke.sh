#!/usr/bin/env bash
# Essai réel de l'application, hors écran du porteur (Xvfb, GDK en X11) :
# 1. démarre le backend (docker compose) s'il existe ;
# 2. compile l'app Linux (debug) et la lance avec GENESIS_SCENARIO=<nom> et GENESIS_SNAPSHOT=<png> :
#    l'app rejoue le scénario, écrit une capture PNG de sa fenêtre et se ferme
#    (mode livré par specs/000-loop-harness) ;
# 3. affiche le chemin de la capture, à ouvrir avec l'outil Read.
# Codes : 0 capture OK · 1 échec de l'app (compte comme une tentative) ·
#         4 environnement indisponible (Xvfb manquant : ne compte pas comme tentative)
# Usage : app-smoke.sh [scenario] (défaut : act1-replay, rejeu A2UI sans micro ni coût)
set -u
. "$(dirname "$0")/lib.sh"
APP="$LOOP_ROOT/apps/genesis_canvas"
OUT="$STATE/snapshots"; mkdir -p "$OUT"
SCENARIO="${1:-act1-replay}"
PNG="$OUT/$(date +%Y%m%d-%H%M%S)-$SCENARIO.png"

[ -f "$APP/pubspec.yaml" ] || { echo "SKIP pas encore d'app ($APP)"; exit 0; }
command -v xvfb-run >/dev/null || { echo "UNAVAILABLE xvfb-run absent (sudo apt install xvfb)"; exit 4; }

if [ -f "$LOOP_ROOT/docker-compose.yaml" ]; then
  docker compose -f "$LOOP_ROOT/docker-compose.yaml" up -d --build --wait > "$OUT/last-compose.log" 2>&1 \
    || { echo "FAIL backend (voir $OUT/last-compose.log)"; exit 1; }
fi
( cd "$APP" && flutter build linux --debug ) > "$OUT/last-build.log" 2>&1 \
  || { echo "FAIL build (voir $OUT/last-build.log ; après un échec CMake : flutter clean)"; exit 1; }
BIN="$(find "$APP/build/linux/x64/debug/bundle" -maxdepth 1 -type f -executable | head -1)"

GDK_BACKEND=x11 GENESIS_SNAPSHOT="$PNG" GENESIS_SCENARIO="$SCENARIO" \
  timeout 180 xvfb-run -a -s "-screen 0 1920x1080x24" "$BIN" > "$OUT/last-run.log" 2>&1
rc=$?
if [ -s "$PNG" ]; then echo "OK capture : $PNG"; exit 0; fi
echo "FAIL pas de capture (code $rc, voir $OUT/last-run.log)"; exit 1
