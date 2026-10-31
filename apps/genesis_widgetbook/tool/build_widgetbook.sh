#!/usr/bin/env bash
# Construit le catalogue Widgetbook en site web statique (développement
# uniquement ; jamais appelé par la porte `tools/loop/gate.sh`).
#
# Usage : tool/build_widgetbook.sh [BASE_HREF]
#   BASE_HREF : chemin de publication, commençant et finissant par « / »
#               (défaut « / » ; pour GitHub Pages : « /<dépôt>/ »).
#
# Sortie : apps/genesis_widgetbook/build/web, à servir par n'importe quel
# hébergeur statique (pas de Widgetbook Cloud : adr-0006). Prérequis : le
# support web de Flutter activé (`flutter config --enable-web`, activé par
# défaut sur le canal stable).
set -euo pipefail

base_href="${1:-/}"
case "$base_href" in
  /*/ | /) ;;
  *)
    echo "BASE_HREF doit commencer et finir par « / » (reçu : $base_href)" >&2
    exit 2
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Le code des stories est généré : on le régénère avant de construire.
dart run build_runner build
flutter build web --release --base-href "$base_href"

echo "Catalogue construit dans $(pwd)/build/web (base href : $base_href)"
