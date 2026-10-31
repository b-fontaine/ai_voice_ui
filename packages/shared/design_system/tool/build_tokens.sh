#!/usr/bin/env bash
# Régénère lib/src/generated/scene_tokens.g.dart (développement uniquement).
# Node n'est jamais requis à l'exécution de l'application ni par la porte :
# le fichier généré est committé et son hash est contrôlé par un test Dart.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
npm ci --ignore-scripts --no-audit --no-fund
node build_tokens.mjs
