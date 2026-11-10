#!/usr/bin/env bash
# Aligne le dépôt sur le SDK Flutter installé localement, puis met à jour les dépendances.
#   tools/flutter-upgrade.sh            écrit la version de Flutter et de Dart du SDK local dans
#                                       tous les pubspec.yaml du workspace, lance `flutter pub upgrade`
#                                       (dans les contraintes déclarées) et liste ce qui reste en retard
#   tools/flutter-upgrade.sh --verify   même chose, puis porte complète (tools/loop/gate.sh --full)
#   tools/flutter-upgrade.sh --check    ne modifie rien ; code 1 si le dépôt et le SDK local divergent
#
# La CI lit la version de Flutter dans le pubspec.yaml racine (flutter-version-file) : rien à y changer.
# Les versions des dépendances directes sont figées à la main (pdr-0010) : ce script ne les touche pas,
# il ne fait monter que les dépendances transitives. Les spikes (spikes/) sont des relevés datés : non touchés.
# Une montée de Flutter se consigne par une PDR et passe par une PR dédiée, suivie d'une répétition.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-}"
case "$MODE" in ""|--verify|--check) ;; *) echo "usage: $0 [--verify|--check]" >&2; exit 2 ;; esac

MACHINE="$(flutter --version --machine)"
field() { printf '%s\n' "$MACHINE" | sed -n "s/^ *\"$1\": *\"\([^\"]*\)\".*/\1/p" | head -n 1; }
FLUTTER="$(field frameworkVersion)"; DART="$(field dartSdkVersion)"
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+$'
[[ "$FLUTTER" =~ $SEMVER && "$DART" =~ $SEMVER ]] || {
  echo "SDK local non stable ou illisible (Flutter « $FLUTTER », Dart « $DART ») : rien n'est modifié." >&2; exit 1; }

pinned() { sed -n "s/^  $1: *\([0-9][0-9.]*\) *$/\1/p" pubspec.yaml | head -n 1; }
OLD_FLUTTER="$(pinned flutter)"; OLD_DART="$(pinned sdk)"
echo "SDK local : Flutter $FLUTTER, Dart $DART — dépôt : Flutter ${OLD_FLUTTER:-?}, Dart ${OLD_DART:-?}"

# Un paquet Dart pur (sans Flutter) ne déclare que `sdk:` : la ligne `flutter:` n'est exigée que si elle existe.
aligned() { grep -qx "  sdk: $DART" "$1" && { ! grep -q '^  flutter: [0-9]' "$1" || grep -qx "  flutter: $FLUTTER" "$1"; }; }

mapfile -t PUBS < <({ echo pubspec.yaml; find apps packages testing -name pubspec.yaml -not -path '*/.dart_tool/*' -not -path '*/build/*'; } | sort)

if [ "$MODE" = --check ]; then
  drift=0
  for p in "${PUBS[@]}"; do
    aligned "$p" || { echo "à aligner : $p"; drift=1; }
  done
  grep -q "\"$FLUTTER\"" <(sed -n '/^sdks:/,$p' pubspec.lock) || { echo "à aligner : pubspec.lock"; drift=1; }
  [ $drift -eq 0 ] && echo "Dépôt aligné sur le SDK local."
  exit $drift
fi

for p in "${PUBS[@]}"; do
  sed -i -E "s/^  flutter: [0-9]+\.[0-9]+\.[0-9]+ *$/  flutter: $FLUTTER/; s/^  sdk: [0-9]+\.[0-9]+\.[0-9]+ *$/  sdk: $DART/" "$p"
  aligned "$p" || {
    echo "Contrainte SDK non exacte dans $p : à corriger à la main." >&2; exit 1; }
done
echo "── ${#PUBS[@]} pubspec.yaml alignés"

echo "── flutter pub upgrade"
flutter pub upgrade
echo "── dépendances encore en retard (figées à la main ou bloquées par une contrainte)"
flutter pub outdated || true

if [ "$MODE" = --verify ]; then
  echo "── porte complète"
  tools/loop/gate.sh --full
fi

cat <<EOF

Reste à faire à la main :
  - relire le diff (pubspec.yaml, pubspec.lock) ;
  - si Flutter a changé (${OLD_FLUTTER:-?} → $FLUTTER) : PDR qui remplace la version figée, PR dédiée, répétition ;
  - tools/loop/gate.sh --full avant toute fusion$([ "$MODE" = --verify ] && echo " (fait ci-dessus)").
EOF
