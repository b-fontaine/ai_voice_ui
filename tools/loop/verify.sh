#!/usr/bin/env bash
# Porte de qualité : lints + génération de code + tests de chaque pile présente.
#   verify.sh --unit [flutter|go]  porte d'une tâche TDD : tests d'acceptation exclus
#                                  (Flutter : test/acceptance/ ; Go : build tag « acceptance »),
#                                  éventuellement limitée à une pile
#   verify.sh --full               porte complète, acceptation comprise (Vérification, Clôture, publication)
# Une pile absente est signalée, jamais comptée verte en silence. Code retour 0 seulement si
# tout ce qui a tourné est vert.
set -u
. "$(dirname "$0")/lib.sh"
cd "$LOOP_ROOT" || exit 1
MODE="${1:---full}"; ONLY="${2:-}"
case "$MODE" in --unit|--full) ;; *) echo "usage: $0 --unit [flutter|go] | --full" >&2; exit 2 ;; esac
fail=0; ran=0
step() { local name="$1"; shift; echo "── $name"; if "$@"; then echo "   ✓"; else echo "   ✗ ÉCHEC"; fail=1; fi; ran=$((ran+1)); }
skip() { echo "── $1 : sauté ($2)"; }
want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }
SRC_DIRS=(); for d in apps packages testing backend; do [ -d "$d" ] && SRC_DIRS+=("$d"); done

step "lint knowledge/" python3 -I knowledge/_tools/kb_lint.py
step "lint product/"   python3 -I product/_tools/product_lint.py

# Tests désactivés ou focalisés, et marqueurs d'inachevé : interdits.
no_placeholders() {
  [ "${#SRC_DIRS[@]}" -eq 0 ] && return 0
  ! grep -rnE --include='*.dart' --include='*.go' \
      -e '\bskip: *(true|['"'"'"])' -e '\bsolo: *true' -e '\b(test|group|testWidgets)\.only\(' \
      -e '\bt\.Skip(Now|f)?\(' -e '\b(TODO|FIXME|XXX)\b' \
      --exclude='*.g.dart' --exclude='*.freezed.dart' --exclude='*.config.dart' \
      --exclude-dir=build --exclude-dir=.dart_tool "${SRC_DIRS[@]}"
}
step "pas de skip/only/TODO" no_placeholders

# Go hors de backend/ : refusé (il ne serait pas testé).
stray_go() { ! find . -name go.mod -not -path './backend/*' -not -path './spikes/*' -not -path './.omc/*' | grep -q .; }
step "go.mod uniquement sous backend/" stray_go

if want flutter; then
  mapfile -t PUBS < <(find apps packages testing -name pubspec.yaml -not -path '*/.dart_tool/*' -not -path '*/build/*' 2>/dev/null | sort)
  [ "${#PUBS[@]}" -eq 0 ] && skip "Flutter" "aucun pubspec.yaml sous apps/, packages/ ou testing/"
  for p in "${PUBS[@]}"; do
    d="$(dirname "$p")"
    if grep -q '^ *build_runner:' "$p"; then
      step "build_runner ($d)" bash -c "cd '$d' && dart run build_runner build --delete-conflicting-outputs >/dev/null"
      # Les tests générés par bdd_widget_test ne sont pas formatés : on les formate ici,
      # pour que le contrôle de format ne porte que sur le code écrit à la main.
      [ -d "$d/test/acceptance" ] && (cd "$d" && dart format test/acceptance >/dev/null)
    fi
    fmt_targets=(lib); [ -d "$d/test" ] && fmt_targets+=(test)
    step "dart format ($d)"     bash -c "cd '$d' && dart format --output=none --set-exit-if-changed ${fmt_targets[*]}"
    step "flutter analyze ($d)" bash -c "cd '$d' && flutter analyze --fatal-infos"
    if [ ! -d "$d/test" ]; then skip "flutter test ($d)" "pas de test/"; continue; fi
    if [ "$MODE" = --full ]; then
      step "flutter test ($d)" bash -c "cd '$d' && flutter test"
    else
      mapfile -t UT < <(cd "$d" && find test -name '*_test.dart' -not -path 'test/acceptance/*' | sort)
      if [ "${#UT[@]}" -eq 0 ]; then skip "flutter test unitaires ($d)" "aucun"; else
        step "flutter test unitaires ($d)" bash -c "cd '$d' && flutter test ${UT[*]}"; fi
    fi
  done
fi

if want go; then
  mapfile -t MODS < <(find backend -name go.mod -not -path '*/vendor/*' 2>/dev/null | sort)
  [ "${#MODS[@]}" -eq 0 ] && skip "Go" "aucun go.mod sous backend/"
  TAGS=""; [ "$MODE" = --full ] && TAGS="-tags acceptance"
  for m in "${MODS[@]}"; do
    d="$(dirname "$m")"
    step "gofmt ($d)"  bash -c "cd '$d' && test -z \"\$(gofmt -l .)\""
    step "go vet ($d)" bash -c "cd '$d' && go vet $TAGS ./..."
    if command -v golangci-lint >/dev/null; then step "golangci-lint ($d)" bash -c "cd '$d' && golangci-lint run $TAGS"; else skip "golangci-lint ($d)" "non installé"; fi
    step "go test ($d)" bash -c "cd '$d' && go test -race $TAGS ./..."
  done
fi

if [ "$MODE" = --full ] && [ -f docker-compose.yaml ]; then step "docker compose config" docker compose config -q; fi

echo "== $MODE${ONLY:+ ($ONLY)} : $ran contrôles, $([ $fail -eq 0 ] && echo 'TOUT VERT' || echo 'ROUGE')"
exit $fail
